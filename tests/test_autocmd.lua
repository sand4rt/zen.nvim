local Helpers = dofile("tests/scripts/helpers.lua")
local child = MiniTest.new_child_neovim()

before_each(function()
	child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
end)

teardown(child.stop)

it("closes zen side buffers on last main quit", function()
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
end)

it("opens zen side buffers on startup", function()
	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})
end)

it("does not open zen side buffers when there is not enough space", function()
	child.restart({ "-u", "tests/scripts/init_with_zen_small.lua" })

	Helpers.expect.layout(child, {
		type = "leaf",
		filetype = "",
		buftype = "",
		width = 140,
		height = 50,
	})
end)

describe("cursor does not enter zen side buffers", function()
	before_each(function()
		child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
		child.cmd("edit test.lua")
	end)

	it("from main", function()
		child.cmd("wincmd h")
		MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "lua")

		child.cmd("wincmd l")
		MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "lua")
	end)

	it("from top integration", function()
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
	end)

	it("from bottom integration", function()
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
	end)
end)
