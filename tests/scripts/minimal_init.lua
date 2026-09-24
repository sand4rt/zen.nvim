vim.cmd([[let &rtp.=','.getcwd()]])
vim.opt.packpath:prepend("deps")

require("mini.test").setup({
	collect = {
		emulate_busted = true,
	},
})
