local Helpers = dofile("tests/scripts/helpers.lua")
local child = MiniTest.new_child_neovim()

before_each(function()
	child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
end)

teardown(child.stop)

it("sizes the background Neotest summary on opening, resizing, and reopening", function()
	child.cmd("edit tests/test_resizing.lua")
	child.cmd("Neotest summary open")
	child.cmd("set columns=400")
	child.cmd("doautocmd VimResized")

	local expected = {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 126, height = 50 },
			{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "neotest-summary", buftype = "nofile", width = 126, height = 50 },
		},
	}
	Helpers.expect.layout(child, expected)

	child.cmd("Neotest summary close")
	child.cmd("Neotest summary open")
	Helpers.expect.layout(child, expected)
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "lua")
end)

it("sizes Fyler to the side width after resizing and reopening", function()
	child.cmd("edit tests/test_resizing.lua")
	child.cmd("Fyler kind=split_left_most")
	child.cmd("set columns=400")
	child.cmd("doautocmd VimResized")

	local expected = {
		type = "row",
		children = {
			{ type = "leaf", filetype = "fyler_finder", buftype = "acwrite", width = 126, height = 50 },
			{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 126, height = 50 },
		},
	}
	Helpers.expect.layout(child, expected)

	child.cmd("close")
	child.cmd("Fyler kind=split_left_most")
	Helpers.expect.layout(child, expected)
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "fyler_finder")

	child.cmd("wincmd l")
	child.cmd("set columns=440")
	child.cmd("doautocmd VimResized")
	expected.children[1].width = 146
	expected.children[3].width = 146
	Helpers.expect.layout(child, expected)
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "lua")
end)

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
