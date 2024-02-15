return {
    "decaycs/decay.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require('decay').setup({
        style = 'default',
        nvim_tree = {
          contrast = true, 
          },
        })    
      end,
}
