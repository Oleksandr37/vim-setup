local function lazygit()
  -- Snacks runs Lazygit in a Neovim terminal float and wires `e` back to the
  -- current Neovim instance. A tmux popup is a separate terminal, so Lazygit's
  -- nvim-remote preset cannot return the selected file to this editor.
  Snacks.lazygit()
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
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
    -- Build the pinned source locally instead of using CodeDiff's automatic
    -- release-binary download, which currently has no checksum verification.
    build = "./build.sh",
    init = function()
      -- If the source build is missing or broken, fail closed. Do not let the
      -- plugin silently fall back to downloading an unverified release binary.
      vim.env.VSCODE_DIFF_NO_AUTO_INSTALL = "1"

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "codediff-explorer",
        callback = function(event)
          -- A tree is vertically navigated and already truncates long paths.
          -- Ignore trackpad/shift-wheel horizontal gestures in this pane.
          for _, key in ipairs({
            "<ScrollWheelLeft>",
            "<ScrollWheelRight>",
            "<S-ScrollWheelUp>",
            "<S-ScrollWheelDown>",
          }) do
            vim.keymap.set("n", key, "<Nop>", { buffer = event.buf, silent = true })
          end
        end,
      })
    end,
    keys = {
      { "<leader>gg", "<cmd>CodeDiff<cr>", desc = "Review changes" },
      { "<leader>gf", "<cmd>CodeDiff<cr>", desc = "Changed files" },
    },
    opts = {
      highlights = {
        line_insert = "#173d24",
        line_delete = "#4a2025",
        char_insert = "#285d36",
        char_delete = "#71313a",
      },
      diff = {
        layout = "inline",
        filler_text = "",
        max_computation_time_ms = 5000,
        compact = false,
      },
      explorer = {
        position = "left",
        width = 36,
        initial_focus = "explorer",
        view_mode = "tree",
        focus_on_select = false,
        auto_open_on_cursor = false,
        auto_refresh = true,
      },
      keymaps = {
        view = {
          quit = { "q", "<Esc>" },
          open_in_prev_tab = { "gf", "o" },
          toggle_stage = { "-", "<Tab>" },
        },
        explorer = {
          -- Leave mouse press unbound so Neovim first moves the cursor to the
          -- clicked row, then select that row when the button is released.
          select = { "<CR>", "<LeftRelease>" },
        },
      },
    },
  },
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gG", lazygit, desc = "Lazygit actions" },
      { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git log" },
    },
  },
}
