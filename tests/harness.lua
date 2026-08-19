local M = {}

local function stop_lsp_clients()
  for _, client in ipairs(vim.lsp.get_clients()) do
    client:stop(true)
  end
end

function M.schedule(test_path)
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      -- Plugin setup callbacks scheduled by VimEnter must finish before the
      -- simulated user workflow begins.
      vim.defer_fn(function()
        local ok, message = xpcall(function()
          local plugins = vim.tbl_keys(require("lazy.core.config").plugins)
          require("lazy").load({ plugins = plugins })
          dofile(test_path).run()
        end, debug.traceback)

        if not ok then
          vim.api.nvim_err_writeln(message)
          stop_lsp_clients()
          vim.cmd("cquit 1")
          return
        end
        stop_lsp_clients()
        vim.cmd("qa!")
      end, 100)
    end,
  })
end

return M
