local Helpers = dofile("tests/scripts/helpers.lua")
local child = MiniTest.new_child_neovim()

before_each(function()
	child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
end)

teardown(child.stop)

it("opens zen side buffers on a new tab", function()
	child.cmd("tabnew")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 49 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 49 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 49 },
		},
	})
end)

it("closes tab on last main quit", function()
	child.cmd("tabnew")
	child.cmd("q")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})
end)
