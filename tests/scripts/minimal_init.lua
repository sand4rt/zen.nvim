vim.cmd([[let &rtp.=','.getcwd()]])
vim.opt.packpath:prepend("deps")

require("mini.test").setup({
	collect = {
		emulate_busted = true,
		find_files = function()
			return vim.fn.globpath("tests", "**/*_spec.lua", true, true)
		end,
	},
})
