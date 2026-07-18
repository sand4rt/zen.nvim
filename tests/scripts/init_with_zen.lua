vim.cmd([[let &rtp.=','.getcwd()]])
vim.opt.packpath:prepend("deps")

vim.o.columns = 240
vim.o.lines = 52

require("mini.test").setup()
require("trouble").setup({ open_no_results = true })
require("fyler").setup({})
require("neotest").setup({ adapters = {} })
require("dapui").setup({})
require("CopilotChat").setup({})

require("zen").setup({
	top = {
		{ filetype = "gitcommit", replace = false },
		{ filetype = "fugitive" },
		{ filetype = "man" },
	},
	bottom = {
		{ filetype = "trouble" },
		{ filetype = "qf" },
	},
	left = {
		{ filetype = "*", min_width = 46 },
		{ filetype = "fyler_finder" },
		{ filetype = "dbui" },
	},
	right = {
		{ filetype = "*", min_width = 46 },
		{ filetype = "neotest-summary" },
		{ filetype = "copilot-chat" },
		{ filetype = { "dapui_watches", "dapui_scopes", "dapui_stacks", "dapui_breakpoints" } },
	},
})
