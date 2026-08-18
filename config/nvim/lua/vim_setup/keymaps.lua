local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>confirm quit<CR>", { desc = "Quit window" })
map("n", "<leader>Q", "<cmd>confirm qall<CR>", { desc = "Quit Neovim" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Close buffer" })
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })

map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

local tmux_directions = { h = "-L", j = "-D", k = "-U", l = "-R" }
local function navigate(direction)
  local before = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. direction)
  if before == vim.api.nvim_get_current_win() and vim.env.TMUX then
    vim.fn.system({ "tmux", "select-pane", tmux_directions[direction] })
  end
end

for _, direction in ipairs({ "h", "j", "k", "l" }) do
  map("n", "<C-" .. direction .. ">", function()
    navigate(direction)
  end, { desc = "Move " .. direction })
end

map("n", "<leader>wh", "<cmd>vertical resize -5<CR>", { desc = "Narrow window" })
map("n", "<leader>wl", "<cmd>vertical resize +5<CR>", { desc = "Widen window" })
map("n", "<leader>wj", "<cmd>resize +3<CR>", { desc = "Make window taller" })
map("n", "<leader>wk", "<cmd>resize -3<CR>", { desc = "Make window shorter" })

map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })
