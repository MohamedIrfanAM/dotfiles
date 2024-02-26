return {
    "decaycs/decay.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require('decay').setup({
        style = 'dark',
        nvim_tree = {
          contrast = true, 
          },
        })
        vim.api.nvim_set_hl(0, 'FloatBorder', {fg = '#242931'})
      end,
}
