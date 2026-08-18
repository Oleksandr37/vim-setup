return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "Avante", "codecompanion" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.icons" },
    opts = {
      render_modes = { "n", "c", "t" },
      heading = { sign = false, position = "inline" },
      code = { sign = false, width = "block", right_pad = 1 },
      checkbox = { enabled = true },
      pipe_table = { preset = "round" },
    },
    keys = {
      { "<leader>mt", "<cmd>RenderMarkdown toggle<CR>", desc = "Toggle rendered Markdown" },
      { "<leader>me", "<cmd>RenderMarkdown enable<CR>", desc = "Enable rendered Markdown" },
      { "<leader>md", "<cmd>RenderMarkdown disable<CR>", desc = "Show Markdown source" },
    },
  },
}
