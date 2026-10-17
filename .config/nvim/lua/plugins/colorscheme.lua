return {
  {
    "decaycs/decay.nvim",
    name = "decay",
    lazy = false,
    priority = 1000,
    init = function()
      -- decay.nvim has no `transparent` option; clear the bg after it loads so
      -- ghostty's opacity/blur shows through, like onedark's transparent = true did
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "decay*",
        callback = function()
          for _, group in ipairs({
            "Normal",
            "NormalNC",
            "NormalFloat",
            "FloatBorder",
            "SignColumn",
            "LineNr",
            "EndOfBuffer",
            "Pmenu",
            "PmenuSbar",
            "StatusLine",
            "StatusLineNC",
            "VertSplit",
            "WinSeparator",
          }) do
            local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
            hl.bg = nil
            vim.api.nvim_set_hl(0, group, hl)
          end
        end,
      })
    end,
    config = function()
      -- styles: default (green accent, matches Zed "Decay"), dark, decayce, cosmic
      require("decay").setup({
        style = "default",
        italics = { code = true, comments = true },
      })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "decay-default" },
  },
}
