local methods = vim.lsp.protocol.Methods

local inlay_hint_handler = vim.lsp.handlers[methods.textDocument_inlayHint]
local simplify_inlay_hint_handler = function(err, result, ctx, config)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if client then
    if result == nil then return end
    ---@diagnostic disable-next-line: undefined-field

    result = vim
      .iter(result)
      :map(function(hint)
        local label = hint.label
        if not (label ~= nil and #label < 5) then hint.label = {} end
        return hint
      end)
      :filter(function(hint) return #hint.label > 0 end)
      :totable()
  end
  inlay_hint_handler(err, result, ctx, config)
end

local rename_handler = vim.lsp.handlers[methods.textDocument_rename]
local auto_save_after_rename_handler = function(err, result, ctx, config)
  rename_handler(err, result, ctx, config)

  if not result or not result.documentChanges then return end

  for _, documentChange in pairs(result.documentChanges) do
    local textDocument = documentChange.textDocument
    if textDocument and textDocument.uri then
      local bufnr = vim.uri_to_bufnr(textDocument.uri)
      if vim.fn.bufloaded(bufnr) == 1 then
        vim.schedule(function()
          vim.api.nvim_buf_call(bufnr, function() vim.cmd "write" end)
        end)
      end
    end
  end
end

-- AstroLSP allows you to customize the features in AstroNvim's LSP configuration engine
-- Configuration documentation can be found with `:h astrolsp`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  ---@diagnostic disable-next-line: assign-type-mismatch
  opts = function(_, opts)
    local mappings = require("mapping").lsp_mappings(opts.mappings)

    return require("astrocore").extend_tbl(opts, {
      -- Configuration table of features provided by AstroLSP
      features = {
        codelens = true, -- enable/disable codelens refresh on start
        inlay_hints = true, -- enable/disable inlay hints on start
        semantic_tokens = true, -- enable/disable semantic token highlighting
        signature_help = false,
        -- autoformat = false, -- enable or disable auto formatting on start
      },
      -- customize lsp formatting options
      formatting = {
        -- control auto formatting on save
        format_on_save = {
          enabled = false, -- enable or disable format on save globally
          allow_filetypes = { -- enable format on save for specified filetypes only
            -- "go",
          },
          ignore_filetypes = { -- disable format on save for specified filetypes
            -- "python",
          },
        },
        disabled = { -- disable formatting capabilities for the listed language servers
          -- disable lua_ls formatting capability if you want to use StyLua to format your lua code
          -- "lua_ls",
        },
        timeout_ms = 20000,
        -- filter = function(client) -- fully override the default formatting function
        --   return true
        -- end
      },
      -- enable servers that you already have installed without mason
      servers = {
        -- "pyright"
      },
      -- customize language server configuration options passed to `lspconfig`
      ---@diagnostic disable: missing-fields
      config = {
        -- clangd = { capabilities = { offsetEncoding = "utf-8" } },
      },
      -- customize how language servers are attached
      handlers = {
        -- a function without a key is simply the default handler, functions take two parameters, the server name and the configured options table for that server
        -- function(server, opts) require("lspconfig")[server].setup(opts) end

        -- the key is the server that is being setup with `lspconfig`
        -- rust_analyzer = false, -- setting a handler to false will disable the set up of that language server
        -- pyright = function(_, opts) require("lspconfig").pyright.setup(opts) end -- or a custom handler function can be passed
      },
      -- Configure buffer local auto commands to add when attaching a language server
      autocmds = {
        -- first key is the `augroup` to add the auto commands to (:h augroup)
        lsp_codelens_refresh = {
          -- Optional condition to create/delete auto command group
          -- can either be a string of a client capability or a function of `fun(client, bufnr): boolean`
          -- condition will be resolved for each client on each execution and if it ever fails for all clients,
          -- the auto commands will be deleted for that buffer
          cond = "textDocument/codeLens",
          -- cond = function(client, bufnr) return client.name == "lua_ls" end,
          -- list of auto commands to set
          {
            -- events to trigger
            event = { "InsertLeave", "BufEnter" },
            -- the rest of the autocmd options (:h nvim_create_autocmd)
            desc = "Refresh codelens (buffer)",
            callback = function(args)
              if require("astrolsp").config.features.codelens then vim.lsp.codelens.refresh { bufnr = args.buf } end
            end,
          },
        },
      },
      -- mappings to be set up on attaching of a language server
      mappings = mappings,
      -- A custom `on_attach` function to be run after the default `on_attach` function
      -- takes two parameters `client` and `bufnr`  (`:h lspconfig-setup`)
      on_attach = function(client, bufnr)
        -- this would disable semanticTokensProvider for all clients
        -- client.server_capabilities.semanticTokensProvider = nil
      end,
      lsp_handlers = {
        [methods.textDocument_inlayHint] = simplify_inlay_hint_handler,
        [methods.textDocument_rename] = auto_save_after_rename_handler,
      },
    })
  end,
}