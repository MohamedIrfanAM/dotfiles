local M = {
	"nvim-pack/nvim-spectre",
	dependencies = { { "nvim-lua/plenary.nvim" } },
}

function M.config()
	require("spectre").setup({
		mapping = {
			["run_current_replace"] = {
				map = "<leader>R",
				cmd = "<cmd>lua require('spectre.actions').run_current_replace()<CR>",
				desc = "replace current line",
			},
			["run_replace"] = {
				map = "<leader>A",
				cmd = "<cmd>lua require('spectre.actions').run_replace()<CR>",
				desc = "replace all",
			},
		},
	})
	local wk = require("which-key")
	wk.register({
		["<leader>ss"] = { '<cmd>lua require("spectre").toggle()<CR>', "Spectre" },
		["<leader>sw"] = { '<cmd>lua require("spectre").open_visual({select_word=true})<CR>', "Search word" },
		["<leader>sf"] = {
			'<cmd>lua require("spectre").open_file_search()<CR>',
			"Search current file",
		},
	})

	wk.register({
		["<leader>sw"] = { '<cmd>lua require("spectre").open_visual()<CR>', "Search selection", mode = "v" },
	})
end

return M
