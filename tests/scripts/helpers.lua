local Helpers = {}

Helpers.expect = vim.deepcopy(MiniTest.expect)

local function error_message(str, pattern)
	return string.format("Pattern: %s\nObserved string: %s", vim.inspect(pattern), str)
end

Helpers.expect.layout = MiniTest.new_expectation("window layout matches", function(child, expected)
	local layout = child.lua_func(function()
		local function enrich(node)
			if node[1] == "leaf" then
				local win = node[2]
				local buf = vim.api.nvim_win_get_buf(win)
				return {
					type = "leaf",
					filetype = vim.bo[buf].filetype,
					buftype = vim.bo[buf].buftype,
					width = vim.api.nvim_win_get_width(win),
					height = vim.api.nvim_win_get_height(win),
				}
			end
			local result = {}
			for i, n in ipairs(node[2]) do
				result[i] = enrich(n)
			end
			return { type = node[1], children = result }
		end
		return enrich(vim.fn.winlayout())
	end)
	return Helpers.expect.equality(layout, expected)
end, error_message)

return Helpers
