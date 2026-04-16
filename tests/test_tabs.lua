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

T["open zen side buffers on a new tab"] = function()
	child.cmd("tabnew")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 49 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 49 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 49 },
		},
	})
end

return T
