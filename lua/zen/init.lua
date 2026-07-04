--- @alias Filetype string|string[]
--- @class Integration
--- @field filetype Filetype
--- @field min_width? number
--- @class Config
--- @field main? { width: number | fun(): number; }
--- @field top? Integration[]
--- @field right? Integration[]
--- @field bottom? Integration[]
--- @field left? Integration[]

local options = {
	main = { width = 148 },
	top = {},
	right = { { filetype = "*", min_width = 46 } },
	bottom = {},
	left = { { filetype = "*", min_width = 46 } },
}
local state = { [vim.api.nvim_get_current_tabpage()] = { left = -1, right = -1 } }
local filetype_positions = {}
local min_widths = {}
local wildcard_min_widths = {}
local sibling_filetypes = {}
local in_handler = false

local function get_main_width()
	local width = options.main and options.main.width
	if type(width) == "function" then width = width() end
	return type(width) == "number" and width or options.main.width
end

local function get_padding_width()
	return math.floor((vim.o.columns - get_main_width()) / 2)
end

local function create_side_window(position)
	vim.cmd(position == "left" and "topleft vnew" or "botright vnew")
	local window = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_width(window, get_padding_width())
	vim.wo[window].winfixwidth = true
	vim.wo[window].winfixbuf = true
	vim.wo[window].cursorline = false
	vim.wo[window].number = false
	vim.wo[window].relativenumber = false
	local buffer = vim.api.nvim_get_current_buf()
	vim.bo[buffer].filetype = "zen-" .. position
	vim.bo[buffer].buftype = "nofile"
	vim.bo[buffer].buflisted = false
	return window
end

local function scan_windows()
	local filetype_windows = {}
	local editable_cols = {}
	local editable_count = 0
	for _, window in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_config(window).relative ~= "" then
			goto continue
		end
		local filetype = vim.bo[vim.api.nvim_win_get_buf(window)].filetype
		filetype_windows[filetype] = window
		if not filetype_positions[filetype] then
			editable_count = editable_count + 1
			if vim.api.nvim_win_get_width(window) < vim.o.columns then
				editable_cols[vim.api.nvim_win_get_position(window)[2]] = true
			end
		end
		::continue::
	end
	return filetype_windows, vim.tbl_count(editable_cols), editable_count
end

local function close_side_window(position)
	local tab = state[vim.api.nvim_get_current_tabpage()]
	local window = tab and tab[position]
	if not window or not vim.api.nvim_win_is_valid(window) then
		return
	end
	local buffer = vim.api.nvim_win_get_buf(window)
	vim.api.nvim_win_close(window, true)
	if vim.api.nvim_buf_is_valid(buffer) then
		vim.api.nvim_buf_delete(buffer, { force = true })
	end
end

local function resize_side_windows()
	local width = get_padding_width()
	local tab = state[vim.api.nvim_get_current_tabpage()]
	if not tab then
		return
	end
	for _, position in ipairs({ "left", "right" }) do
		if vim.api.nvim_win_is_valid(tab[position] or -1) then vim.api.nvim_win_set_width(tab[position], width) end
	end
end

-- Critical: set_config and set_height must be in separate passes;
-- interleaving them causes Neovim to redistribute heights between calls.
local function reposition_top_bottom(filetype_windows)
	local heights, configs = {}, {}
	for filetype, window in pairs(filetype_windows) do
		local position = filetype_positions[filetype]
		if (position == "top" or position == "bottom") and vim.api.nvim_win_is_valid(window) then
			heights[window] = vim.api.nvim_win_get_height(window)
			if vim.api.nvim_win_get_width(window) ~= vim.o.columns then
				configs[window] = position
			end
		end
	end
	for window, position in pairs(configs) do
		vim.api.nvim_win_set_config(window, { split = position == "top" and "above" or "below", win = -1 })
	end
	for window, height in pairs(heights) do
		if vim.api.nvim_win_is_valid(window) then vim.api.nvim_win_set_height(window, height) end
	end
end

local function protect_top_bottom(filetype_windows)
	local protected = {}
	for filetype, window in pairs(filetype_windows) do
		local position = filetype_positions[filetype]
		if (position == "top" or position == "bottom") and vim.api.nvim_win_is_valid(window) then
			vim.wo[window].winfixheight = true
			table.insert(protected, window)
		end
	end
	if #protected == 0 then return end
	vim.api.nvim_create_autocmd("WinResized", {
		once = true,
		callback = function()
			for _, window in ipairs(protected) do
				if vim.api.nvim_win_is_valid(window) then
					vim.wo[window].winfixheight = false
				end
			end
		end,
	})
end

local function has_side_window(filetype_windows, position, exclude)
	for filetype in pairs(filetype_windows) do
		if filetype ~= exclude and filetype_positions[filetype] == position then
			return true
		end
	end
	return false
end

local function ensure_padding(filetype_windows, exclude)
	local tabpage = vim.api.nvim_get_current_tabpage()
	state[tabpage] = state[tabpage] or { left = -1, right = -1 }
	for _, position in ipairs({ "left", "right" }) do
		if not has_side_window(filetype_windows, position, exclude) then
			state[tabpage][position] = create_side_window(position)
			vim.cmd(position == "left" and "wincmd l" or "wincmd h")
		end
	end
end

--- @param config? Config
local function setup(config)
	vim.opt.splitkeep = "screen"
	options = vim.tbl_extend("force", options, config or {})
	filetype_positions = { ["zen-left"] = "left", ["zen-right"] = "right" }
	min_widths, wildcard_min_widths, sibling_filetypes = {}, {}, {}
	for _, position in ipairs({ "top", "right", "bottom", "left" }) do
		for _, integration in ipairs(options[position]) do
			if type(integration) ~= "table" then
				goto continue
			end
			if integration.filetype == "*" then
				if (integration.min_width or 0) > 0 then
					wildcard_min_widths[position] = integration.min_width
				end
				goto continue
			end
			local filetypes = type(integration.filetype) == "table" and integration.filetype or { integration.filetype }
			for _, ft in ipairs(filetypes) do
				filetype_positions[ft] = position
				sibling_filetypes[ft] = filetypes
				if (integration.min_width or 0) > 0 then
					min_widths[position] = min_widths[position] or {}
					min_widths[position][ft] = integration.min_width
				end
			end
			::continue::
		end
	end

	vim.api.nvim_create_autocmd({ "VimEnter", "TabNew" }, {
		callback = function()
			local _, vsplit_count = scan_windows()
			if vim.o.columns <= get_main_width() or vsplit_count >= 2 then
				return
			end
			state[vim.api.nvim_get_current_tabpage()] = {
				left = create_side_window("left"),
				right = create_side_window("right"),
			}
			vim.cmd("wincmd h")
		end,
	})

	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function()
			if vim.bo.filetype == "zen-left" then
				vim.cmd("wincmd l")
			elseif vim.bo.filetype == "zen-right" then
				vim.cmd("wincmd h")
			end
		end,
	})

	vim.api.nvim_create_autocmd("QuitPre", {
		callback = function(args)
			if vim.api.nvim_win_get_config(vim.api.nvim_get_current_win()).relative ~= "" then
				return
			end
			if filetype_positions[vim.bo[args.buf].filetype] then
				return
			end
			local editable = 0
			for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				if vim.api.nvim_win_get_config(window).relative == "" and not filetype_positions[vim.bo[vim.api.nvim_win_get_buf(window)].filetype] then
					editable = editable + 1
				end
			end
			if editable ~= 1 then return end
			close_side_window("left")
			close_side_window("right")
			for _, window in ipairs(vim.api.nvim_list_wins()) do
				if filetype_positions[vim.bo[vim.api.nvim_win_get_buf(window)].filetype] then
					vim.api.nvim_win_close(window, false)
				end
			end
		end,
	})

	vim.api.nvim_create_autocmd("WinResized", {
		callback = function()
			if in_handler then
				return
			end
			local filetype_windows, vsplit_count = scan_windows()
			if vsplit_count >= 2 then
				close_side_window("left")
				close_side_window("right")
				return
			end
			in_handler = true
			-- Re-contain any window that escaped the zen area via wincmd J/K
			for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				if vim.api.nvim_win_get_config(window).relative ~= "" then
					goto continue
				end
				local ft = vim.bo[vim.api.nvim_win_get_buf(window)].filetype
				if filetype_positions[ft] then
					goto continue
				end
				if vim.api.nvim_win_get_width(window) < vim.o.columns then
					goto continue
				end
				local height = vim.api.nvim_win_get_height(window)
				for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
					if w == window then
						goto skip
					end
					if vim.api.nvim_win_get_config(w).relative ~= "" then
						goto skip
					end
					local wft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
					if filetype_positions[wft] then
						goto skip
					end
					if vim.api.nvim_win_get_width(w) < vim.o.columns then
						vim.api.nvim_win_set_config(window, { split = "below", win = w })
						if vim.api.nvim_win_is_valid(window) then
							vim.api.nvim_win_set_height(window, height)
						end
						break
					end
					::skip::
				end
				::continue::
			end
			-- Re-enforce widths for left/right integration windows after wincmd H/L
			for ft, window in pairs(filetype_windows) do
				local position = filetype_positions[ft]
				if (position == "left" or position == "right") and ft ~= "zen-left" and ft ~= "zen-right" then
					if vim.api.nvim_win_is_valid(window) then
						local min_width = (min_widths[position] and min_widths[position][ft])
							or wildcard_min_widths[position]
							or 0
						vim.api.nvim_win_set_width(window, math.max(min_width, get_padding_width()))
					end
				end
			end
			resize_side_windows()
			in_handler = false
		end,
	})

	vim.api.nvim_create_autocmd("VimResized", {
		callback = function()
			local filetype_windows, vsplit_count = scan_windows()
			if vim.o.columns <= get_main_width() then
				close_side_window("left")
				close_side_window("right")
				return
			end
			if vsplit_count > 1 then
				return
			end
			ensure_padding(filetype_windows, nil)
			reposition_top_bottom(scan_windows())
			resize_side_windows()
		end,
	})

	vim.api.nvim_create_autocmd("WinClosed", {
		callback = function(args)
			if vim.o.columns <= get_main_width() then
				return
			end
			local window_id = tonumber(args.match)
			if not window_id or not vim.api.nvim_win_is_valid(window_id) then
				return
			end
			if vim.api.nvim_win_get_config(window_id).relative ~= "" then
				return
			end
			local closing_buffer = vim.fn.winbufnr(window_id)
			local closing_filetype = closing_buffer ~= -1 and vim.bo[closing_buffer].filetype or ""
			local closing_position = filetype_positions[closing_filetype]
			if closing_position == "top" or closing_position == "bottom" then
				protect_top_bottom(scan_windows())
				return
			end
			local filetype_windows, vsplit_count = scan_windows()
			if closing_buffer ~= -1 and vim.bo[closing_buffer].buftype == "" then
				vsplit_count = vsplit_count - 1
			end
			if vsplit_count >= 2 then
				return
			end
			ensure_padding(filetype_windows, closing_filetype)
			if not in_handler then
				reposition_top_bottom(scan_windows())
			end
			resize_side_windows()
		end,
	})

	vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
		callback = function(args)
			if vim.api.nvim_win_get_config(vim.api.nvim_get_current_win()).relative ~= "" then
				return
			end
			local filetype = vim.bo[args.buf].filetype
			local filetype_windows = scan_windows()
			if not filetype_positions[filetype] then
				return
			end
			local position = filetype_positions[filetype]
			if filetype == "zen-left" or filetype == "zen-right" then
				reposition_top_bottom(filetype_windows)
				resize_side_windows()
				return
			end
			in_handler = true
			close_side_window(position)
			local siblings = sibling_filetypes[filetype] or { filetype }
			for _, window in ipairs(vim.api.nvim_list_wins()) do
				local ft = vim.bo[vim.api.nvim_win_get_buf(window)].filetype
				if filetype_positions[ft] == position and not vim.tbl_contains(siblings, ft) then
					vim.api.nvim_win_close(window, false)
				end
			end
			if position == "left" or position == "right" then
				local min_width = (min_widths[position] and min_widths[position][filetype]) or wildcard_min_widths[position] or 0
				local window = vim.fn.bufwinid(args.buf)
				if window ~= -1 then
					vim.api.nvim_win_set_width(window, math.max(min_width, get_padding_width()))
				end
			end
			reposition_top_bottom(scan_windows())
			resize_side_windows()
			in_handler = false
		end,
	})
end

return { setup = setup }
