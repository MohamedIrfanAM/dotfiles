-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
-- cmd+p (find files) and cmd+w (close buffer) are handled in Ghostty's config,
-- which sends <leader>ff / <leader>bd instead — terminals don't reliably pass
-- Cmd-modified keys through as <D-p>/<D-w>.

-- LazyVim's default lazygit/git-log/blame/browse binds all live under lowercase
-- <leader>g*, which makes bare <leader>g (Diffview toggle) wait out timeoutlen
-- as a prefix key. Drop them so <leader>g fires instantly.
for _, lhs in ipairs({ "<leader>gg", "<leader>gG", "<leader>gL", "<leader>gb", "<leader>gf", "<leader>gl", "<leader>gB", "<leader>gY" }) do
  pcall(vim.keymap.del, { "n", "x" }, lhs)
end
