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

T["vsplit"] = MiniTest.new_set({})

T["vsplit"]["opening closes zen side buffers"] = function()
	child.cmd("vsplit")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "", buftype = "", width = 120, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 119, height = 50 },
		},
	})
end

T["vsplit"]["closing reopens zen side buffers"] = function()
	child.cmd("vsplit")
	child.cmd("q")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})
end

T["vsplit"]["closing does not reopen zen side buffers when below minimum width"] = function()
	child.cmd("edit test.lua")
	child.cmd("vsplit test2.lua")

	child.cmd("set columns-=100")
	child.cmd("doautocmd VimResized")

	child.cmd("q")

	Helpers.expect.layout(child, {
		type = "leaf",
		filetype = "lua",
		buftype = "",
		width = 140,
		height = 50,
	})
end

T["hsplit"] = MiniTest.new_set({})

T["hsplit"]["opening does not close the side buffers"] = function()
	child.cmd("edit test.lua")
	child.cmd("split test2.lua")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{
				type = "col",
				children = {
					{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 25 },
					{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 24 },
				},
			},
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})
end

T["hsplit"]["opening with a top integration"] = function()
	child.cmd("Git")

	Helpers.expect.layout(child, {
		type = "col",
		children = {
			{ type = "leaf", filetype = "fugitive", buftype = "nowrite", width = 240, height = 25 },
			{
				type = "row",
				children = {
					{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 24 },
					{ type = "leaf", filetype = "", buftype = "", width = 146, height = 24 },
					{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 24 },
				},
			},
		},
	})

	child.cmd("wincmd j | wincmd l")
	child.cmd("split test.lua")

	Helpers.expect.layout(child, {
		type = "col",
		children = {
			{ type = "leaf", filetype = "fugitive", buftype = "nowrite", width = 240, height = 16 },
			{
				type = "row",
				children = {
					{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 33 },
					{
						type = "col",
						children = {
							{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 16 },
							{ type = "leaf", filetype = "", buftype = "", width = 146, height = 16 },
						},
					},
					{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 33 },
				},
			},
		},
	})
end

T["hsplit"]["closing with a top integration without layout shift"] = function()
	child.cmd("split")
	child.cmd("Git")

	Helpers.expect.layout(child, {
		type = "col",
		children = {
			{ type = "leaf", filetype = "fugitive", buftype = "nowrite", width = 240, height = 16 },
			{
				type = "row",
				children = {
					{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 33 },
					{
						type = "col",
						children = {
							{ type = "leaf", filetype = "", buftype = "", width = 146, height = 16 },
							{ type = "leaf", filetype = "", buftype = "", width = 146, height = 16 },
						},
					},
					{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 33 },
				},
			},
		},
	})

	child.cmd("close")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{
				type = "col",
				children = {
					{ type = "leaf", filetype = "", buftype = "", width = 146, height = 25 },
					{ type = "leaf", filetype = "", buftype = "", width = 146, height = 24 },
				},
			},
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})
end

return T
