vim.cmd([[let &rtp.=','.getcwd()]])
vim.cmd("set rtp+=deps/mini.nvim")

vim.o.columns = 240
vim.o.lines = 52

require("mini.test").setup()
require("zen").setup()
