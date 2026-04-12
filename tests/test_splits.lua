local T = MiniTest.new_set()

T["close side buffers when a vertical split is opened"] = function()
	require("zen").setup({ main = { with = 100 } })
	MiniTest.expect.equality(vim.o.splitkeep, "screen")
end

return T
