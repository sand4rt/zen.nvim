local T = MiniTest.new_set()

T["setup() works without errors"] = function()
	require("zen").setup({})
	MiniTest.expect.equality(vim.o.splitkeep, "screen")
end

return T
