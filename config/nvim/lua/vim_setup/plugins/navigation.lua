return {
  {
    "folke/snacks.nvim",
    priority = 900,
    lazy = false,
    opts = {
      bigfile = { enabled = true },
      explorer = { enabled = true },
      image = {
        enabled = true,
        formats = {
          "png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff", "heic", "avif", "svg", "pdf", "icns",
        },
        doc = { enabled = true, inline = true, float = true, max_width = 80, max_height = 40 },
      },
      input = { enabled = true },
      notifier = { enabled = true, timeout = 3000 },
      picker = {
        enabled = true,
        sources = {
          explorer = {
            auto_close = false,
            hidden = true,
            layout = { preset = "sidebar", preview = false },
          },
        },
      },
      quickfile = { enabled = true },
      words = { enabled = true },
    },
    keys = {
      { "<leader>e", function() Snacks.explorer() end, desc = "Project explorer" },
      { "<leader><space>", function() Snacks.picker.smart() end, desc = "Smart file search" },
      { "<leader>ff", function() Snacks.picker.files() end, desc = "Find files" },
      { "<leader>fg", function() Snacks.picker.grep() end, desc = "Search project text" },
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Find buffers" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent files" },
      { "<leader>fc", function() Snacks.picker.commands() end, desc = "Commands" },
      { "<leader>fs", function() Snacks.picker.lsp_symbols() end, desc = "File symbols" },
      { "<leader>ip", function() Snacks.image.hover() end, desc = "Preview image under cursor" },
      { "<C-p>", function() Snacks.picker.files() end, desc = "Find files" },
      { "<C-g>", function() Snacks.picker.grep() end, desc = "Search project text" },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("vim_setup.treesitter").setup()
    end,
  },
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    dependencies = { "echasnovski/mini.icons" },
    opts = {},
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Workspace diagnostics" },
      { "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics" },
      { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Document symbols" },
      { "<leader>xl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP references" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix list" },
    },
  },
}
