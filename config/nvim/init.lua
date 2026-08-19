vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("vim_setup.options")
require("vim_setup.keymaps")
require("vim_setup.autocmds")
require("vim_setup.update").setup()

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local lazy_lock_path = vim.fn.stdpath("config") .. "/lazy-lock.json"
local lazy_lock = vim.json.decode(table.concat(vim.fn.readfile(lazy_lock_path), "\n"))
local lazy_commit = lazy_lock["lazy.nvim"] and lazy_lock["lazy.nvim"].commit
if type(lazy_commit) ~= "string" or not lazy_commit:match("^[0-9a-f]+$") then
  error("lazy.nvim is missing an exact commit in " .. lazy_lock_path)
end
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--no-checkout",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Could not install lazy.nvim:\n" .. output)
  end
end
local installed_lazy_commit = vim.trim(vim.fn.system({ "git", "-C", lazypath, "rev-parse", "HEAD" }))
local lazy_runtime = (vim.uv or vim.loop).fs_stat(lazypath .. "/lua/lazy/init.lua")
if vim.v.shell_error ~= 0 or installed_lazy_commit ~= lazy_commit or not lazy_runtime then
  local output = vim.fn.system({ "git", "-C", lazypath, "checkout", "--detach", lazy_commit })
  if vim.v.shell_error ~= 0 then
    error("Could not restore the pinned lazy.nvim commit:\n" .. output)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({ { import = "vim_setup.plugins" } }, {
  defaults = { lazy = true },
  install = { colorscheme = { "kanagawa-dragon", "habamax" } },
  change_detection = { notify = false },
  checker = { enabled = false },
  ui = { border = "rounded" },
})

require("vim_setup.tasks").setup()

local local_config = vim.fn.expand("~/.config/vim-setup/local.lua")
if vim.uv.fs_stat(local_config) then
  dofile(local_config)
end
