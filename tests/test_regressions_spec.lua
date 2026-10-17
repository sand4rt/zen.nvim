local Helpers = dofile("tests/scripts/helpers.lua")
local MiniTest = require("mini.test")
local child = MiniTest.new_child_neovim()

before_each(function()
	child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
end)

teardown(child.stop)

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
