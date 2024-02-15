local opts = { noremap = true, silent = true }

local term_opts = { silent = true }

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Modes
--   normal_mode = "n",
--   insert_mode = "i",
--   visual_mode = "v",
--   visual_block_mode = "x",
--   term_mode = "t",
--   command_mode = "c",

-- Normal --
-- Better window navigation
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

-- Comments --
keymap("n","<C-/>",":lua require('Comment.api').toggle.linewise()<CR>" ,opts)
keymap("v","<C-/>",":lua require('Comment.api').locked('toggle.linewise')(vim.fn.visualmode())<CR>" ,opts)

-- Resize with arrows --
keymap("n", "<C-Up>", ":resize -2<CR>", opts)
keymap("n", "<C-Down>", ":resize +2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Open URL --
keymap("n", "gx",'<Cmd>call jobstart(["xdg-open", expand("<cfile>")], {"detach": v:true})<CR>', opts)
keymap("n", "<C-LeftMouse>",'<Cmd>call jobstart(["xdg-open", expand("<cfile>")], {"detach": v:true})<CR>', opts)

-- Navigate buffers --
keymap("n", "<S-k>", ":BufferLineCycleNext<CR>", opts)
keymap("n", "<S-j>", ":BufferLineCyclePrev<CR>", opts)

-- CP Booster --
keymap("n", "<a-t>", ":Test<CR><C-w>l:vertical resize 35<CR><C-w>h", opts)
keymap("n", "<a-T>", ":Rtest<CR><C-w>l:vertical resize 35<CR><C-w>h", opts)
keymap("n", "<a-d>", ":Debug<CR><C-\\><C-n>:vertical resize 35<CR>i", opts)
keymap("n", "<a-D>", ":Rdebug<CR><C-\\><C-n>:vertical resize 35<CR>i", opts)
keymap("n", "<a-s>", ":Submit<CR><C-w>l:vertical resize 35<CR><C-w>h", opts)
keymap("n", "<a-a>", ":Addtc<CR>:vertical resize 35<CR>", opts)
vim.cmd [[ command! -nargs=1 Include  call feedkeys("mZ") | call timer_start(1, { tid -> execute('26r /home/irfan/cp/.utils/library/<args>.cpp')}) | call timer_start(1, { tid -> execute('call feedkeys("`Z")')}) ]]

-- Standard bindings --
keymap("n", "<C-w>", ":Bdelete!<CR>",opts)
keymap("n", "<C-e>", ":NvimTreeToggle<cr>",opts)
keymap("n", "<C-s>", ":w><cr>",opts)
keymap("n", "<C-a>", "mZgg0yG`Z",opts)

-- Insert --
-- Press jk fast to enter
keymap("i", "jk", "<ESC>", opts)
keymap("i", "kj", "<ESC>", opts)

-- fl and lf for right arrow
keymap("i","fl","<right>",opts);
keymap("i","lf","<right>",opts);

-- Visual --
-- Stay in indent mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- visual paste persistance
keymap("v", "p", '"_dP', opts)

-- Visual Block --
-- Move text up and down
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)

-- Terminal --
-- Better terminal navigation
keymap("t", "<C-h>", "<C-\\><C-N><C-w>h", term_opts)
keymap("t", "<C-j>", "<C-\\><C-N><C-w>j", term_opts)
keymap("t", "<C-k>", "<C-\\><C-N><C-w>k", term_opts)
keymap("t", "<C-l>", "<C-\\><C-N><C-w>l", term_opts)
