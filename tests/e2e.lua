local M = {}

local function fail(message)
  error("end-to-end test: " .. message, 0)
end

local function assert_true(value, message)
  if not value then
    fail(message)
  end
end

local function wait_for(description, timeout, predicate)
  local deadline = vim.uv.hrtime() + (timeout * 1000000)
  local delay = 25
  local attempts = 0

  while attempts < 24 do
    attempts = attempts + 1
    if predicate() then
      return
    end

    local remaining = math.floor((deadline - vim.uv.hrtime()) / 1000000)
    if remaining <= 0 then
      break
    end
    vim.wait(math.min(delay, remaining))
    delay = math.min(delay * 2, 500)
  end

  fail(string.format("timed out waiting for %s after %d readiness checks", description, attempts))
end

local function edit(root, relative)
  vim.cmd.edit(vim.fn.fnameescape(root .. "/" .. relative))
  return vim.api.nvim_get_current_buf()
end

local function assert_markdown(root)
  local buffer = edit(root, "README.md")
  assert_true(vim.bo[buffer].filetype == "markdown", "README.md was not detected as Markdown")

  local ok, parser = pcall(vim.treesitter.get_parser, buffer, "markdown")
  assert_true(ok and parser ~= nil, "Markdown Tree-sitter parser is unavailable")
  local parsed, trees = pcall(function() return parser:parse() end)
  assert_true(parsed and trees and #trees > 0, "Markdown Tree-sitter parser did not produce a tree")
  assert_true(vim.treesitter.highlighter.active[buffer] ~= nil, "Markdown Tree-sitter highlighting is inactive")

  vim.cmd("RenderMarkdown enable")
  wait_for("render-markdown extmarks", 5000, function()
    for name, namespace in pairs(vim.api.nvim_get_namespaces()) do
      if name:lower():find("render.markdown") then
        local marks = vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, {})
        if #marks > 0 then
          return true
        end
      end
    end
    return false
  end)
end

local function assert_picker(root)
  local picker = Snacks.picker.files({ cwd = root })
  wait_for("file picker", 3000, function()
    return picker ~= nil and not picker.closed and #Snacks.picker.get() > 0
  end)
  picker:close()
end

local function client_names(buffer)
  local names = {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buffer })) do
    names[client.name] = true
  end
  return names
end

local function assert_no_client_watchers(buffer)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buffer })) do
    for source, capabilities in pairs({ config = client.config.capabilities, advertised = client.capabilities }) do
      local workspace = capabilities and capabilities.workspace
      local watched = workspace and workspace.didChangeWatchedFiles
      if watched and watched.dynamicRegistration ~= false then
        fail(string.format(
          "%s still advertises recursive client-side file watching in %s capabilities: %s",
          client.name,
          source,
          vim.inspect(watched)
        ))
      end
    end
  end
end

local function assert_lsp(root, relative, required)
  local buffer = edit(root, relative)
  wait_for("LSP for " .. relative, 8000, function()
    local attached = client_names(buffer)
    for _, name in ipairs(required) do
      if not attached[name] then
        return false
      end
    end
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = buffer })) do
      if vim.tbl_contains(required, client.name) and not client.initialized then
        return false
      end
    end
    return true
  end)
  assert_no_client_watchers(buffer)

  for _, expected in ipairs({
    { key = "<leader>ca", modes = { "n" }, desc = "Code action" },
    { key = "<F13>", modes = { "n", "i", "x" }, desc = "Quick fix" },
  }) do
    local lhs = expected.key:gsub("<leader>", vim.g.mapleader)
    for _, mode in ipairs(expected.modes) do
      local mapped = vim.fn.maparg(lhs, mode, false, true)
      assert_true(
        type(mapped) == "table" and not vim.tbl_isempty(mapped) and mapped.buffer == 1,
        string.format("%s has no buffer-local %s-mode code-action mapping in %s", expected.key, mode, relative)
      )
      assert_true(mapped.desc == expected.desc, string.format("%s is not owned by %s", expected.key, expected.desc))
    end
  end

  return buffer
end

local function completion_items(result)
  if type(result) ~= "table" then
    return {}
  end
  if vim.islist(result) then
    return result
  end
  return result.items or {}
end

local function assert_lsp_completion(buffer, relative, probe)
  local lines = vim.split(probe, "\n", { plain = true })
  local cursor_line
  local cursor_col
  for index, line in ipairs(lines) do
    local marker = line:find("|", 1, true)
    if marker then
      cursor_line = index
      cursor_col = marker - 1
      lines[index] = line:sub(1, marker - 1) .. line:sub(marker + 1)
      break
    end
  end
  assert_true(cursor_line ~= nil, "completion probe has no cursor marker for " .. relative)

  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { cursor_line, cursor_col })

  local providers = 0
  local diagnostics = {}
  local function request_items()
    local pending = 0
    local item_count = 0
    providers = 0
    diagnostics = {}

    for _, client in ipairs(vim.lsp.get_clients({ bufnr = buffer })) do
      if client.server_capabilities.completionProvider then
        providers = providers + 1
        pending = pending + 1
        local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
        params.context = { triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked }
        local requested = client:request("textDocument/completion", params, function(err, result)
          local items = completion_items(result)
          diagnostics[client.name] = {
            response_error = err,
            items = #items,
            result_type = type(result),
          }
          if err == nil then
            item_count = item_count + #items
          end
          pending = pending - 1
        end, buffer)
        if not requested then
          diagnostics[client.name] = { request_error = "request was rejected" }
          pending = pending - 1
        end
      end
    end

    local completed = vim.wait(2000, function() return pending == 0 end, 25)
    return completed and item_count or 0
  end

  local item_count = 0
  local completion_backoff = { 50, 100, 200, 400, 800, 1600, 3200 }
  local attempts = 0
  for _, delay in ipairs(completion_backoff) do
    attempts = attempts + 1
    item_count = request_items()
    if item_count > 0 then
      break
    end
    vim.wait(delay)
  end
  assert_true(providers > 0, "no attached LSP advertises completion for " .. relative)
  assert_true(item_count > 0, string.format(
    "attached LSPs returned no completion items for %s after %d readiness checks: %s",
    relative,
    attempts,
    vim.inspect(diagnostics)
  ))
end

local function assert_code_action_ui(buffer)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
    "export function needsAsync() {",
    "  await Promise.resolve()",
    "}",
  })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  local unchanged = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)

  wait_for("TypeScript code-action diagnostic", 8000, function()
    return #vim.diagnostic.get(buffer, { lnum = 1 }) > 0
  end)

  -- Snacks normally installs vim.ui.select on UIEnter. Headless CI has no UI,
  -- so initialize the same picker integration explicitly before exercising it.
  if vim.ui.select ~= Snacks.picker.select then
    Snacks.picker.setup()
  end

  -- Exercise the actual Cmd-. transport target, not a direct function call.
  -- The terminal E2E also invokes it from a genuine Insert-mode UI; headless
  -- Neovim cannot enter Insert mode because no UI is attached.
  vim.api.nvim_feedkeys(vim.keycode("<F13>"), "x", false)
  local picker
  wait_for("code-action selection UI", 8000, function()
    for _, candidate in ipairs(Snacks.picker.get()) do
      if not candidate.closed and #candidate:items() > 0 then
        picker = candidate
        return true
      end
    end
    return false
  end)
  for _, item in ipairs(picker:items()) do
    local action = item.item and item.item.action
    assert_true(
      action and action.kind and vim.startswith(action.kind, vim.lsp.protocol.CodeActionKind.QuickFix),
      "Quick Fix picker included a non-quickfix action"
    )
  end
  assert_true(
    vim.deep_equal(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), unchanged),
    "opening Quick Fix modified the source buffer before the user chose an action"
  )
  picker:close()
end

function M.run()
  local root = vim.env.VIM_SETUP_E2E_ROOT
  assert_true(root and vim.fn.isdirectory(root) == 1, "VIM_SETUP_E2E_ROOT is not a fixture directory")
  vim.cmd.cd(vim.fn.fnameescape(root))

  local scope = vim.env.VIM_SETUP_E2E_SCOPE or "all"
  if scope ~= "lsp-completion" then
    assert_markdown(root)
    dofile(vim.env.VIM_SETUP_REPO_ROOT .. "/tests/keymaps.lua").run()
    assert_picker(root)
  end

  if vim.env.VIM_SETUP_E2E_LSP == "1" then
    local selected = vim.env.VIM_SETUP_E2E_LSP_CASE or "all"
    local cases = {
      typescript = {
        "src/app.ts",
        { "ts_ls" },
        "export const completionProbe = console.|",
      },
      react = {
        "src/App.tsx",
        { "ts_ls" },
        "export const CompletionProbe = () => <di| />;",
      },
      python = {
        "src/check.py",
        { "pyright", "ruff" },
        'completion_probe = "hello".|',
      },
      yaml = {
        ".github/workflows/ci.yml",
        { "yamlls" },
        "name: Completion fixture\n|",
      },
      compose = {
        "compose.yaml",
        { "yamlls", "docker_compose_language_service" },
        "services:\n  app:\n    |",
      },
      terraform = {
        "main.tf",
        { "terraformls" },
        'variable "project_name" { type = string }\noutput "probe" {\n  value = var.|\n}',
      },
      docker = {
        "Dockerfile",
        { "dockerls" },
        "FR|",
      },
      json = {
        "package.json",
        { "jsonls" },
        '{\n  "|"\n}',
      },
      html = {
        "index.html",
        { "html" },
        "<di|",
      },
      css = {
        "styles.css",
        { "cssls" },
        "a { dis| }",
      },
      lua = {
        "config.lua",
        { "lua_ls" },
        "local completion_probe = { alpha = true }\ncompletion_probe.|a",
      },
    }
    for name, case in pairs(cases) do
      if selected == "all" or selected == name then
        local buffer = assert_lsp(root, case[1], case[2])
        assert_lsp_completion(buffer, case[1], case[3])
        if name == "typescript" then
          assert_code_action_ui(buffer)
        end
      end
    end
  end

  if scope == "lsp-completion" then
    print("LSP completion case passed: " .. (vim.env.VIM_SETUP_E2E_LSP_CASE or "all"))
  else
    print("Neovim end-to-end workflow passed.")
  end
end

return M
