-- Full-tab diff review: bigger split view + file panel, instead of the
-- Snacks git-status picker's compact list+preview. Staging in the file
-- panel is whole-file (s/-, S, U) — no hunk interaction required.
return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      {
        "<leader>gv",
        function()
          if next(require("diffview.lib").views) then
            vim.cmd("DiffviewClose")
          else
            vim.cmd("DiffviewOpen")
          end
        end,
        desc = "Diffview (working tree)",
      },
      { "<leader>gV", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview File History" },
    },
  },
}
