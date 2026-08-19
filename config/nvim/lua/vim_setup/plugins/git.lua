local function lazygit()
  -- Snacks runs Lazygit in a Neovim terminal float and wires `e` back to the
  -- current Neovim instance. A tmux popup is a separate terminal, so Lazygit's
  -- nvim-remote preset cannot return the selected file to this editor.
  Snacks.lazygit()
end

local function scroll_diff(picker, up)
  local preview = picker.preview.win
  if not preview:valid() then
    return
  end

  -- Snacks' built-in preview scroll uses the window's half-page `scroll`
  -- value. That is appropriate for Ctrl-D/U, but much too large for one
  -- mouse-wheel tick. Match Neovim's native vertical wheel distance instead.
  local lines = tonumber(vim.o.mousescroll:match("ver:(%d+)")) or 3
  local focused_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_call(preview.win, function()
    vim.cmd("normal! " .. lines .. vim.keycode(up and "<C-y>" or "<C-e>"))
  end)

  -- nvim_win_call normally restores this itself. Keeping it explicit makes
  -- the review invariant clear: scrolling the diff never transfers focus.
  if vim.api.nvim_win_is_valid(focused_win) then
    vim.api.nvim_set_current_win(focused_win)
  end
end

local function review_changes()
  Snacks.picker.git_status({
    -- In the review screen, Vim's half-page scroll keys belong to the diff.
    -- Snacks normally assigns them to the file list, which can unexpectedly
    -- change the selected file while someone is reading the preview.
    actions = {
      review_wheel_down = function(picker) scroll_diff(picker, false) end,
      review_wheel_up = function(picker) scroll_diff(picker, true) end,
    },
    win = {
      input = {
        keys = {
          ["<C-d>"] = { "preview_scroll_down", mode = { "i", "n" } },
          ["<C-u>"] = { "preview_scroll_up", mode = { "i", "n" } },
          ["<ScrollWheelDown>"] = { "review_wheel_down", mode = { "i", "n" } },
          ["<ScrollWheelUp>"] = { "review_wheel_up", mode = { "i", "n" } },
        },
      },
      list = {
        keys = {
          ["<C-d>"] = "preview_scroll_down",
          ["<C-u>"] = "preview_scroll_up",
          ["<ScrollWheelDown>"] = "review_wheel_down",
          ["<ScrollWheelUp>"] = "review_wheel_up",
        },
      },
      preview = {
        keys = {
          ["<C-d>"] = "preview_scroll_down",
          ["<C-u>"] = "preview_scroll_up",
          ["<ScrollWheelDown>"] = "review_wheel_down",
          ["<ScrollWheelUp>"] = "review_wheel_up",
        },
      },
    },
    layout = {
      layout = {
        box = "horizontal",
        width = 0.95,
        height = 0.92,
        {
          box = "vertical",
          border = true,
          title = " Changed files ",
          width = 0.35,
          { win = "input", height = 1, border = "bottom" },
          { win = "list", border = "none" },
        },
        {
          win = "preview",
          title = " Diff ",
          border = true,
        },
      },
    },
  })
end

return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      current_line_blame = false,
      preview_config = { border = "rounded" },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map("n", "]h", function() gs.nav_hunk("next") end, "Next Git hunk")
        map("n", "[h", function() gs.nav_hunk("prev") end, "Previous Git hunk")
        map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
        map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
        map("v", "<leader>gs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage hunk")
        map("v", "<leader>gr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset hunk")
        map("n", "<leader>gS", gs.stage_buffer, "Stage file")
        map("n", "<leader>gR", gs.reset_buffer, "Reset file")
        map("n", "<leader>gb", gs.blame_line, "Blame line")
        map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle inline blame")
      end,
    },
  },
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gg", review_changes, desc = "Review changes" },
      { "<leader>gG", lazygit, desc = "Lazygit actions" },
      { "<leader>gf", review_changes, desc = "Changed files" },
      { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git log" },
    },
  },
}
