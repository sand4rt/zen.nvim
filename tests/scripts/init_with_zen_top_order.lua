vim.cmd([[let &rtp.=','.getcwd()]])
vim.opt.packpath:prepend(vim.fn.fnamemodify("deps", ":p"))

vim.o.columns = 240
vim.o.lines = 52

require("mini.test").setup()

require("zen").setup({
	top = {
		{ filetype = "fugitive" },
		{ filetype = "gitcommit", replace = false },
	},
})
