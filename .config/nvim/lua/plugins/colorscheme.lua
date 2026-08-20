return {
  {
    "navarasu/onedark.nvim",
    priority = 1000,
    config = function()
      require("onedark").setup({
        style = "darker",
        transparent = true,
        highlights = {
          DiagnosticError = { fg = "#be5046" },
          DiagnosticWarn = { fg = "#d19a66" },
          DiagnosticInfo = { fg = "#61afef" },
          DiagnosticHint = { fg = "#56b6c2" },
          DiagnosticUnderlineError = {
            undercurl = true,
            sp = "#be5046",
          },
          DiagnosticUnderlineWarn = {
            undercurl = true,
            sp = "#d19a66",
          },
          -- extra groups the plugin doesn't clear by default
          NormalFloat = { bg = "none" },
          FloatBorder = { bg = "none" },
          Pmenu = { bg = "none" },
          PmenuSbar = { bg = "none" },
          StatusLine = { bg = "none" },
          StatusLineNC = { bg = "none" },
          VertSplit = { bg = "none" },
          WinSeparator = { bg = "none" },
        },
      })
      require("onedark").load()
    end,
  },
}
