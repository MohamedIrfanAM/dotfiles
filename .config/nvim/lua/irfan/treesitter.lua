local M = {
  "nvim-treesitter/nvim-treesitter",
  event = { "BufReadPost", "BufNewFile" },
  build = ":TSUpdate",
}

function M.config()
  require("nvim-treesitter.configs").setup {
    ensure_installed = { "lua", "markdown", "markdown_inline", "bash", "vimdoc", "json", "html", "css", "javascript", "typescript", "tsx", "jsonc" },
    highlight = { enable = true },
    indent = { enable = true },
  }
end

return M
