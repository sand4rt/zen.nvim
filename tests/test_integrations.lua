local Helpers = dofile("tests/scripts/helpers.lua")
local child = MiniTest.new_child_neovim()

before_each(function()
	child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
end)

teardown(child.stop)

describe("left integration", function()
	it("opening closes zen side buffer, closing reopens it", function()
		child.cmd("Fyler kind=split_left_most")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "fyler_finder", buftype = "acwrite", width = 46, height = 50 },
				{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
				{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
			},
		})

		child.cmd("close")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
				{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
			},
		})
	end)

	it("opening an integration should close the existing integration on the same side", function()
		child.cmd("Fyler kind=split_left_most")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "fyler_finder", buftype = "acwrite", width = 46, height = 50 },
				{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
				{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
			},
		})

		child.cmd("DBUI")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "dbui", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
				{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
			},
		})
	end)

	it("opening an integration on a small window", function()
		child.restart({ "-u", "tests/scripts/init_with_zen_small.lua" })

		child.cmd("Fyler kind=split_left_most")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "fyler_finder", buftype = "acwrite", width = 35, height = 50 },
				{ type = "leaf", filetype = "", buftype = "", width = 104, height = 50 },
			},
		})
	end)
end)

describe("top integration", function()
	it("opening", function()
		child.cmd("Git")

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

	it("opening an integration should close the existing integration on the same side", function()
		child.cmd("Git")

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

		child.cmd("Man ls")

		Helpers.expect.layout(child, {
			type = "col",
			children = {
				{ type = "leaf", filetype = "man", buftype = "nofile", width = 240, height = 25 },
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

	for _, case in ipairs({ { name = "above" }, { name = "below" } }) do
		it("stacks " .. case.name .. " when configured " .. case.name .. " with replace=false", function()
			if case.name == "below" then
				child.restart({ "-u", "tests/scripts/init_with_zen_top_order.lua" })
			end

			child.lua([[
			local tmpdir = vim.fn.tempname()
			vim.fn.mkdir(tmpdir, "p")
			vim.fn.system({ "git", "init", tmpdir })
			vim.fn.system({ "git", "-C", tmpdir, "config", "user.name", "Test" })
			vim.fn.system({ "git", "-C", tmpdir, "config", "user.email", "test@test.com" })
			vim.fn.system({ "git", "-C", tmpdir, "commit", "--allow-empty", "-m", "initial" })
			vim.fn.writefile({ "hello" }, tmpdir .. "/file")
			vim.cmd("edit " .. tmpdir .. "/file")
		]])

			child.cmd("Git")

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

			child.cmd("Git commit --allow-empty")

			Helpers.expect.layout(child, {
				type = "col",
				children = {
					{
						type = "leaf",
						filetype = case.name == "above" and "gitcommit" or "fugitive",
						buftype = case.name == "above" and "" or "nowrite",
						width = 240,
						height = 12,
					},
					{
						type = "leaf",
						filetype = case.name == "above" and "fugitive" or "gitcommit",
						buftype = case.name == "above" and "nowrite" or "",
						width = 240,
						height = 12,
					},
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

			child.cmd("q")

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
	end

	it("closing a git commit keeps the top and bottom stacks intact", function()
		-- Regression: creating a commit in fugitive and then closing the gitcommit
		-- window used to abort the reposition handlers with `E242: Can't split a
		-- window while closing another`, because recreating a side buffer on
		-- `WinClosed` re-enters `reposition_stack` mid-close. The close must leave
		-- the fugitive (top) and trouble (bottom) stacks intact instead.
		child.lua([[
		local tmpdir = vim.fn.tempname()
		vim.fn.mkdir(tmpdir, "p")
		vim.fn.system({ "git", "init", tmpdir })
		vim.fn.system({ "git", "-C", tmpdir, "config", "user.name", "Test" })
		vim.fn.system({ "git", "-C", tmpdir, "config", "user.email", "test@test.com" })
		vim.fn.system({ "git", "-C", tmpdir, "commit", "--allow-empty", "-m", "initial" })
		vim.fn.writefile({ "hello" }, tmpdir .. "/file")
		vim.cmd("edit " .. tmpdir .. "/file")
	]])

		child.cmd("Git")
		child.cmd("Trouble diagnostics")
		child.cmd("wincmd t")
		child.cmd("Git commit --allow-empty")
		child.cmd("q")

		Helpers.expect.layout(child, {
			type = "col",
			children = {
				{ type = "leaf", filetype = "fugitive", buftype = "nowrite", width = 240, height = 25 },
				{
					type = "row",
					children = {
						{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 13 },
						{ type = "leaf", filetype = "", buftype = "", width = 146, height = 13 },
						{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 13 },
					},
				},
				{ type = "leaf", filetype = "trouble", buftype = "nofile", width = 240, height = 10 },
			},
		})
	end)
end)

describe("bottom integration", function()
	it("opening", function()
		child.cmd("Trouble diagnostics")

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

	it("opening an integration should close the existing integration on the same side", function()
		child.cmd("Trouble diagnostics")

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

		child.cmd("copen")

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
				{ type = "leaf", filetype = "qf", buftype = "quickfix", width = 240, height = 10 },
			},
		})
	end)
end)

describe("right integration", function()
	it("opening closes zen side buffer, closing reopens it", function()
		child.cmd("Neotest summary open")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "", buftype = "", width = 142, height = 50 },
				{ type = "leaf", filetype = "neotest-summary", buftype = "nofile", width = 50, height = 50 },
			},
		})

		child.cmd("Neotest summary close")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
				{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
			},
		})
	end)

	it("opening an integration should close the existing integration on the same side", function()
		child.cmd("Neotest summary open")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "", buftype = "", width = 142, height = 50 },
				{ type = "leaf", filetype = "neotest-summary", buftype = "nofile", width = 50, height = 50 },
			},
		})

		child.lua([[vim.o.splitright = true; require("CopilotChat").open()]])

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
				{ type = "leaf", filetype = "copilot-chat", buftype = "nofile", width = 46, height = 50 },
			},
		})
	end)

	it("opening an integration with table filetype", function()
		child.lua([[require("dapui").open()]])

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{
					type = "col",
					children = {
						{ type = "leaf", filetype = "dapui_watches", buftype = "prompt", width = 40, height = 12 },
						{ type = "leaf", filetype = "dapui_stacks", buftype = "nofile", width = 40, height = 12 },
						{ type = "leaf", filetype = "dapui_breakpoints", buftype = "nofile", width = 40, height = 12 },
						{ type = "leaf", filetype = "dapui_scopes", buftype = "nofile", width = 40, height = 11 },
					},
				},
				{
					type = "col",
					children = {
						{ type = "leaf", filetype = "", buftype = "", width = 199, height = 39 },
						{
							type = "row",
							children = {
								{ type = "leaf", filetype = "dapui_console", buftype = "nofile", width = 99, height = 10 },
								{ type = "leaf", filetype = "dap-repl", buftype = "prompt", width = 99, height = 10 },
							},
						},
					},
				},
			},
		})
	end)
end)

local min_width_child = MiniTest.new_child_neovim()

describe("min_width", function()
	before_each(function()
		min_width_child.restart({ "-u", "tests/scripts/init_with_zen_min_width.lua" })
	end)

	teardown(min_width_child.stop)

	it("integration with a larger min_width should override the wildcard default", function()
		min_width_child.lua([[vim.o.splitright = true; require("CopilotChat").open()]])

		Helpers.expect.layout(min_width_child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "", buftype = "", width = 132, height = 50 },
				{ type = "leaf", filetype = "copilot-chat", buftype = "nofile", width = 60, height = 50 },
			},
		})
	end)
end)
