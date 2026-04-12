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

T["close side buffers on last main quit"] = function()
	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})

	pcall(child.cmd, "q")

	local RUNNING = -1
	MiniTest.expect.equality(vim.fn.jobwait({ child.job.id })[1] ~= RUNNING, true)
end

return T
