local Helpers = dofile("tests/scripts/helpers.lua")
local child = MiniTest.new_child_neovim()

before_each(function()
	child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
end)

teardown(child.stop)

it("resizing below minimum width closes the side buffers", function()
	child.cmd("set columns-=100")
	child.cmd("doautocmd VimResized")

	Helpers.expect.layout(child, {
		type = "leaf",
		filetype = "",
		buftype = "",
		width = 140,
		height = 50,
	})
end)

it("resizing above minimum width reopens the side buffers", function()
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
end)

describe("with top integration", function()
	it("resizing below minimum width closes the side buffers", function()
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
	end)

	it("resizing above minimum width reopens the side buffers", function()
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
	end)
end)

describe("with bottom integration", function()
	it("resizing below minimum width closes the side buffers", function()
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
	end)

	it("resizing above minimum width reopens the side buffers", function()
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
	end)
end)

describe("with top and bottom integration", function()
	it("resizing below minimum width closes the side buffers", function()
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
	end)
end)
