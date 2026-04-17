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

T["close zen side buffers on last main quit"] = function()
	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})

	pcall(child.cmd, "q")

	local STOPPED = 0
	local exit_code = vim.fn.jobwait({ child.job.id }, 1000)[1]
	MiniTest.expect.equality(exit_code, STOPPED)
end

T["open zen side buffers on startup"] = function()
	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})
end

T["do not open zen side buffers when there is not enough space"] = function()
	child.restart({ "-u", "tests/scripts/init_with_zen_small.lua" })

	Helpers.expect.layout(child, {
		type = "leaf",
		filetype = "",
		buftype = "",
		width = 140,
		height = 50,
	})
end

T["cursor does not enter zen side buffers"] = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
			child.cmd("edit test.lua")
		end,
	},
})

T["cursor does not enter zen side buffers"]["from main"] = function()
	child.cmd("wincmd h")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "lua")

	child.cmd("wincmd l")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "lua")
end

T["cursor does not enter zen side buffers"]["from top integration"] = function()
	child.cmd("Git")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "fugitive")

	child.cmd("wincmd j")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "lua")

	child.cmd("wincmd k")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "fugitive")

	child.cmd("wincmd h")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "fugitive")

	child.cmd("wincmd l")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "fugitive")

	child.cmd("close")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "lua")
end

T["cursor does not enter zen side buffers"]["from bottom integration"] = function()
	child.cmd("Trouble diagnostics open")
	child.cmd("wincmd j")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "trouble")

	child.cmd("wincmd k")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "lua")

	child.cmd("wincmd j")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "trouble")

	child.cmd("wincmd h")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "trouble")

	child.cmd("wincmd l")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "trouble")

	child.cmd("close")
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "lua")
end

return T
