return {
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      theme = "dragon",
      transparent = false,
      terminalColors = true,
      commentStyle = { italic = true },
      keywordStyle = {},
      statementStyle = { bold = false },
      background = { dark = "dragon", light = "lotus" },
      overrides = function()
        -- Keep additions and deletions immediately scannable in the review
        -- picker while preserving Tree-sitter's foreground syntax colors.
        return {
          DiffAdd = { bg = "#173d24" },
          DiffDelete = { bg = "#4a2025" },
          DiffChange = { bg = "#252535" },
          DiffText = { bg = "#285d36" },
        }
      end,
    },
    config = function(_, opts)
      require("kanagawa").setup(opts)
      vim.cmd.colorscheme("kanagawa-dragon")
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
        theme = "kanagawa",
        globalstatus = true,
        always_show_tabline = false,
        component_separators = { left = "│", right = "│" },
        section_separators = { left = "", right = "" },
      },
      sections = {
        lualine_c = {
          {
            "filename",
            path = 1,
            fmt = function(name)
              return vim.bo.filetype == "codediff-explorer" and "Diff" or name
            end,
          },
        },
        lualine_x = { "diagnostics", "diff", "encoding", "filetype" },
      },
      tabline = {
        lualine_a = {
          {
            "tabs",
            mode = 1,
            path = 0,
            fmt = function(name, tab)
              return tab.filetype == "codediff-explorer" and "Diff" or name
            end,
          },
        },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
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
