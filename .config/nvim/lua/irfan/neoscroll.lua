local M = {
  "karb94/neoscroll.nvim",
}

function M.config()
  local neoscroll = require("neoscroll")
  local centering_function = function()
      local defer_time_ms = 10
      vim.defer_fn(function()
          neoscroll.zz(50, "sine")
      end, defer_time_ms)
  end

  neoscroll.setup {
    -- All these keys will be mapped to their corresponding default scrolling animation
    mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "<C-y>", "<C-e>", "zt", "zz", "zb", "C-k", "C-j" },
    hide_cursor = true, -- Hide cursor while scrolling
    stop_eof = false, -- Stop at <EOF> when scrolling downwards
    respect_scrolloff = true, -- Stop scrolling when the cursor reaches the scrolloff margin of the file
    cursor_scrolls_alone = true, -- The cursor will keep on scrolling even if the window cannot scroll further
    easing_function = nil, -- Default easing function
    pre_hook = nil, -- Function to run before the scrolling animation starts
    post_hook = function(info)
        if info ~= "center" then
            return
        end
        centering_function()
    end, -- Function to run after the scrolling animation ends
    performance_mode = false, -- Disable "Performance Mode" on all buffers.
  }

  local t = {}
  -- Syntax: t[keys] = {function, {function arguments}}
  t["<C-u>"] = { "scroll", { "-vim.wo.scroll", "true", "50", "sine", "'center'"} }
  t["<C-d>"] = { "scroll", { "vim.wo.scroll", "true", "50", "sine", "'center'" } }
  t["<C-b>"] = { "scroll", { "-vim.api.nvim_win_get_height(0)", "true", "150" } }
  t["<C-f>"] = { "scroll", { "vim.api.nvim_win_get_height(0)", "true", "150" } }
  t["<C-y>"] = { "scroll", { "-0.10", "false", "100" } }
  t["<C-e>"] = { "scroll", { "0.10", "false", "100" } }
  t["zt"] = { "zt", { "50" } }
  t["zz"] = { "zz", { "50" } }
  t["zb"] = { "zb", { "50" } }

  require("neoscroll.config").set_mappings(t)
end

return M
