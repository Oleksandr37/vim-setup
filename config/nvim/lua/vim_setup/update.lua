local M = {}

local pending_version = nil
local restarting = false

local function register_server()
  local pane = vim.env.TMUX_PANE
  if not pane or pane == "" or vim.fn.executable("tmux") ~= 1 then
    return
  end
  if vim.v.servername == "" then
    pcall(vim.fn.serverstart)
  end
  if vim.v.servername == "" then
    return
  end
  vim.system({
    "tmux",
    "set-option",
    "-pq",
    "-t",
    pane,
    "@workon_nvim_socket",
    vim.v.servername,
  }, { detach = true })
end

local function has_modified_buffers()
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buffer) and vim.bo[buffer].modified then
      return true
    end
  end
  return false
end

local function restart()
  if restarting or has_modified_buffers() then
    return false
  end
  restarting = true
  pending_version = nil
  vim.schedule(function()
    if vim.g.workon_test_update_restart == true then
      vim.g.workon_test_update_restart_count = (vim.g.workon_test_update_restart_count or 0) + 1
      restarting = false
      return
    end
    vim.cmd("restart")
  end)
  return true
end

function M.request_restart(version)
  pending_version = version ~= "" and version or "the new version"
  if restart() then
    return "restarting"
  end
  vim.notify(
    "Workon " .. pending_version .. " is ready. Neovim will restart after all modified buffers are saved.",
    vim.log.levels.INFO,
    { title = "Workon update" }
  )
  return "waiting-for-save"
end

function M.status()
  return {
    pending = pending_version,
    restarting = restarting,
    modified = has_modified_buffers(),
  }
end

function M.setup()
  register_server()
  vim.api.nvim_create_user_command("WorkonRestart", function(command)
    M.request_restart(command.args)
  end, { nargs = "?", desc = "Restart Neovim after a Workon update" })

  local group = vim.api.nvim_create_augroup("workon_update", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWritePost", "BufModifiedSet" }, {
    group = group,
    callback = function()
      if pending_version then
        restart()
      end
    end,
  })
end

return M
