return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
      keymap = {
        preset = "default",
        -- Kitty translates Cmd-I to this terminal-safe key. Keep it explicit
        -- so a Blink preset update cannot silently break manual completion.
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        -- Blink's default arrow mappings fall back to Neovim cursor movement
        -- when the completion menu disappears between keystrokes. Swallowing
        -- that transition prevents editing from unexpectedly continuing on a
        -- different source line.
        ["<Up>"] = {
          function(cmp)
            if cmp.is_menu_visible() then
              return cmp.select_prev({ auto_insert = false })
            end
            return true
          end,
        },
        ["<Down>"] = {
          function(cmp)
            if cmp.is_menu_visible() then
              return cmp.select_next({ auto_insert = false })
            end
            return true
          end,
        },
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = {
          function(cmp)
            if cmp.is_menu_visible() then
              return cmp.select_and_accept()
            end
          end,
          "snippet_forward",
          "fallback",
        },
      },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 300 },
        list = { selection = { preselect = true, auto_insert = false } },
        menu = { border = "rounded" },
      },
      signature = { enabled = true, window = { border = "rounded" } },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
    },
    opts_extend = { "sources.default" },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "mason-org/mason.nvim", cmd = "Mason", opts = { ui = { border = "rounded" } } },
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp",
      "b0o/SchemaStore.nvim",
      {
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        opts = function()
          local testing = vim.env.VIM_SETUP_TESTING == "1"
          return {
            ensure_installed = testing and {} or {
              "css-lsp",
              "docker-compose-language-service",
              "dockerfile-language-server",
              "eslint-lsp",
              "html-lsp",
              "json-lsp",
              "lua-language-server",
              "prettierd",
              "pyright",
              "ruff",
              "stylua",
              "terraform-ls",
              "tflint",
              "typescript-language-server",
              "yaml-language-server",
            },
            run_on_start = not testing,
          }
        end,
      },
    },
    config = function()
      vim.filetype.add({
        filename = {
          ["compose.yaml"] = "yaml.docker-compose",
          ["compose.yml"] = "yaml.docker-compose",
          ["docker-compose.yaml"] = "yaml.docker-compose",
          ["docker-compose.yml"] = "yaml.docker-compose",
        },
      })

      local capabilities = require("blink.cmp").get_lsp_capabilities()
      -- Neovim's recursive client-side watchers can exhaust file descriptors
      -- on macOS and in large monorepos. Language servers retain their native
      -- watcher fallback, while completion, diagnostics, and navigation are
      -- unaffected.
      capabilities.workspace = capabilities.workspace or {}
      capabilities.workspace.didChangeWatchedFiles = { dynamicRegistration = false }
      vim.lsp.config("*", { capabilities = capabilities })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim", "Snacks" } },
            workspace = {
              checkThirdParty = false,
              library = { vim.env.VIMRUNTIME },
            },
            telemetry = { enable = false },
          },
        },
      })
      vim.lsp.config("pyright", {
        settings = { python = { analysis = { typeCheckingMode = "basic", autoImportCompletions = true } } },
      })
      vim.lsp.config("jsonls", {
        settings = { json = { schemas = require("schemastore").json.schemas(), validate = { enable = true } } },
      })
      vim.lsp.config("yamlls", {
        settings = {
          yaml = {
            schemaStore = { enable = false, url = "" },
            schemas = require("schemastore").yaml.schemas(),
            validate = true,
          },
        },
      })

      local servers = {
          "cssls",
          "docker_compose_language_service",
          "dockerls",
          "eslint",
          "html",
          "jsonls",
          "lua_ls",
          "pyright",
          "ruff",
          "terraformls",
          "ts_ls",
          "yamlls",
      }
      require("mason-lspconfig").setup({
        ensure_installed = vim.env.VIM_SETUP_TESTING == "1" and {} or servers,
        automatic_enable = servers,
      })

      vim.diagnostic.config({
        severity_sort = true,
        underline = true,
        update_in_insert = false,
        virtual_text = { spacing = 2, source = "if_many" },
        float = { border = "rounded", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "󰅚 ",
            [vim.diagnostic.severity.WARN] = "󰀪 ",
            [vim.diagnostic.severity.INFO] = "󰋽 ",
            [vim.diagnostic.severity.HINT] = "󰌶 ",
          },
        },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local function lsp_map(keys, func, desc, modes)
            vim.keymap.set(modes or "n", keys, func, { buffer = event.buf, desc = desc })
          end
          local function select_code_action()
            vim.lsp.buf.code_action({ apply = false })
          end
          local function select_quick_fix()
            -- Match VS Code's Quick Fix command: exclude unrelated refactors
            -- and require confirmation even when the server offers one fix.
            vim.lsp.buf.code_action({
              apply = false,
              context = { only = { vim.lsp.protocol.CodeActionKind.QuickFix } },
            })
          end
          lsp_map("gd", vim.lsp.buf.definition, "Go to definition")
          lsp_map("gD", vim.lsp.buf.declaration, "Go to declaration")
          lsp_map("gr", vim.lsp.buf.references, "Find references")
          lsp_map("gI", vim.lsp.buf.implementation, "Go to implementation")
          lsp_map("gy", vim.lsp.buf.type_definition, "Go to type definition")
          lsp_map("K", vim.lsp.buf.hover, "Hover documentation")
          lsp_map("<leader>ca", select_code_action, "Code action")
          lsp_map("<F13>", select_quick_fix, "Quick fix", { "n", "i", "x" })
          lsp_map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          lsp_map("<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
          lsp_map("[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Previous diagnostic")
          lsp_map("]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Next diagnostic")

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.name == "ruff" then
            client.server_capabilities.hoverProvider = false
          end
        end,
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
      formatters_by_ft = {
        css = { "prettierd", "prettier", stop_after_first = true },
        html = { "prettierd", "prettier", stop_after_first = true },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        json = { "prettierd", "prettier", stop_after_first = true },
        jsonc = { "prettierd", "prettier", stop_after_first = true },
        lua = { "stylua" },
        markdown = { "prettierd", "prettier", stop_after_first = true },
        python = { "ruff_format" },
        terraform = { "terraform_fmt" },
        ["terraform-vars"] = { "terraform_fmt" },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        yaml = { "prettierd", "prettier", stop_after_first = true },
        ["yaml.docker-compose"] = { "prettierd", "prettier", stop_after_first = true },
      },
      format_on_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end
        return { timeout_ms = 1500, lsp_format = "fallback" }
      end,
    },
    keys = {
      {
        "<leader>cf",
        function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
        desc = "Format file",
      },
    },
    init = function()
      vim.api.nvim_create_user_command("FormatDisable", function(args)
        if args.bang then vim.b.disable_autoformat = true else vim.g.disable_autoformat = true end
      end, { desc = "Disable format-on-save", bang = true })
      vim.api.nvim_create_user_command("FormatEnable", function()
        vim.b.disable_autoformat = false
        vim.g.disable_autoformat = false
      end, { desc = "Enable format-on-save" })
    end,
  },
  {
    "echasnovski/mini.pairs",
    version = false,
    event = "InsertEnter",
    opts = {},
  },
}
