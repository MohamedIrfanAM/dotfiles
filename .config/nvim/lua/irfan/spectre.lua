local M = {
	"nvim-pack/nvim-spectre",
	dependencies = { { "nvim-lua/plenary.nvim" } },
}

function M.config()
	require("spectre").setup()
	local wk = require("which-key")
	wk.register({
		["<leader>ss"] = { '<cmd>lua require("spectre").toggle()<CR>', "Spectre" },
		["<leader>sw"] = { '<cmd>lua require("spectre").open_visual({select_word=true})<CR>', "Search word" },
		["<leader>sf"] = {
			'<cmd>lua require("spectre").open_file_search({select_word=true})<CR>',
			"Search current file",
		},
	})

	wk.register({
		["<leader>sw"] = { '<cmd>lua require("spectre").open_visual()<CR>', "Search selection", mode = "v" },
	})
end

return M
