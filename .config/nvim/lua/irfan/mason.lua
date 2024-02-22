local M = {
	"williamboman/mason-lspconfig.nvim",
	dependencies = {
		"williamboman/mason.nvim",
		"nvim-lua/plenary.nvim",
	},
}

function M.config()
	local servers = {
		"lua_ls",
		"cssls",
		"html",
		"tsserver",
		"tailwindcss",
		"eslint",
		"bashls",
		"jsonls",
		"gopls",
	}

	require("mason").setup({
		ui = {
			border = "rounded",
		},
	})

	require("mason-lspconfig").setup({
		ensure_installed = servers,
	})
end

return M
