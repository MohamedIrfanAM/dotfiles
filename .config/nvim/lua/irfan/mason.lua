local M = {
  "williamboman/mason-lspconfig.nvim",
  dependencies = {
    "williamboman/mason.nvim",
    "nvim-lua/plenary.nvim",
  },
}

M.execs= {
    "lua_ls",
    "cssls",
    "html",
    "tsserver",
    "tailwindcss",
    "eslint",
    "prettierd",
    "bashls",
    "jsonls",
  }

function M.config()

  require("mason").setup {
    ui = {
      border = "rounded",
    },
  }

  require("mason-lspconfig").setup {
    ensure_installed = M.execs
  }
end

return M
