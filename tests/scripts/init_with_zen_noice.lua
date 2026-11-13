dofile("tests/scripts/init_with_zen.lua")

-- mirrors a real-world noice setup with a centered confirm popup and a
-- `cmdline_input` view for prompts
require("noice").setup({
	cmdline = {
		format = {
			cmdline = { title = "", pattern = "^:", icon = ":", lang = "vim" },
			input = { title = "", view = "cmdline_input" },
		},
	},
	messages = { view = "mini", view_error = "mini", view_warn = "mini" },
	notify = { view = "mini" },
	health = { checker = false },
	views = {
		cmdline_input = { border = { style = "single" } },
		cmdline_popup = {
			position = { row = 6, col = "50%" },
			size = { width = 94, height = 1 },
			border = { style = "single" },
		},
		confirm = {
			backend = "popup",
			relative = "editor",
			focusable = false,
			align = "center",
			enter = false,
			zindex = 210,
			format = { "{confirm}" },
			position = { row = "35%", col = "50%" },
			size = "auto",
			border = { style = "single", padding = { 1, 4 }, text = { top = "" } },
		},
	},
})
