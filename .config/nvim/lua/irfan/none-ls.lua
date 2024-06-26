local M = {
	"nvimtools/none-ls.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
}

function M.config()
	local null_ls = require("null-ls")
	local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
	local formatting = null_ls.builtins.formatting
	local diagnostics = null_ls.builtins.diagnostics
	local completion = null_ls.builtins.completion

	null_ls.setup({
		debug = false,
		sources = {
			formatting.stylua,
			formatting.prettierd,
			completion.spell,
			formatting.gofumpt,
			formatting.goimports_revisor,
			formatting.golines,
		},
	})
end

return M
