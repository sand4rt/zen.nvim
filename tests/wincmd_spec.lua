local Helpers = dofile("tests/scripts/helpers.lua")
local child = MiniTest.new_child_neovim()

before_each(function()
	child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
end)

teardown(child.stop)

describe("single window", function()
	for _, direction in ipairs({ "H", "L" }) do
		it("wincmd " .. direction .. " keeps the layout", function()
			child.cmd("edit test.lua")
			child.cmd("wincmd " .. direction)

			Helpers.expect.layout(child, {
				type = "row",
				children = {
					{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
					{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 50 },
					{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
				},
			})
		end)
	end
end)

for _, integration in ipairs({
	{
		position = "bottom",
		open = "copen",
		to_main = "wincmd k",
		main_height = 39,
		leaf = { type = "leaf", filetype = "qf", buftype = "quickfix", width = 240, height = 10 },
	},
	{
		position = "top",
		open = "Man ls",
		to_main = "wincmd j",
		main_height = 24,
		leaf = { type = "leaf", filetype = "man", buftype = "nofile", width = 240, height = 25 },
	},
}) do
	describe(integration.position .. " integration", function()
		for _, focus in ipairs({ "main", "integration" }) do
			for _, direction in ipairs({ "H", "J", "K", "L" }) do
				it("wincmd " .. direction .. " on the " .. focus .. " window keeps the layout", function()
					child.cmd("edit test.lua")
					child.cmd(integration.open)
					if focus == "main" then
						child.cmd(integration.to_main)
					end
					child.cmd("wincmd " .. direction)

					local row = {
						type = "row",
						children = {
							{
								type = "leaf",
								filetype = "zen-left",
								buftype = "nofile",
								width = 46,
								height = integration.main_height,
							},
							{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = integration.main_height },
							{
								type = "leaf",
								filetype = "zen-right",
								buftype = "nofile",
								width = 46,
								height = integration.main_height,
							},
						},
					}
					Helpers.expect.layout(child, {
						type = "col",
						children = integration.position == "top" and { integration.leaf, row } or { row, integration.leaf },
					})
				end)
			end
		end
	end)
end

describe("side integration", function()
	for _, moves in ipairs({
		{ "wincmd l" },
		{ "wincmd H" },
		{ "wincmd J" },
		{ "wincmd K" },
		{ "wincmd L" },
		{ "wincmd l", "wincmd H" },
		{ "wincmd l", "wincmd J" },
		{ "wincmd l", "wincmd K" },
		{ "wincmd l", "wincmd L" },
	}) do
		it("Fyler then " .. table.concat(moves, ", ") .. " keeps the layout", function()
			child.cmd("edit test.lua")
			child.cmd("Fyler kind=split_left_most")
			for _, move in ipairs(moves) do
				child.cmd(move)
			end

			Helpers.expect.layout(child, {
				type = "row",
				children = {
					{ type = "leaf", filetype = "fyler_finder", buftype = "acwrite", width = 46, height = 50 },
					{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 50 },
					{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
				},
			})
		end)
	end
end)

describe("command-line window", function()
	it("opening keeps the layout", function()
		child.cmd("edit test.lua")
		child.type_keys("q:")

		Helpers.expect.layout(child, {
			type = "col",
			children = {
				{
					type = "row",
					children = {
						{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 42 },
						{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 42 },
						{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 42 },
					},
				},
				{ type = "leaf", filetype = "vim", buftype = "nofile", width = 240, height = 7 },
			},
		})
	end)

	it("closing restores the layout", function()
		child.cmd("edit test.lua")
		child.type_keys("q:")
		child.type_keys("<C-c><C-c>")

		Helpers.expect.layout(child, {
			type = "row",
			children = {
				{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
				{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = 50 },
				{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
			},
		})
	end)
end)

describe("side by side", function()
	for _, case in ipairs({
		{ split = "split", moves = { "wincmd H" }, widths = { 120, 119 } },
		{ split = "split", moves = { "wincmd L" }, widths = { 120, 119 } },
		{ split = "vsplit", moves = { "wincmd l", "wincmd H" }, widths = { 119, 120 } },
		{ split = "vsplit", moves = { "wincmd L" }, widths = { 119, 120 } },
		{ split = "vsplit", moves = { "wincmd x" }, widths = { 119, 120 } },
	}) do
		it(case.split .. " then " .. table.concat(case.moves, ", ") .. " closes the side buffers", function()
			child.cmd("edit test.lua")
			child.cmd(case.split .. " test2.lua")
			for _, move in ipairs(case.moves) do
				child.cmd(move)
			end

			Helpers.expect.layout(child, {
				type = "row",
				children = {
					{ type = "leaf", filetype = "lua", buftype = "", width = case.widths[1], height = 50 },
					{ type = "leaf", filetype = "lua", buftype = "", width = case.widths[2], height = 50 },
				},
			})
		end)
	end
end)

describe("stacked", function()
	for _, case in ipairs({
		{ split = "split", moves = { "wincmd J" }, heights = { 24, 25 } },
		{ split = "split", moves = { "wincmd K" }, heights = { 25, 24 } },
		{ split = "split", moves = { "wincmd j", "wincmd K" }, heights = { 24, 25 } },
		{ split = "split", moves = { "wincmd x" }, heights = { 24, 25 } },
		{ split = "split", moves = { "wincmd H", "wincmd K" }, heights = { 25, 24 } },
		{ split = "split", moves = { "wincmd L", "wincmd J" }, heights = { 25, 24 } },
		{ split = "vsplit", moves = { "wincmd K" }, heights = { 25, 24 } },
		{ split = "vsplit", moves = { "wincmd J" }, heights = { 25, 24 } },
	}) do
		it(case.split .. " then " .. table.concat(case.moves, ", ") .. " shows the side buffers", function()
			child.cmd("edit test.lua")
			child.cmd(case.split .. " test2.lua")
			for _, move in ipairs(case.moves) do
				child.cmd(move)
			end

			Helpers.expect.layout(child, {
				type = "row",
				children = {
					{ type = "leaf", filetype = "zen-left", buftype = "nofile", width = 46, height = 50 },
					{
						type = "col",
						children = {
							{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = case.heights[1] },
							{ type = "leaf", filetype = "lua", buftype = "", width = 146, height = case.heights[2] },
						},
					},
					{ type = "leaf", filetype = "zen-right", buftype = "nofile", width = 46, height = 50 },
				},
			})
		end)
	end
end)

for _, split in ipairs({ "split", "vsplit" }) do
	for _, integration in ipairs({
		{ position = "top", open = "Git", filetype = "fugitive", to_main = "wincmd j" },
		{ position = "bottom", open = "copen", filetype = "qf", to_main = "wincmd k" },
	}) do
		describe(split .. " with a " .. integration.position .. " integration", function()
			for _, focus in ipairs({ "main", "integration" }) do
				for _, direction in ipairs({ "H", "J", "K", "L", "h", "j", "k", "l" }) do
					it("wincmd " .. direction .. " on the " .. focus .. " window keeps the integration in place", function()
						child.cmd("edit test.lua")
						child.cmd(split .. " test2.lua")
						child.cmd(integration.open)
						if focus == "main" then
							child.cmd(integration.to_main)
						end
						local height_before = child.lua_get(
							[[(function(filetype)
								for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
									if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == filetype then
										return vim.api.nvim_win_get_height(win)
									end
								end
							end)(...)]],
							{ integration.filetype }
						)
						child.cmd("wincmd " .. direction)

						local state = child.lua_get(
							[[(function(filetype)
								local result = { sides = {}, main = {} }
								for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
									local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
									local pos = vim.api.nvim_win_get_position(win)
									local info = {
										row = pos[1],
										col = pos[2],
										width = vim.api.nvim_win_get_width(win),
										height = vim.api.nvim_win_get_height(win),
									}
									if ft == filetype then
										result.integration = info
									elseif ft == "zen-left" or ft == "zen-right" then
										result.sides[ft] = info
									else
										table.insert(result.main, info)
									end
								end
								return result
							end)(...)]],
							{ integration.filetype }
						)

						local stack = state.integration
						MiniTest.expect.equality(stack.width, 240)
						MiniTest.expect.equality(stack.height, height_before)
						if integration.position == "top" then
							MiniTest.expect.equality(stack.row, 0)
						else
							MiniTest.expect.equality(stack.row + stack.height, 50)
						end

						local side_by_side = state.main[1].col ~= state.main[2].col
						if side_by_side then
							MiniTest.expect.equality(vim.tbl_count(state.sides), 0)
						else
							MiniTest.expect.equality(state.sides["zen-left"].col, 0)
							MiniTest.expect.equality(state.sides["zen-right"].col + state.sides["zen-right"].width, 240)
						end
					end)
				end
			end
		end)
	end
end

local function layout_with_names()
	return child.lua_func(function()
		local function describe_node(node)
			if node[1] == "leaf" then
				local win = node[2]
				local buf = vim.api.nvim_win_get_buf(win)
				local filetype = vim.bo[buf].filetype
				return {
					name = filetype == "lua" and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t") or filetype,
					width = vim.api.nvim_win_get_width(win),
					height = vim.api.nvim_win_get_height(win),
				}
			end
			local children = {}
			for i, child_node in ipairs(node[2]) do
				children[i] = describe_node(child_node)
			end
			return { type = node[1], children = children }
		end
		return describe_node(vim.fn.winlayout())
	end)
end

local function focus_filetype(filetype)
	child.lua(
		[[local filetype = ...
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == filetype then
				vim.api.nvim_set_current_win(win)
				return
			end
		end
		error("no window with filetype " .. filetype)]],
		{ filetype }
	)
end

-- `wincmd r`/`R` refuse to rotate a window whose siblings are split (E443)
local function move(keys)
	pcall(child.type_keys, keys)
	child.type_keys("<Ignore>")
end

local pinned = {
	{ name = "quickfix", filetype = "qf", setup = { "edit test.lua", "copen" } },
	{ name = "man page", filetype = "man", setup = { "edit test.lua", "Man ls" } },
	{ name = "trouble", filetype = "trouble", setup = { "edit test.lua", "Trouble diagnostics" } },
	{ name = "fyler", filetype = "fyler_finder", setup = { "edit test.lua", "Fyler kind=split_left_most" } },
	{ name = "fugitive with splits", filetype = "fugitive", setup = { "edit test.lua", "split test2.lua", "Git" } },
	{ name = "quickfix with splits", filetype = "qf", setup = { "edit test.lua", "split test2.lua", "copen" } },
	{ name = "quickfix with vsplits", filetype = "qf", setup = { "edit test.lua", "vsplit test2.lua", "copen" } },
	{
		name = "fyler with vsplits",
		filetype = "fyler_finder",
		setup = { "edit test.lua", "vsplit test2.lua", "Fyler kind=split_left_most" },
	},
	{ name = "man page above quickfix", filetype = "man", setup = { "edit test.lua", "copen", "Man ls" } },
	{ name = "quickfix below man page", filetype = "qf", setup = { "edit test.lua", "copen", "Man ls" } },
	{
		name = "quickfix next to fyler",
		filetype = "qf",
		setup = { "edit test.lua", "Fyler kind=split_left_most", "copen" },
	},
	{
		name = "fyler above quickfix",
		filetype = "fyler_finder",
		setup = { "edit test.lua", "Fyler kind=split_left_most", "copen" },
	},
}

for _, case in ipairs(pinned) do
	describe("pinned " .. case.name, function()
		for _, keys in ipairs({ "<C-w>H", "<C-w>J", "<C-w>K", "<C-w>L", "<C-w>x", "2<C-w>x", "<C-w>r", "<C-w>R" }) do
			it(keys .. " leaves the layout untouched", function()
				for _, cmd in ipairs(case.setup) do
					child.cmd(cmd)
				end
				focus_filetype(case.filetype)
				child.type_keys("<Ignore>")
				local before = layout_with_names()

				move(keys)

				MiniTest.expect.equality(layout_with_names(), before)
				MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), case.filetype)
			end)
		end

		for _, direction in ipairs({ "H", "J", "K", "L" }) do
			it(":wincmd " .. direction .. " leaves the layout untouched", function()
				for _, cmd in ipairs(case.setup) do
					child.cmd(cmd)
				end
				focus_filetype(case.filetype)
				child.type_keys("<Ignore>")
				local before = layout_with_names()

				move(":wincmd " .. direction .. "<CR>")

				MiniTest.expect.equality(layout_with_names(), before)
			end)
		end
	end)
end

describe("main window next to an integration", function()
	for _, case in ipairs({
		{ name = "quickfix", setup = { "edit test.lua", "copen" } },
		{ name = "man page", setup = { "edit test.lua", "Man ls" } },
		{ name = "fyler", setup = { "edit test.lua", "Fyler kind=split_left_most" } },
		{ name = "fyler and quickfix", setup = { "edit test.lua", "Fyler kind=split_left_most", "copen" } },
		{ name = "man page and quickfix", setup = { "edit test.lua", "copen", "Man ls" } },
	}) do
		for _, keys in ipairs({ "<C-w>H", "<C-w>J", "<C-w>K", "<C-w>L", "<C-w>x", "2<C-w>x", "<C-w>r", "<C-w>R" }) do
			it(keys .. " with " .. case.name .. " does not swap them", function()
				for _, cmd in ipairs(case.setup) do
					child.cmd(cmd)
				end
				focus_filetype("lua")
				child.type_keys("<Ignore>")
				local before = layout_with_names()

				move(keys)

				MiniTest.expect.equality(layout_with_names(), before)
				MiniTest.expect.equality(child.lua_get("vim.fn.expand('%:t')"), "test.lua")
			end)
		end
	end

	for _, keys in ipairs({ "<C-w>x", "<C-w>r", "<C-w>R" }) do
		it(keys .. " swaps vsplits but keeps fyler at the left edge", function()
			child.cmd("edit test.lua")
			child.cmd("vsplit test2.lua")
			child.cmd("Fyler kind=split_left_most")
			focus_filetype("lua")
			child.type_keys("<Ignore>")

			move(keys)

			local layout = layout_with_names()
			MiniTest.expect.equality(layout.type, "row")
			MiniTest.expect.equality(layout.children[1], { name = "fyler_finder", width = 46, height = 50 })
			local names = { layout.children[2].name, layout.children[3].name }
			table.sort(names)
			MiniTest.expect.equality(names, { "test.lua", "test2.lua" })
		end)
	end
end)

describe("resized integration", function()
	for _, keys in ipairs({ "<C-w>H", "<C-w>J", "<C-w>K", "<C-w>L", "<C-w>x" }) do
		it("keeps its new height after " .. keys, function()
			child.cmd("edit test.lua")
			child.cmd("copen")
			child.cmd("resize 15")
			child.type_keys("<Ignore>")
			local before = layout_with_names()

			move(keys)

			MiniTest.expect.equality(layout_with_names(), before)
			MiniTest.expect.equality(child.lua_get("vim.api.nvim_win_get_height(0)"), 15)
		end)
	end
end)

describe("tabs", function()
	it("moves in one tab leave the other tab untouched", function()
		child.cmd("edit test.lua")
		child.cmd("copen")
		child.cmd("tabnew test2.lua")
		child.cmd("Man ls")
		-- the tabline takes a row once there are two tabs
		child.cmd("tabprevious")
		child.type_keys("<Ignore>")
		local first = layout_with_names()

		child.cmd("tabnext")
		child.type_keys("<Ignore>")
		local second = layout_with_names()
		move("<C-w>H")
		MiniTest.expect.equality(layout_with_names(), second)

		child.cmd("tabprevious")
		child.type_keys("<Ignore>")
		MiniTest.expect.equality(layout_with_names(), first)
		focus_filetype("qf")
		move("<C-w>K")
		MiniTest.expect.equality(layout_with_names(), first)
	end)
end)

describe("failed restore", function()
	it("does not disable later restores", function()
		child.cmd("edit test.lua")
		child.cmd("copen")
		child.type_keys("<Ignore>")
		local before = layout_with_names()

		-- make the next restore throw once
		child.lua([[
			local set_config = vim.api.nvim_win_set_config
			vim.api.nvim_win_set_config = function()
				vim.api.nvim_win_set_config = set_config
				error("boom")
			end
		]])
		move("<C-w>K")
		child.cmd("messages clear")

		move("<C-w>K")
		MiniTest.expect.equality(layout_with_names(), before)
	end)
end)
