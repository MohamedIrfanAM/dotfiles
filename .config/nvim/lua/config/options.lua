-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Reload buffers automatically when a file changes on disk (e.g. Claude editing
-- files from the other tmux pane). LazyVim already runs `:checktime` on
-- FocusGained/TermClose/TermLeave; this makes that actually reload silently.
vim.opt.autoread = true
