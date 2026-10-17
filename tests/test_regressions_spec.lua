local Helpers = dofile("tests/scripts/helpers.lua")
local MiniTest = require("mini.test")
local child = MiniTest.new_child_neovim()

before_each(function()
	child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
end)

teardown(child.stop)

describe("tabpage created while zen is disabled", function()
	it("creates the side buffers on VimResized without errors", function()
		-- Regression: the tabpage has no `state` entry because the TabNew
		-- guard skipped it (columns below the main width), so the VimResized
		-- handler used to crash with `attempt to index a nil value` at
		-- `state[tab].left = create_window("left")` and leave orphan windows.
		child.restart({ "-u", "tests/scripts/init_with_zen_small.lua" })
		child.cmd("tab split")
		child.cmd("set columns=240")
		child.cmd("doautocmd VimResized")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 49 },
				{ type = "leaf", filetype = "", buftype = "", width = 146, height = 49 },
				{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 49 },
			},
		})
	end)
end)

describe("integration not covered by the recreate lists", function()
	it("closing a split does not reopen zen-right beside copilot-chat", function()
		-- Regression: `copilot-chat` replaced zen-right when it opened, but
		-- the WinClosed handler decided whether to recreate zen-right from a
		-- hardcoded filetype list that does not contain `copilot-chat`, so
		-- closing any split recreated zen-right next to it.
		child.lua([[vim.o.splitright = true; require("CopilotChat").open()]])
		child.cmd("vsplit")
		child.cmd("q")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
				{ type = "leaf", filetype = "copilot-chat", buftype = "nofile", width = 46, height = 50 },
			},
		})
	end)
end)

describe("calling setup twice", function()
	it("does not duplicate the side buffers on startup", function()
		-- Regression: setup() created every autocmd again without a
		-- group/guard, so both VimEnter handlers ran and each created a pair
		-- of side windows (5 windows at startup).
		child.restart({ "-u", "tests/scripts/init_with_zen_twice.lua" })

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
				{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
			},
		})
	end)
end)

describe("closing the last main window", function()
	it("keeps integrations open in other tabpages", function()
		-- Regression: the QuitPre handler closed integration windows via
		-- nvim_list_wins(), which spans all tabpages, so quitting the only
		-- editable window of one tab silently closed e.g. Trouble in another.
		child.cmd("edit a.lua")
		child.cmd("tabnew")
		child.cmd("Trouble diagnostics")
		child.cmd("tabnext 1")
		child.cmd("q")

		Helpers.expect.layout(child, {
			type = "col",
			children = {
				{
					type = "row",
					children = {
						{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 39 },
						{ type = "leaf", filetype = "", buftype = "", width = 146, height = 39 },
						{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 39 },
					},
				},
				{ type = "leaf", filetype = "trouble", buftype = "nofile", width = 240, height = 10 },
			},
		})
	end)
end)

describe("resizing with multiple tabpages open", function()
	it("resizes the side buffers of the current tabpage", function()
		-- Regression: the VimResized guard counted distinct editable buffers
		-- across ALL tabpages, so with two tabs open it always bailed out and
		-- the side windows kept their stale widths.
		child.cmd("tabnew")
		child.cmd("set columns=320")
		child.cmd("doautocmd VimResized")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 86, height = 49 },
				{ type = "leaf", filetype = "", buftype = "", width = 146, height = 49 },
				{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 86, height = 49 },
			},
		})
	end)
end)

describe("when the margin for side buffers is below one column", function()
	it("does not create side buffers", function()
		-- Regression: at columns == main_width + 1 the side windows were
		-- created with a width of 0.
		child.restart({ "-u", "tests/scripts/init_with_zen_small.lua" })
		child.cmd("set columns=149")
		child.cmd("doautocmd VimResized")

		Helpers.expect.layout(child, {
			type = "leaf",
			filetype = "",
			buftype = "",
			width = 149,
			height = 50,
		})
	end)

	it("closes existing side buffers", function()
		child.cmd("set columns=149")
		child.cmd("doautocmd VimResized")

		Helpers.expect.layout(child, {
			type = "leaf",
			filetype = "",
			buftype = "",
			width = 149,
			height = 50,
		})
	end)
end)

describe("resizing with a same-buffer vsplit", function()
	it("does not recreate the side buffers next to the split", function()
		-- Regression: get_editable_files() deduplicated by buffer, so a
		-- vsplit of the same buffer counted as a single editable file and the
		-- VimResized handler recreated the side windows beside the split.
		child.cmd("edit a.lua")
		child.cmd("vsplit")
		child.cmd("set columns=250")
		child.cmd("doautocmd VimResized")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "lua", buftype = "", width = 120, height = 50 },
				{ type = "leaf", filetype = "lua", buftype = "", width = 129, height = 50 },
			},
		})
	end)
end)
