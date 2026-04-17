vim.cmd([[let &rtp.=','.getcwd()]])
vim.opt.packpath:prepend("deps")

vim.o.columns = 140
vim.o.lines = 52

require("mini.test").setup()
require("trouble").setup({ open_no_results = true })
require("fyler").setup({})
require("neotest").setup({ adapters = {} })
require("zen").setup({
	top = {
		{ filetype = "fugitive" },
	},
	bottom = {
		{ filetype = "trouble" },
	},
	left = {
		{ filetype = "*", min_width = 46 },
		{ filetype = "fyler" },
	},
	right = {
		{ filetype = "*", min_width = 46 },
		{ filetype = "neotest-summary" },
	},
})
