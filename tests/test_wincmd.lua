local Helpers = dofile("tests/scripts/helpers.lua")
local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
		end,
		post_once = child.stop,
	},
})

T["moving a window to the side does not go past zen buffers"] = function()
	child.cmd("wincmd H")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})

	child.cmd("wincmd L")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})
end

T["moving a window to the side does not go past integrations"] = function()
	child.cmd("Fyler kind=split_left_most")
	child.cmd("Neotest summary open")

	child.cmd("wincmd H")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "fyler", buftype = "acwrite", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "neotest-summary", buftype = "nofile", width = 46, height = 50 },
		},
	})

	child.cmd("wincmd L")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "fyler", buftype = "acwrite", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "neotest-summary", buftype = "nofile", width = 46, height = 50 },
		},
	})
end

T["hsplit"] = MiniTest.new_set({})

T["hsplit"]["moving a window below keeps it between zen buffers"] = function()
	child.cmd("edit test.lua")
	child.cmd("split test.rs")

	child.cmd("wincmd J")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{
				type = "col",
				children = {
					{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 24 },
					{ type = "leaf", filetype = "rust", buftype = "", width = 146, height = 25 },
				},
			},
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})
end

T["hsplit"]["moving a window above keeps it between zen buffers"] = function()
	child.cmd("edit test.lua")
	child.cmd("split test.rs")

	child.cmd("wincmd j")
	child.cmd("wincmd K")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{
				type = "col",
				children = {
					{ type = "leaf", filetype = "rust", buftype = "", width = 146, height = 24 },
					{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 25 },
				},
			},
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})
end

return T
