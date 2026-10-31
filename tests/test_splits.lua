local Helpers = dofile("tests/scripts/helpers.lua")
local child = MiniTest.new_child_neovim()

before_each(function()
	child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
end)

teardown(child.stop)

describe("vsplit", function()
	it("opening closes zen side buffers", function()
		child.cmd("edit test.lua")
		child.cmd("vsplit test2.lua")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "lua", buftype = "", width = 120, height = 50 },
				{ type = "leaf", filetype = "lua", buftype = "", width = 119, height = 50 },
			},
		})
	end)

	it("closing reopens zen side buffers", function()
		child.cmd("edit test.lua")
		child.cmd("vsplit test2.lua")
		child.cmd("q")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 50 },
				{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
			},
		})
	end)

	it("splitting the current buffer closes zen side buffers", function()
		child.cmd("edit test.lua")
		child.cmd("vsplit")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "lua", buftype = "", width = 120, height = 50 },
				{ type = "leaf", filetype = "lua", buftype = "", width = 119, height = 50 },
			},
		})
	end)

	it("reopening zen side buffers after a split keeps them open", function()
		child.cmd("edit test.lua")
		child.cmd("vsplit")
		child.cmd("q")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 50 },
				{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
			},
		})
	end)

	it("closing does not reopen zen side buffers when below minimum width", function()
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
	end)
end)

describe("hsplit", function()
	it("opening does not close the side buffers", function()
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
	end)

	it("closing keeps the side buffers", function()
		child.cmd("edit test.lua")
		child.cmd("split test2.lua")
		child.cmd("q")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 50 },
				{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
			},
		})
	end)

	it("resizing below minimum width closes the side buffers", function()
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
	end)

	it("resizing above minimum width reopens the side buffers", function()
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
	end)

	it("a vsplit inside a split closes the side buffers", function()
		child.cmd("edit test.lua")
		child.cmd("split test2.lua")
		child.cmd("vsplit test3.lua")

		Helpers.expect.layout(child, {
			type = "col",
			children = {
				{
					type = "row",
					children = {
						{ type = "leaf", filetype = "lua", buftype = "", width = 120, height = 25 },
						{ type = "leaf", filetype = "lua", buftype = "", width = 119, height = 25 },
					},
				},
				{ type = "leaf", filetype = "lua", buftype = "", width = 240, height = 24 },
			},
		})
	end)
end)
