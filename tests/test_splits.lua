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
	child.cmd("edit test.lua")
	child.cmd("vsplit test2.lua")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "lua", buftype = "", width = 120, height = 50 },
			{ type = "leaf", filetype = "lua", buftype = "", width = 119, height = 50 },
		},
	})
end

T["vsplit"]["closing reopens zen side buffers"] = function()
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
	-- TODO
end

return T
