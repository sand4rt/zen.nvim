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

T["resizing below minimum width closes the side buffers"] = function()
	child.cmd("set columns-=100")
	child.cmd("doautocmd VimResized")

	Helpers.expect.layout(child, {
		type = "leaf",
		filetype = "",
		buftype = "",
		width = 140,
		height = 50,
	})
end

T["resizing above minimum width reopens the side buffers"] = function()
	child.cmd("set columns-=100")
	child.cmd("doautocmd VimResized")

	child.cmd("set columns+=100")
	child.cmd("doautocmd VimResized")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})
end


T["with hsplit"] = MiniTest.new_set({})

T["with hsplit"]["resizing below minimum width closes the side buffers"] = function()
	child.cmd("edit test.lua")
	child.cmd("split test2.lua")

	child.cmd("set columns-=100")
	child.cmd("doautocmd VimResized")

	Helpers.expect.layout(child, {
		type = "col",
		children = {
			{ type = "leaf", filetype = "lua", buftype = "", width = 140, height = 25 },
			{ type = "leaf", filetype = "lua", buftype = "", width = 140, height = 24 },
		},
	})
end

T["with hsplit"]["resizing above minimum width reopens the side buffers"] = function()
	child.cmd("edit test.lua")
	child.cmd("split test2.lua")

	child.cmd("set columns-=100")
	child.cmd("doautocmd VimResized")

	child.cmd("set columns+=100")
	child.cmd("doautocmd VimResized")

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

T["with top integration"] = MiniTest.new_set({})

T["with top integration"]["resizing below minimum width closes the side buffers"] = function()
	child.cmd("Git")

	child.cmd("set columns-=100")
	child.cmd("doautocmd VimResized")

	Helpers.expect.layout(child, {
		type = "col",
		children = {
			{ type = "leaf", filetype = "fugitive", buftype = "nowrite", width = 140, height = 25 },
			{ type = "leaf", filetype = "", buftype = "", width = 140, height = 24 },
		},
	})
end

T["with top integration"]["resizing above minimum width reopens the side buffers"] = function()
	child.cmd("Git")

	child.cmd("set columns-=100")
	child.cmd("doautocmd VimResized")

	child.cmd("set columns+=100")
	child.cmd("doautocmd VimResized")

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
end

T["with bottom integration"] = MiniTest.new_set({})

T["with bottom integration"]["resizing below minimum width closes the side buffers"] = function()
	child.cmd("Trouble diagnostics")

	child.cmd("set columns-=100")
	child.cmd("doautocmd VimResized")

	Helpers.expect.layout(child, {
		type = "col",
		children = {
			{ type = "leaf", filetype = "", buftype = "", width = 140, height = 39 },
			{ type = "leaf", filetype = "trouble", buftype = "nofile", width = 140, height = 10 },
		},
	})
end

T["with bottom integration"]["resizing above minimum width reopens the side buffers"] = function()
	child.cmd("Trouble diagnostics")

	child.cmd("set columns-=100")
	child.cmd("doautocmd VimResized")

	child.cmd("set columns+=100")
	child.cmd("doautocmd VimResized")

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
end

T["with top and bottom integration"] = MiniTest.new_set({})

T["with top and bottom integration"]["resizing below minimum width closes the side buffers"] = function()
	child.cmd("Git")
	child.cmd("Trouble diagnostics")

	child.cmd("set columns-=100")
	child.cmd("doautocmd VimResized")

	Helpers.expect.layout(child, {
		type = "col",
		children = {
			{ type = "leaf", filetype = "fugitive", buftype = "nowrite", width = 140, height = 25 },
			{ type = "leaf", filetype = "", buftype = "", width = 140, height = 13 },
			{ type = "leaf", filetype = "trouble", buftype = "nofile", width = 140, height = 10 },
		},
	})
end

return T
