local M = {}

local function fail(message)
  error("keymap audit: " .. message, 0)
end

local function mapping(mode, lhs)
  local value = vim.fn.maparg(lhs, mode, false, true)
  if type(value) ~= "table" or vim.tbl_isempty(value) then
    fail(string.format("missing %s mapping for %s", mode, vim.inspect(lhs)))
  end
  return value
end

local expected = {
  { "n", "<Esc>", "Clear search highlight" },
  { "n", "<leader>w", "Save file" },
  { "n", "<leader>q", "Quit window" },
  { "n", "<leader>Q", "Quit Neovim" },
  { "n", "<leader>bd", "Close buffer" },
  { "n", "<S-h>", "Previous buffer" },
  { "n", "<S-l>", "Next buffer" },
  { "v", "<", "Indent left" },
  { "v", ">", "Indent right" },
  { "v", "J", "Move selection down" },
  { "v", "K", "Move selection up" },
  { "n", "<C-h>", "Move h" },
  { "n", "<C-j>", "Move j" },
  { "n", "<C-k>", "Move k" },
  { "n", "<C-l>", "Move l" },
  { "n", "<leader>wh", "Narrow window" },
  { "n", "<leader>wl", "Widen window" },
  { "n", "<leader>wj", "Make window taller" },
  { "n", "<leader>wk", "Make window shorter" },
  { "t", "<Esc><Esc>", "Leave terminal mode" },
  { "n", "<C-p>", "Find files" },
  { "n", "<C-g>", "Search project text" },
  { "n", "<leader>e", "Project explorer" },
  { "n", "<leader><space>", "Smart file search" },
  { "n", "<leader>ff", "Find files" },
  { "n", "<leader>fg", "Search project text" },
  { "n", "<leader>fb", "Find buffers" },
  { "n", "<leader>fr", "Recent files" },
  { "n", "<leader>fc", "Commands" },
  { "n", "<leader>fs", "File symbols" },
  { "n", "<leader>ip", "Preview image under cursor" },
  { "n", "<leader>xx", "Workspace diagnostics" },
  { "n", "<leader>xb", "Buffer diagnostics" },
  { "n", "<leader>xs", "Document symbols" },
  { "n", "<leader>xl", "LSP references" },
  { "n", "<leader>xq", "Quickfix list" },
  { "n", "<leader>cf", "Format file" },
  { "n", "<leader>gg", "Review changes" },
  { "n", "<leader>gG", "Lazygit actions" },
  { "n", "<leader>gf", "Changed files" },
  { "n", "<leader>gl", "Git log" },
  { "n", "<leader>mt", "Toggle rendered Markdown" },
  { "n", "<leader>me", "Enable rendered Markdown" },
  { "n", "<leader>md", "Show Markdown source" },
  { "n", "<leader>/", "All shortcuts" },
  { "n", "<leader>?", "All shortcuts" },
  { "n", "<leader>rr", "Run default task" },
  { "n", "<leader>rt", "Choose task" },
  { "n", "<leader>rl", "Run last task" },
  { "n", "<leader>rs", "Stop task" },
  { "n", "<leader>rv", "Choose service terminal" },
  { "n", "<leader>ra", "Create agent shell" },
  { "n", "<F5>", "Run default project task" },
}

local function assert_expected_mappings()
  for _, item in ipairs(expected) do
    local mode, lhs, description = unpack(item)
    local found = mapping(mode, lhs:gsub("<leader>", vim.g.mapleader))
    if found.desc ~= description then
      fail(string.format(
        "%s is owned by %s instead of %s",
        lhs,
        vim.inspect(found.desc),
        vim.inspect(description)
      ))
    end
  end
end

local function assert_safe_completion_mappings()
  local repo_root = assert(vim.env.VIM_SETUP_REPO_ROOT)
  local specs = dofile(repo_root .. "/config/nvim/lua/vim_setup/plugins/coding.lua")
  local opts = specs[1].opts

  local manual = opts.keymap["<C-Space>"]
  if not vim.deep_equal(manual, { "show", "show_documentation", "hide_documentation" }) then
    fail("Ctrl-Space must explicitly open Blink completion for Kitty's Cmd-I transport")
  end

  if not vim.tbl_isempty(vim.fn.maparg("i", "n", false, true)) then
    fail("plain i must remain Neovim's built-in Insert-mode command")
  end

  if opts.completion.list.selection.auto_insert ~= false then
    fail("completion candidates may modify the buffer before acceptance")
  end

  for key, method in pairs({ ["<Up>"] = "select_prev", ["<Down>"] = "select_next" }) do
    local commands = opts.keymap[key]
    if #commands ~= 1 or type(commands[1]) ~= "function" then
      fail(key .. " completion mapping can fall through to cursor movement")
    end

    local selected
    local fake_cmp = {
      is_menu_visible = function() return false end,
      select_prev = function(selection_opts)
        selected = { method = "select_prev", opts = selection_opts }
        return true
      end,
      select_next = function(selection_opts)
        selected = { method = "select_next", opts = selection_opts }
        return true
      end,
    }

    if commands[1](fake_cmp) ~= true or selected ~= nil then
      fail(key .. " is not safely consumed when completion disappears")
    end

    fake_cmp.is_menu_visible = function() return true end
    if commands[1](fake_cmp) ~= true or not selected or selected.method ~= method then
      fail(key .. " does not select the expected completion item")
    end
    if selected.opts.auto_insert ~= false then
      fail(key .. " inserts a completion candidate before acceptance")
    end
  end

  local enter = opts.keymap["<CR>"]
  if not vim.deep_equal(enter, { "accept", "fallback" }) then
    fail("Enter must accept a visible completion and remain a newline otherwise")
  end

  local tab = opts.keymap["<Tab>"]
  if type(tab[1]) ~= "function" or tab[2] ~= "snippet_forward" or tab[3] ~= "fallback" then
    fail("Tab must accept a visible completion and retain snippet/tab behavior otherwise")
  end
  local tab_accepted = false
  local fake_cmp = {
    is_menu_visible = function() return true end,
    select_and_accept = function()
      tab_accepted = true
      return true
    end,
  }
  if tab[1](fake_cmp) ~= true or not tab_accepted then
    fail("Tab does not accept a visible completion")
  end

  -- The Mason/LSP spec configures lua_ls at runtime; keep the runtime-library
  -- setting visible in the source audit so isolated tests do not silently lose
  -- Neovim API completion while using a deterministic local-table probe.
  local coding_source = table.concat(vim.fn.readfile(
    repo_root .. "/config/nvim/lua/vim_setup/plugins/coding.lua"
  ), "\n")
  if not coding_source:find("library = { vim.env.VIMRUNTIME }", 1, true) then
    fail("lua_ls does not include Neovim's runtime library for vim.* completion")
  end
end

function M.run()
  assert_expected_mappings()
  assert_safe_completion_mappings()
  print("Neovim shortcut audit passed.")
end

return M
