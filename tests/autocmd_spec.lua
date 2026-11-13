local Helpers = dofile("tests/scripts/helpers.lua")
local child = MiniTest.new_child_neovim()

before_each(function()
	child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
end)

teardown(child.stop)

describe("quit", function()
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

	it("keeps zen side buffers when quit is aborted by unsaved changes", function()
		child.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })

		pcall(child.cmd, "q")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
				{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
			},
		})
	end)

	for _, config in ipairs({
		{ name = "", init = "tests/scripts/init_with_zen.lua", height = 50 },
		-- noice sets `cmdheight` to 0, which gives the windows an extra row
		{ name = " with noice", init = "tests/scripts/init_with_zen_noice.lua", height = 51 },
	}) do
		for _, case in ipairs({
			{ answer = "y", exits = true, saved = true },
			{ answer = "n", exits = true, saved = false },
			{ answer = "c", exits = false, saved = false },
		}) do
			it(string.format("handles %q in the confirm dialog on quit%s", case.answer, config.name), function()
				-- the dialog needs a UI, which the headless `child` does not have, so
				-- point a child object at an instance running in a pty instead
				local tui = MiniTest.new_child_neovim()
				local address = vim.fn.tempname()
				local id = vim.fn.jobstart(
					{ vim.v.progpath, "--clean", "-n", "--listen", address, "-u", config.init },
					{ pty = true, width = 240, height = 52 }
				)
				local ok, channel = false, nil
				vim.wait(5000, function()
					ok, channel = pcall(vim.fn.sockconnect, "pipe", address, { rpc = true })
					return ok
				end, 10)
				assert(ok, channel)
				tui.job = { id = id, channel = channel, address = address }
				vim.wait(5000, function()
					return tui.lua_get("vim.v.vim_did_enter") == 1
				end, 10)

				local function expect_layout(side_buftype)
					-- mini.test refuses calls while the dialog blocks the child, but the
					-- API still answers then
					tui.is_blocked = function()
						return false
					end
					Helpers.expect.layout(tui, {
						type = "row",
						children = {
							{ type = "leaf", filetype = "zen-left", buftype = side_buftype, width = 46, height = config.height },
							{ type = "leaf", filetype = "", buftype = "", width = 146, height = config.height },
							{ type = "leaf", filetype = "zen-right", buftype = side_buftype, width = 46, height = config.height },
						},
					})
				end

				local file = vim.fn.tempname()
				tui.o.confirm = true
				tui.api.nvim_buf_set_name(0, file)
				tui.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })

				tui.type_keys(300, ":q<CR>")
				-- the side buffers count as help while the dialog is open, so that
				-- Neovim treats the main window as the last one
				expect_layout("help")
				vim.fn.chansend(id, case.answer)
				vim.wait(300)

				local STOPPED = 0
				local exit_code = vim.fn.jobwait({ id }, 1000)[1]
				MiniTest.expect.equality(exit_code == STOPPED, case.exits)
				MiniTest.expect.equality(vim.fn.filereadable(file) == 1, case.saved)
				if not case.exits then
					expect_layout("nofile")
					tui.stop()
				end
			end)
		end
	end
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

it("does not duplicate zen side buffers when setup runs again", function()
	child.lua([[require("zen").setup()]])
	child.cmd("doautocmd VimEnter")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})
end)

it("supports a callback main width", function()
	child.lua([[
		width_calls = 0
		require("zen").setup({
			main = {
				width = function()
					width_calls = width_calls + 1
					return 148
				end,
			},
		})
	]])
	MiniTest.expect.equality(child.lua_get("width_calls"), 1)

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})

	child.lua([[vim.api.nvim_exec_autocmds("CursorMoved", { modeline = false })]])
	MiniTest.expect.equality(child.lua_get("width_calls"), 1)
	MiniTest.expect.equality(
		child.lua_get([[#vim.api.nvim_get_autocmds({ group = "zen.nvim", event = "CursorMoved" })]]),
		0
	)

	child.cmd("Neotest summary open")
	child.cmd("Neotest summary close")
	MiniTest.expect.equality(child.lua_get("width_calls"), 1)

	child.cmd("doautocmd VimResized")
	MiniTest.expect.equality(child.lua_get("width_calls"), 2)

	child.cmd("doautocmd FocusGained")
	MiniTest.expect.equality(child.lua_get("width_calls"), 3)
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

it("keeps the main window when its buffer is force deleted from a floating window", function()
	child.cmd("edit test.lua")
	child.lua([[
		local buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, {
			relative = "editor",
			row = 1,
			col = 1,
			width = 10,
			height = 1,
		})
		vim.api.nvim_buf_delete(buf, { force = true })
	]])

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
	})
end)

it("keeps the main window when its buffer is force deleted from a side integration", function()
	child.lua([[
		require("zen").setup({ left = { { filetype = "*", min_width = 46 }, { filetype = "custom-sidebar" } } })
	]])
	child.cmd("edit test.lua")
	child.lua([[
		local buf = vim.api.nvim_get_current_buf()
		local sidebar = vim.api.nvim_create_buf(false, true)
		vim.bo[sidebar].filetype = "custom-sidebar"
		vim.api.nvim_open_win(sidebar, true, { split = "left", win = -1 })
		vim.api.nvim_buf_delete(buf, { force = true })
	]])

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "custom-sidebar", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
		},
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
