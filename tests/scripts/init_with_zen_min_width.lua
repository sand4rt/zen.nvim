vim.cmd([[let &rtp.=','.getcwd()]])
vim.opt.packpath:prepend("deps")

vim.o.columns = 240
vim.o.lines = 52

require("mini.test").setup()
require("CopilotChat").setup()

require("zen").setup({
	right = {
		{ filetype = "*", min_width = 46 },
		{ filetype = "copilot-chat", min_width = 60 },
	},
})
