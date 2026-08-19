local update = require("vim_setup.update")

local mason_tools = require("vim_setup.mason_tools")
assert(#mason_tools > 0, "Mason release tool list is empty")
for _, tool in ipairs(mason_tools) do
  assert(type(tool) == "table" and type(tool[1]) == "string", "Mason tool is not structured")
  assert(type(tool.version) == "string" and tool.version ~= "", tool[1] .. " is not version-pinned")
end

vim.g.workon_test_update_restart = true
vim.g.workon_test_update_restart_count = 0

local buffer = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buffer)
local temporary = vim.fn.tempname()
vim.api.nvim_buf_set_name(buffer, temporary)
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "unsaved" })
vim.bo[buffer].modified = true

assert(update.request_restart("v0.2.0") == "waiting-for-save", "modified buffer did not defer restart")
assert(update.status().pending == "v0.2.0", "pending update version was not retained")
assert(vim.g.workon_test_update_restart_count == 0, "modified buffer was restarted")

vim.cmd.write()
assert(vim.wait(1000, function()
  return vim.g.workon_test_update_restart_count == 1
end, 10), "saving the final modified buffer did not trigger restart")

assert(update.request_restart("v0.3.0") == "restarting", "clean editor did not restart immediately")
assert(vim.wait(1000, function()
  return vim.g.workon_test_update_restart_count == 2
end, 10), "clean editor restart was not scheduled")

vim.fn.delete(temporary)

print("Workon safe restart tests passed")
