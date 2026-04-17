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

T["left integration"] = MiniTest.new_set({})

T["left integration"]["opening closes zen side buffer, closing reopens it"] = function()
	child.cmd("Fyler kind=split_left_most")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "fyler", buftype = "acwrite", width = 46, height = 50 },
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
end


T["left integration"]["opening a left integration preserves an existing top integration"] = function()
	child.cmd("Git")
	child.lua("vim.cmd('Fyler kind=split_left_most')")

	Helpers.expect.layout(child, {
		type = "col",
		children = {
			{ type = "leaf", filetype = "fugitive", buftype = "nowrite", width = 240, height = 25 },
			{
				type = "row",
				children = {
					{ type = "leaf", filetype = "fyler", buftype = "acwrite", width = 46, height = 24 },
					{ type = "leaf", filetype = "", buftype = "", width = 146, height = 24 },
					{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 24 },
				},
			},
		},
	})

	child.cmd("close")
	child.lua("vim.cmd('Fyler kind=split_left_most')")
	child.cmd("close")

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
end

T["left integration"]["opening an integration should close the existing integration on the same side"] = function()
	child.cmd("Fyler kind=split_left_most")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "fyler", buftype = "acwrite", width = 46, height = 50 },
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
end

T["left integration"]["opening a left integration preserves an existing bottom integration"] = function()
	child.cmd("Trouble diagnostics")
	child.cmd("Fyler kind=split_left_most")

	Helpers.expect.layout(child, {
		type = "col",
		children = {
			{
				type = "row",
				children = {
					{ type = "leaf", filetype = "fyler", buftype = "acwrite", width = 46, height = 39 },
					{ type = "leaf", filetype = "", buftype = "", width = 146, height = 39 },
					{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 39 },
				},
			},
			{ type = "leaf", filetype = "trouble", buftype = "nofile", width = 240, height = 10 },
		},
	})

	child.cmd("close")
	child.cmd("Fyler kind=split_left_most")
	child.cmd("close")

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
end

T["top integration"] = MiniTest.new_set({})

T["top integration"]["opening"] = function()
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
end

T["top integration"]["opening an integration should close the existing integration on the same side"] = function()
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
end

-- T["top integration"]["closing a stacked top split returns cursor to the integration below it"] = function ()
-- 	child.cmd("Git")
--
-- 	-- create a commit with cc
-- 	-- close the cc buffer
-- 	-- fugitive buffer should be focussed
-- end

T["bottom integration"] = MiniTest.new_set({})

T["bottom integration"]["opening"] = function()
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
end

T["bottom integration"]["opening an integration should close the existing integration on the same side"] = function()
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
end

T["combined"] = MiniTest.new_set({})

T["combined"]["opening a side integration preserves existing top and bottom integrations"] = function()
	child.cmd("Git")
	child.cmd("Trouble diagnostics")
	child.cmd("Fyler kind=split_left_most")

	Helpers.expect.layout(child, {
		type = "col",
		children = {
			{ type = "leaf", filetype = "fugitive", buftype = "nowrite", width = 240, height = 18 },
			{
				type = "row",
				children = {
					{ type = "leaf", filetype = "fyler", buftype = "acwrite", width = 46, height = 20 },
					{ type = "leaf", filetype = "", buftype = "", width = 146, height = 20 },
					{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 20 },
				},
			},
			{ type = "leaf", filetype = "trouble", buftype = "nofile", width = 240, height = 10 },
		},
	})

	child.cmd("close")
	child.cmd("Fyler kind=split_left_most")
	child.cmd("close")

	Helpers.expect.layout(child, {
		type = "col",
		children = {
			{ type = "leaf", filetype = "fugitive", buftype = "nowrite", width = 240, height = 18 },
			{
				type = "row",
				children = {
					{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 20 },
					{ type = "leaf", filetype = "", buftype = "", width = 146, height = 20 },
					{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 20 },
				},
			},
			{ type = "leaf", filetype = "trouble", buftype = "nofile", width = 240, height = 10 },
		},
	})
end

T["right integration"] = MiniTest.new_set({})

T["right integration"]["opening a right integration preserves an existing top integration"] = function()
	child.cmd("Git")
	child.cmd("Neotest summary open")

	Helpers.expect.layout(child, {
		type = "col",
		children = {
			{ type = "leaf", filetype = "fugitive", buftype = "nowrite", width = 240, height = 25 },
			{
				type = "row",
				children = {
					{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 24 },
					{ type = "leaf", filetype = "", buftype = "", width = 146, height = 24 },
					{ type = "leaf", filetype = "neotest-summary", buftype = "nofile", width = 46, height = 24 },
				},
			},
		},
	})

	child.cmd("Neotest summary close")
	child.cmd("Neotest summary open")
	child.cmd("Neotest summary close")

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
end

T["right integration"]["opening a right integration preserves an existing bottom integration"] = function()
	child.cmd("Trouble diagnostics")
	child.cmd("Neotest summary open")

	Helpers.expect.layout(child, {
		type = "col",
		children = {
			{
				type = "row",
				children = {
					{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 39 },
					{ type = "leaf", filetype = "", buftype = "", width = 146, height = 39 },
					{ type = "leaf", filetype = "neotest-summary", buftype = "nofile", width = 46, height = 39 },
				},
			},
			{ type = "leaf", filetype = "trouble", buftype = "nofile", width = 240, height = 10 },
		},
	})

	child.cmd("Neotest summary close")
	child.cmd("Neotest summary open")
	child.cmd("Neotest summary close")

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
end

T["right integration"]["opening closes zen side buffer, closing reopens it"] = function()
	child.cmd("Neotest summary open")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "neotest-summary", buftype = "nofile", width = 46, height = 50 },
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
end

T["right integration"]["opening an integration should close the existing integration on the same side"] = function()
	child.cmd("Neotest summary open")

	Helpers.expect.layout(child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 146, height = 50 },
			{ type = "leaf", filetype = "neotest-summary", buftype = "nofile", width = 46, height = 50 },
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
end

T["right integration"]["opening an integration with table filetype"] = function()
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
end

local min_width_child = MiniTest.new_child_neovim()

T["min_width"] = MiniTest.new_set({
	hooks = {
		pre_case = function()
			min_width_child.restart({ "-u", "tests/scripts/init_with_zen_min_width.lua" })
		end,
		post_once = min_width_child.stop,
	},
})

T["min_width"]["integration with a larger min_width should override the wildcard default"] = function()
	min_width_child.lua([[vim.o.splitright = true; require("CopilotChat").open()]])

	Helpers.expect.layout(min_width_child, {
		type = "row",
		children = {
			{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
			{ type = "leaf", filetype = "", buftype = "", width = 132, height = 50 },
			{ type = "leaf", filetype = "copilot-chat", buftype = "nofile", width = 60, height = 50 },
		},
	})
end

return T
