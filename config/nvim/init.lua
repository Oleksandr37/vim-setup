vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("vim_setup.options")
require("vim_setup.keymaps")
require("vim_setup.autocmds")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Could not install lazy.nvim:\n" .. output)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({ { import = "vim_setup.plugins" } }, {
  defaults = { lazy = true },
  install = { colorscheme = { "tokyonight", "habamax" } },
  change_detection = { notify = false },
  checker = { enabled = false },
  ui = { border = "rounded" },
})

require("vim_setup.tasks").setup()

local local_config = vim.fn.expand("~/.config/vim-setup/local.lua")
if vim.uv.fs_stat(local_config) then
  dofile(local_config)
end
