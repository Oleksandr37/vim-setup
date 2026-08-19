local M = {}

M.parsers = {
  "bash",
  "css",
  "diff",
  "dockerfile",
  "git_config",
  "git_rebase",
  "gitcommit",
  "gitignore",
  "hcl",
  "html",
  "javascript",
  "json",
  "lua",
  "luadoc",
  "markdown",
  "markdown_inline",
  "python",
  "query",
  "regex",
  "terraform",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

function M.setup()
  require("nvim-treesitter").setup({})
  vim.treesitter.language.register("yaml", "yaml.docker-compose")

  local group = vim.api.nvim_create_augroup("vim_setup_treesitter", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "*",
    callback = function(event)
      pcall(vim.treesitter.start, event.buf)
    end,
  })
end

function M.install(timeout_ms)
  local task = require("nvim-treesitter").install(M.parsers)
  if task then
    task:wait(timeout_ms or 300000)
  end
end

return M
