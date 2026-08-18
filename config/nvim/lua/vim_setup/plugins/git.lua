local function lazygit()
  if vim.env.TMUX then
    vim.fn.jobstart({
      "tmux", "display-popup", "-E", "-w", "95%", "-h", "95%", "-d", vim.fn.getcwd(), "lazygit",
    }, { detach = true })
  else
    Snacks.lazygit()
  end
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
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles", "DiffviewFocusFiles" },
    dependencies = { "nvim-lua/plenary.nvim", "echasnovski/mini.icons" },
    opts = {
      enhanced_diff_hl = true,
      view = { merge_tool = { layout = "diff3_mixed" } },
    },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "Review repository diff" },
      { "<leader>gc", "<cmd>DiffviewClose<CR>", desc = "Close diff review" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "Current file history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<CR>", desc = "Repository history" },
    },
  },
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gg", lazygit, desc = "Lazygit popup" },
      { "<leader>gf", function() Snacks.picker.git_status() end, desc = "Changed files" },
      { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git log" },
    },
  },
}
