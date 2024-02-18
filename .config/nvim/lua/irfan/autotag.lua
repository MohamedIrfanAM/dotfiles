local M = {
  "windwp/nvim-ts-autotag",
}

function M.config()
  require("nvim-ts-autotag").setup {
    enable = true,
    enable_rename = true,
    enable_close = true,
    enable_close_on_slash = true,

    filetypes = {
      "html",
      "javascript",
      "typescript",
      "javascriptreact",
      "typescriptreact",
      "tsx",
      "jsx",
      "markdown",
    },
  }
end

return M
