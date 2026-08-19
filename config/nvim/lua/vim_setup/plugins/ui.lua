return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "storm",
      transparent = false,
      styles = { comments = { italic = true }, keywords = { italic = false } },
      on_highlights = function(highlights, colors)
        -- High-contrast unified diffs inspired by GitHub's dark review UI.
        -- Snacks' Git status preview combines these backgrounds with the
        -- source file's Tree-sitter highlighting.
        highlights.DiffAdd = { bg = "#173d24" }
        highlights.DiffDelete = { bg = "#4a2025" }
        highlights.DiffChange = { bg = colors.bg_float }
        highlights.DiffText = { bg = "#285d36" }
      end,
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight")
    end,
  },
  {
    "echasnovski/mini.icons",
    version = false,
    lazy = true,
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
    opts = {},
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "echasnovski/mini.icons" },
    opts = {
      options = {
        theme = "tokyonight",
        globalstatus = true,
        component_separators = { left = "│", right = "│" },
        section_separators = { left = "", right = "" },
      },
      sections = {
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "diagnostics", "diff", "encoding", "filetype" },
      },
    },
  },
  {
    "folke/which-key.nvim",
    -- WhichKey initializes on VimEnter. Loading it from the same first keypress
    -- that calls show() races that initialization and makes the shortcut fail.
    lazy = false,
    dependencies = { "echasnovski/mini.icons" },
    opts = {
      preset = "modern",
      delay = 300,
      spec = {
        { "<leader>b", group = "buffers" },
        { "<leader>c", group = "code" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>i", group = "images" },
        { "<leader>m", group = "markdown" },
        { "<leader>r", group = "run" },
        { "<leader>x", group = "diagnostics" },
        { "<leader>w", group = "windows" },
      },
    },
    keys = {
      {
        "<leader>?",
        "<cmd>WhichKey<CR>",
        desc = "All shortcuts",
      },
      {
        "<leader>/",
        "<cmd>WhichKey<CR>",
        desc = "All shortcuts",
      },
    },
  },
}
