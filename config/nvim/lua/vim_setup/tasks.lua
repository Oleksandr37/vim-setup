local M = {}

local state = { root = nil, command = nil }

local function project_root()
  return vim.fs.root(0, { ".git", ".vim-setup.json", "package.json", "pyproject.toml" }) or vim.fn.getcwd()
end

local function read_json(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  local ok, decoded = pcall(vim.json.decode, content)
  return ok and decoded or nil
end

local function add_task(tasks, seen, label, command, is_default)
  if type(command) ~= "string" or command == "" or seen[command] then
    return
  end
  seen[command] = true
  table.insert(tasks, { label = label, command = command, default = is_default == true })
end

local function package_manager(root)
  if vim.uv.fs_stat(root .. "/pnpm-lock.yaml") then
    return "pnpm"
  elseif vim.uv.fs_stat(root .. "/yarn.lock") then
    return "yarn"
  elseif vim.uv.fs_stat(root .. "/bun.lockb") or vim.uv.fs_stat(root .. "/bun.lock") then
    return "bun"
  end
  return "npm"
end

local function discover_tasks(root)
  local tasks, seen = {}, {}
  local config = read_json(root .. "/.vim-setup.json")
  if config and type(config.tasks) == "table" then
    for name, command in pairs(config.tasks) do
      add_task(tasks, seen, name, command, name == config.default)
    end
  end

  local package = read_json(root .. "/package.json")
  if package and type(package.scripts) == "table" then
    local manager = package_manager(root)
    local preferred = { "dev", "start", "serve", "test", "lint", "build" }
    for _, name in ipairs(preferred) do
      if package.scripts[name] then
        local command = manager == "npm" and ("npm run " .. name) or (manager .. " " .. name)
        add_task(tasks, seen, "package: " .. name, command, #tasks == 0 and (name == "dev" or name == "start"))
      end
    end
    for name in pairs(package.scripts) do
      local command = manager == "npm" and ("npm run " .. name) or (manager .. " " .. name)
      add_task(tasks, seen, "package: " .. name, command, false)
    end
  end

  if vim.uv.fs_stat(root .. "/Makefile") then
    add_task(tasks, seen, "make", "make", #tasks == 0)
  end
  if vim.uv.fs_stat(root .. "/justfile") then
    add_task(tasks, seen, "just", "just", #tasks == 0)
  end
  if vim.uv.fs_stat(root .. "/compose.yaml") or vim.uv.fs_stat(root .. "/docker-compose.yml") then
    add_task(tasks, seen, "docker compose: up", "docker compose up", #tasks == 0)
  end
  if vim.uv.fs_stat(root .. "/main.tf") then
    add_task(tasks, seen, "terraform: plan", "terraform plan", false)
  end
  return tasks
end

local function discover_services(root)
  local services = {}
  local config = read_json(root .. "/.vim-setup.json")
  if config and type(config.services) == "table" then
    for name, command in pairs(config.services) do
      if type(name) == "string" and type(command) == "string" and command ~= "" then
        table.insert(services, { label = name, command = command })
      end
    end
  end
  table.sort(services, function(a, b)
    return a.label < b.label
  end)
  return services
end

local function run_in_terminal(root, command)
  vim.cmd("botright 15split")
  vim.cmd("terminal")
  vim.fn.chansend(vim.b.terminal_job_id, "cd " .. vim.fn.shellescape(root) .. " && " .. command .. "\n")
end

function M.run(command, root)
  root = root or project_root()
  state = { root = root, command = command }
  if vim.env.TMUX and vim.fn.executable("vim-setup-run") == 1 then
    vim.fn.jobstart({ "vim-setup-run", "--root", root, "--", command }, { detach = true })
    vim.notify("Started in runner: " .. command)
  else
    run_in_terminal(root, command)
  end
end

function M.choose()
  local root = project_root()
  local tasks = discover_tasks(root)
  if #tasks == 0 then
    vim.notify("No tasks found. Add .vim-setup.json to this project.", vim.log.levels.WARN)
    return
  end
  vim.ui.select(tasks, {
    prompt = "Run project task",
    format_item = function(task)
      return task.label .. "  ·  " .. task.command
    end,
  }, function(task)
    if task then
      M.run(task.command, root)
    end
  end)
end

function M.run_default()
  local root = project_root()
  local tasks = discover_tasks(root)
  for _, task in ipairs(tasks) do
    if task.default then
      M.run(task.command, root)
      return
    end
  end
  if #tasks == 1 then
    M.run(tasks[1].command, root)
  else
    M.choose()
  end
end

function M.rerun()
  if state.command then
    M.run(state.command, state.root)
  else
    M.run_default()
  end
end

function M.stop()
  local root = project_root()
  if vim.env.TMUX and vim.fn.executable("vim-setup-run") == 1 then
    vim.fn.jobstart({ "vim-setup-run", "--stop", "--root", root }, { detach = true })
    vim.notify("Stopped runner task")
  else
    vim.notify("Stop the terminal task with Ctrl-C", vim.log.levels.INFO)
  end
end

function M.choose_service()
  local root = project_root()
  local services = discover_services(root)
  if #services == 0 then
    vim.notify("No services found. Add services to .vim-setup.json.", vim.log.levels.WARN)
    return
  end
  vim.ui.select(services, {
    prompt = "Start or focus project service",
    format_item = function(service)
      return service.label .. "  ·  " .. service.command
    end,
  }, function(service)
    if service then
      vim.fn.jobstart({ "workon", "service", "start", service.label, "--root", root }, { detach = true })
      vim.notify("Service terminal: " .. service.label)
    end
  end)
end

function M.new_agent()
  local root = project_root()
  vim.ui.input({ prompt = "Agent session name: " }, function(name)
    if name and name ~= "" then
      vim.fn.jobstart({ "workon", "agent", "new", name, "--root", root }, { detach = true })
      vim.notify("Agent shell: " .. name)
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("TaskRun", M.run_default, {})
  vim.api.nvim_create_user_command("TaskSelect", M.choose, {})
  vim.api.nvim_create_user_command("TaskRerun", M.rerun, {})
  vim.api.nvim_create_user_command("TaskStop", M.stop, {})
  vim.api.nvim_create_user_command("ServiceSelect", M.choose_service, {})
  vim.api.nvim_create_user_command("AgentNew", M.new_agent, {})

  vim.keymap.set("n", "<F5>", M.run_default, { desc = "Run default project task" })
  vim.keymap.set("n", "<leader>rr", M.run_default, { desc = "Run default task" })
  vim.keymap.set("n", "<leader>rt", M.choose, { desc = "Choose task" })
  vim.keymap.set("n", "<leader>rl", M.rerun, { desc = "Run last task" })
  vim.keymap.set("n", "<leader>rs", M.stop, { desc = "Stop task" })
  vim.keymap.set("n", "<leader>rv", M.choose_service, { desc = "Choose service terminal" })
  vim.keymap.set("n", "<leader>ra", M.new_agent, { desc = "Create agent shell" })
end

return M
