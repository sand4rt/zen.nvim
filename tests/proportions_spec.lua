local child = MiniTest.new_child_neovim()

before_each(function()
	child.restart({ "-u", "tests/scripts/init_with_zen.lua" })
end)

teardown(child.stop)

--- Runs each command and lets the layout settle after it.
local function run(...)
	for _, cmd in ipairs({ ... }) do
		child.cmd(cmd)
		child.type_keys("<Ignore>")
	end
end

local function keys(...)
	for _, key in ipairs({ ... }) do
		child.type_keys(key)
		child.type_keys("<Ignore>")
	end
end

--- The layout as `row[name:widthxheight, …]`, named by file or filetype.
local function layout()
	return child.lua_get([[(function()
		local function describe(node)
			if node[1] == "leaf" then
				local buf = vim.api.nvim_win_get_buf(node[2])
				local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
				if vim.bo[buf].buftype ~= "" or name == "" then
					name = vim.bo[buf].filetype
				end
				return ("%s:%dx%d"):format(name, vim.api.nvim_win_get_width(node[2]), vim.api.nvim_win_get_height(node[2]))
			end
			local children = {}
			for _, child in ipairs(node[2]) do
				table.insert(children, describe(child))
			end
			return node[1] .. "[" .. table.concat(children, ", ") .. "]"
		end
		return describe(vim.fn.winlayout())
	end)()]])
end

local function expect(expected)
	MiniTest.expect.equality(layout(), expected)
end

for _, equalalways in ipairs({ true, false }) do
	describe(equalalways and "equalalways" or "noequalalways", function()
		before_each(function()
			child.o.equalalways = equalalways
			child.lua([[vim.keymap.set("n", "<C-S-l>", "<C-w>L")]])
		end)

		it("a split moved next to fyler shares the main area evenly", function()
			run("edit a.lua", "split b.lua", "Fyler kind=split_left_most", "wincmd l", "wincmd j")
			expect("row[fyler_finder:46x50, col[b.lua:146x25, a.lua:146x24], zen-right:46x50]")

			keys("<C-S-l>")
			expect("row[fyler_finder:46x50, b.lua:96x50, a.lua:96x50]")

			keys("<C-S-l>")
			expect("row[fyler_finder:46x50, b.lua:96x50, a.lua:96x50]")

			keys("<C-w>K")
			expect("row[fyler_finder:46x50, col[a.lua:146x25, b.lua:146x24], zen-right:46x50]")
		end)

		it("swapped vsplits keep their widths", function()
			run("edit a.lua", "vsplit b.lua", "vertical resize 150", "Fyler kind=split_left_most", "wincmd l")
			expect("row[fyler_finder:46x50, b.lua:121x50, a.lua:71x50]")

			keys("<C-S-l>")
			expect("row[fyler_finder:46x50, a.lua:71x50, b.lua:121x50]")

			keys("<C-w>x")
			expect("row[fyler_finder:46x50, b.lua:121x50, a.lua:71x50]")
		end)

		it("side integrations keep the proportions of vsplits", function()
			run("edit a.lua", "vsplit b.lua", "vertical resize 150")
			expect("row[b.lua:150x50, a.lua:89x50]")

			for _ = 1, 2 do
				run("Neotest summary open")
				expect("row[b.lua:121x50, a.lua:71x50, neotest-summary:46x50]")
				run("Neotest summary close")
				expect("row[b.lua:150x50, a.lua:89x50]")

				run("Fyler kind=split_left_most")
				expect("row[fyler_finder:46x50, b.lua:121x50, a.lua:71x50]")
				run("close")
				expect("row[b.lua:150x50, a.lua:89x50]")
			end
		end)

		it("stacked integrations keep the proportions of splits", function()
			run("edit a.lua", "split b.lua", "resize 35")
			expect("row[zen-left:46x50, col[b.lua:146x35, a.lua:146x14], zen-right:46x50]")

			run("copen")
			expect("col[row[zen-left:46x39, col[b.lua:146x27, a.lua:146x11], zen-right:46x39], qf:240x10]")

			run("cclose")
			expect("row[zen-left:46x50, col[b.lua:146x35, a.lua:146x14], zen-right:46x50]")
		end)

		it("stacks keep their heights while main windows and sides come and go", function()
			run("edit a.lua", "Git", "copen", "wincmd t", "wincmd j")
			local stacks = "col[fugitive:240x25, row[zen-left:46x13, a.lua:146x13, zen-right:46x13], qf:240x10]"
			expect(stacks)

			run("split b.lua")
			expect("col[fugitive:240x25, row[zen-left:46x13, col[b.lua:146x6, a.lua:146x6], zen-right:46x13], qf:240x10]")

			run("close", "Fyler kind=split_left_most", "close")
			expect(stacks)

			run("wincmd t")
			child.lua("vim.v.errmsg = ''")
			keys("<C-w>J", "<C-w>K", "<C-w>L")
			expect(stacks)
			-- trouble reports E716 on its own
			local errmsg = child.lua_get("vim.v.errmsg")
			MiniTest.expect.equality(errmsg:find("zen") or errmsg:find("E36"), nil)
		end)

		it("dapui keeps the proportions of vsplits", function()
			run("edit a.lua", "vsplit b.lua")
			expect("row[b.lua:120x50, a.lua:119x50]")

			run("lua require('dapui').open()")
			MiniTest.expect.equality(
				layout():match("^row%[col%[row%[b.lua:%d+x%d+, a.lua:%d+x%d+%]"),
				"row[col[row[b.lua:96x39, a.lua:96x39]"
			)

			run("lua require('dapui').close()")
			expect("row[b.lua:120x50, a.lua:119x50]")
		end)

		describe("a band", function()
			before_each(function()
				child.lua([[
					require("zen").setup({
						top = { { filetype = { "top-a", "top-b" } } },
						bottom = {
							{ filetype = { "bottom-a", "bottom-b" }, replace = false },
							{ filetype = "bottom-c", replace = false },
						},
					})
					_G.open = function(filetype, cmd)
						vim.cmd(cmd or "botright 8split")
						local buf = vim.api.nvim_create_buf(false, true)
						vim.api.nvim_win_set_buf(0, buf)
						vim.bo[buf].filetype = filetype
					end
					_G.focus = function(filetype)
						for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
							if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == filetype then
								vim.api.nvim_set_current_win(win)
							end
						end
					end
				]])
				run("edit a.lua")
			end)

			local middle = "row[zen-left:46x41, a.lua:146x41, zen-right:46x41]"

			it("holds the windows of a filetype list side by side in list order", function()
				run("lua open('bottom-b')", "lua open('bottom-a', 'wincmd t | belowright split')")
				expect(("col[%s, row[bottom-a:120x8, bottom-b:119x8]]"):format(middle))

				run("lua open('top-b', 'topleft 6split')", "lua open('top-a', 'topleft 6split')")
				expect(
					"col[row[top-a:120x6, top-b:119x6], row[zen-left:46x34, a.lua:146x34, zen-right:46x34], "
						.. "row[bottom-a:120x8, bottom-b:119x8]]"
				)
			end)

			it("stacks the windows of a single filetype below it", function()
				run("lua open('bottom-a')", "lua open('bottom-b')", "lua open('bottom-c')", "lua open('bottom-c')")
				expect(("col[%s, row[bottom-a:120x2, bottom-b:119x2], bottom-c:240x2, bottom-c:240x2]"):format(middle))
			end)

			it("keeps its widths through moves and its height while windows come and go", function()
				run("lua open('bottom-a')", "lua open('bottom-b')", "lua focus('bottom-a')", "vertical resize 150")
				local resized = ("col[%s, row[bottom-a:150x8, bottom-b:89x8]]"):format(middle)
				expect(resized)

				keys("<C-w>x", "<C-w>K", "<C-w>L")
				expect(resized)
				MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "bottom-a")

				run("Fyler kind=split_left_most", "close")
				expect(resized)

				run("lua focus('bottom-b')", "close")
				expect(("col[%s, bottom-a:240x8]"):format(middle))

				run("lua open('bottom-b', 'wincmd t | belowright split')")
				expect(("col[%s, row[bottom-a:120x8, bottom-b:119x8]]"):format(middle))
			end)
		end)
	end)
end

it("a mapped move from an integration is undone", function()
	child.lua([[vim.keymap.set("n", "<C-S-l>", "<C-w>L")]])
	run("edit a.lua", "split b.lua", "copen")
	local before = layout()

	keys("<C-S-l>")
	expect(before)
	MiniTest.expect.equality(child.lua_get("vim.bo.filetype"), "qf")
end)
