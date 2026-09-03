return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          hidden = true,
          win = {
            list = {
              keys = {
                -- mirrors the global <leader>g Diffview toggle (see plugins/diffview.lua)
                -- so it also works with focus inside the explorer
                ["<leader>g"] = function()
                  if next(require("diffview.lib").views) then
                    vim.cmd("DiffviewClose")
                  else
                    vim.cmd("DiffviewOpen")
                  end
                end,
              },
            },
          },
        },
        files = {
          hidden = true,
        },
        grep = {
          hidden = true,
        },
      },
    },
  },
}
