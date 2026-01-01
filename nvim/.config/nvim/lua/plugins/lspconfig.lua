return {
  "hrsh7th/cmp-nvim-lsp", -- LSP source for nvim-cmp
  demendencies = {
    "neovim/nvim-lspconfig"
  },
  config = function()
    local capabilities = require('cmp_nvim_lsp').default_capabilities()
    local lspconfig = require('lspconfig')

    -- HTML
    lspconfig.emmet_ls.setup({ capabilities = capabilities })

    -- JS/TS
    lspconfig.eslint.setup({ capabilities = capabilities })
    lspconfig.ts_ls.setup({ capabilities = capabilities })
    lspconfig.svelte.setup({ capabilities = capabilities })
    lspconfig.jsonls.setup({ capabilities = capabilities })

    -- Python
    lspconfig.basedpyright.setup({
      capabilities = capabilities,
      -- disable reportMissingTypeStubs
      settings = {
        {
          basedpyright = {
            analysis = {
              autoSearchPaths = true,
              diagnosticMode = "openFilesOnly",
              useLibraryCodeForTypes = true,
            }
          }
        }
      }
    })
    lspconfig.ruff.setup({ capabilities = capabilities })

    -- Lua
    lspconfig.lua_ls.setup({ capabilities = capabilities })

    -- PHP
    lspconfig.phpactor.setup({ capabilities = capabilities })



    return true
  end
}
