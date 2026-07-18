--- @alias Filetype string|string[]

--- @class Integration
--- @field filetype Filetype
--- @field min_width? number
--- @field replace? boolean

--- @class Config
--- @field main? { width: number | fun(): number; }
--- @field top? Integration[]
--- @field right? Integration[]
--- @field bottom? Integration[]
--- @field left? Integration[]

--- @class ConfigOptions
--- @field main { width: number | fun(): number; }
--- @field top Integration[]
--- @field right Integration[]
--- @field bottom Integration[]
--- @field left Integration[]

local default_width = 148
--- @type ConfigOptions
local opts = {
	main = { width = default_width },
	top = {},
	right = { { filetype = "*", min_width = 46 } },
	bottom = {},
	left = { { filetype = "*", min_width = 46 } },
}
local state = {
	[vim.api.nvim_get_current_tabpage()] = { left = nil, right = nil },
}

local function get_main_width()
	local width = opts.main and opts.main.width
	if type(width) == "function" then
		width = width()
	end
	if type(width) ~= "number" then
		return default_width
	end
	return width
end

local function create_window(position)
	if position == "left" then
		vim.cmd("topleft vnew")
	elseif position == "right" then
		vim.cmd("botright vnew")
	end

	local win_id = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_width(win_id, math.floor((vim.o.columns - get_main_width()) / 2))
	vim.api.nvim_set_option_value("winfixwidth", true, { scope = "local", win = win_id })
	vim.api.nvim_set_option_value("winfixbuf", true, { scope = "local", win = win_id })
	vim.api.nvim_set_option_value("cursorline", false, { scope = "local", win = win_id })
	vim.api.nvim_set_option_value("number", false, { scope = "local", win = win_id })
	vim.api.nvim_set_option_value("relativenumber", false, { scope = "local", win = win_id })

	local buf_id = vim.api.nvim_get_current_buf()
	vim.api.nvim_set_option_value("filetype", "zen-" .. position, { buf = buf_id })
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf_id })
	vim.api.nvim_set_option_value("buflisted", false, { buf = buf_id })

	return vim.api.nvim_get_current_win()
end

---@param target string
---@param filetype Filetype
---@return boolean
local function is_filetype(target, filetype)
	if type(filetype) == "string" then
		return filetype ~= "*" and filetype == target
	elseif type(filetype) == "table" then
		return vim.tbl_contains(filetype, target)
	end
	return false
end

---@param position "top" | "right" | "bottom" | "left"
---@param filetype string
---@return number
local function get_min_width(position, filetype)
	local wildcard_width = 0
	for _, integration in ipairs(opts[position]) do
		if type(integration) == "table" then
			if integration.min_width and integration.filetype ~= "*" and is_filetype(filetype, integration.filetype) then
				return integration.min_width
			end
			local mw = integration.min_width
			if integration.filetype == "*" and mw then
				wildcard_width = mw
			end
		end
	end
	return wildcard_width
end

---@return number
local function get_side_buffer(position)
	local current_tabpage = vim.api.nvim_get_current_tabpage()
	if state[current_tabpage] and state[current_tabpage][position] then
		return state[current_tabpage][position]
	end
	return -1
end

local function close_side_buffer(position)
	local window = get_side_buffer(position)
	if window and vim.api.nvim_win_is_valid(window) then
		local buffer = vim.api.nvim_win_get_buf(window)
		vim.api.nvim_win_close(window, true)

		if vim.api.nvim_buf_is_valid(buffer) then
			vim.api.nvim_buf_delete(buffer, { force = true })
		end
	end
end

---@param filetypes string[]
---@return boolean
local function filetypes_visible(filetypes)
	for _, win_id in ipairs(vim.api.nvim_list_wins()) do
		local buf_id = vim.api.nvim_win_get_buf(win_id)
		if vim.api.nvim_buf_is_valid(buf_id) and vim.api.nvim_buf_is_loaded(buf_id) then
			if vim.tbl_contains(filetypes, vim.api.nvim_get_option_value("filetype", { buf = buf_id })) then
				return true
			end
		end
	end
	return false
end

---@param filetypes string[]
---@param type_to_remove string
local function remove_file_type(filetypes, type_to_remove)
	for i, filetype in ipairs(filetypes) do
		if filetype == type_to_remove then
			table.remove(filetypes, i)
			break
		end
	end
end

---@param buf number
---@return boolean
local function is_buff_integration(buf)
	local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
	if filetype == "zen-left" or filetype == "zen-right" then
		return true
	end
	for _, position in ipairs({ "left", "right", "top", "bottom" }) do
		for _, integration in ipairs(opts[position] or {}) do
			---@diagnostic disable-next-line: undefined-field
			if type(integration) == "table" and is_filetype(filetype, integration.filetype) then
				return true
			end
		end
	end
	return false
end

---@return table
local function get_editable_files()
	local editable_files = {}
	local windows = vim.api.nvim_list_wins()
	for _, win in ipairs(windows) do
		local buf = vim.api.nvim_win_get_buf(win)
		if not is_buff_integration(buf) then -- is an actual file
			editable_files[buf] = buf
		end
	end
	return editable_files
end

---@param win_id number
---@return boolean
local function is_popup_window(win_id)
	return vim.api.nvim_win_get_config(win_id).relative ~= ""
end

---@return table
local function get_vsplits()
	local vsplits = {}
	local windows = vim.api.nvim_list_wins()
	for _, win in ipairs(windows) do
		local buf = vim.api.nvim_win_get_buf(win)
		local total_width = vim.o.columns
		local window_width = vim.api.nvim_win_get_width(win)
		local is_popup = is_popup_window(win)
		local is_integration = is_buff_integration(buf)
		if not is_popup and not is_integration and window_width < total_width then
			vsplits[win] = buf
		end
	end
	return vsplits
end

---@param position "top" | "right" | "bottom" | "left"
---@return boolean
local function is_integration_open(position)
	for _, integration in pairs(opts[position]) do
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if
				type(integration) == "table"
				and vim.api.nvim_buf_is_loaded(buf)
				and is_filetype(vim.api.nvim_get_option_value("filetype", { buf = buf }), integration.filetype)
			then
				return true
			end
		end
	end
	return false
end

---@param filetype string|string[]
local function get_window_by_filetype(filetype)
	for _, win_id in ipairs(vim.api.nvim_list_wins()) do
		local buf_id = vim.api.nvim_win_get_buf(win_id)
		local buf_filetype = vim.api.nvim_get_option_value("filetype", { buf = buf_id })
		if is_filetype(buf_filetype, filetype) then
			return win_id
		end
	end
	return nil
end

---@param position "top" | "bottom"
---@return number[]
local function get_ordered_stack_windows(position)
	local windows = {}
	for _, integration in ipairs(opts[position]) do
		if type(integration) == "table" and integration.filetype ~= "*" then
			local win = get_window_by_filetype(integration.filetype)
			if win then
				table.insert(windows, win)
			end
		end
	end
	return windows
end

--- Stacks the open `top`/`bottom` integration windows on top of each other,
--- full width, in the order they appear in the config: for `top`, the first
--- configured integration ends up closest to the very top edge of the screen
--- and the last one closest to the main area; for `bottom` it is the mirror
--- (first closest to the main area, last closest to the very bottom edge).
---@param position "top" | "bottom"
local function reposition_stack(position)
	local windows = get_ordered_stack_windows(position)
	if #windows == 0 then
		return
	end

	-- already full width and in the desired relative order (top-to-bottom):
	-- nothing to do, since re-splitting would needlessly renegotiate heights
	local in_order = true
	for _, win in ipairs(windows) do
		if vim.api.nvim_win_get_width(win) ~= vim.o.columns then
			in_order = false
			break
		end
	end
	if in_order then
		for i = 2, #windows do
			if vim.api.nvim_win_get_position(windows[i])[1] < vim.api.nvim_win_get_position(windows[i - 1])[1] then
				in_order = false
				break
			end
		end
	end
	if in_order then
		return
	end

	-- splitting a window relative to another renegotiates both windows'
	-- heights, so snapshot and restore them once the whole stack is in order
	local heights = {}
	for _, win in ipairs(windows) do
		heights[win] = vim.api.nvim_win_get_height(win)
	end

	pcall(function()
		if position == "top" then
			vim.api.nvim_win_set_config(windows[1], { split = "above", win = -1 })
			for i = 2, #windows do
				vim.api.nvim_win_set_config(windows[i], { split = "below", win = windows[i - 1] })
			end
		else
			vim.api.nvim_win_set_config(windows[#windows], { split = "below", win = -1 })
			for i = #windows - 1, 1, -1 do
				vim.api.nvim_win_set_config(windows[i], { split = "above", win = windows[i + 1] })
			end
		end

		for _, win in ipairs(windows) do
			vim.api.nvim_win_set_height(win, heights[win])
			vim.api.nvim_win_set_width(win, vim.o.columns)
		end
	end)
end

---@param position "top" | "bottom"
---@return number height, number count combined height and number of open stack windows
local function stack_metrics(position)
	local windows = get_ordered_stack_windows(position)
	local height = 0
	for _, win in ipairs(windows) do
		height = height + vim.api.nvim_win_get_height(win)
	end
	return height, #windows
end

--- Closing a stacked `top`/`bottom` window frees its content plus its one
--- statusline row, but Neovim may hand that freed row to the main area instead
--- of the surviving stack window. Given the stack's height/count from before
--- the close, grow the survivor closest to the main area back to the height the
--- stack should now have (its old height plus the closed window's freed row).
---@param position "top" | "bottom"
---@param before_height number stack height captured before the close
---@param before_count number stack window count captured before the close
local function reclaim_stack_height(position, before_height, before_count)
	local windows = get_ordered_stack_windows(position)
	-- nothing to do if this stack didn't lose a window, or lost them all
	if #windows == 0 or #windows >= before_count then
		return
	end

	local height = stack_metrics(position)
	local deficit = before_height + 1 - height
	if deficit <= 0 then
		return
	end

	local boundary = position == "top" and windows[#windows] or windows[1]
	vim.api.nvim_win_set_height(boundary, vim.api.nvim_win_get_height(boundary) + deficit)
end

local function resize_side_buffers()
	local new_width = math.floor((vim.o.columns - get_main_width()) / 2)
	local left = vim.api.nvim_win_is_valid(get_side_buffer("left"))
	if left then
		vim.api.nvim_win_set_width(get_side_buffer("left"), new_width)
	end
	local right = vim.api.nvim_win_is_valid(get_side_buffer("right"))
	if right then
		vim.api.nvim_win_set_width(get_side_buffer("right"), new_width)
	end
end

---@param filetype string|string[]
local function close(filetype)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if is_filetype(vim.bo[buf].filetype, filetype) then
			vim.api.nvim_win_close(win, false)
		end
	end
end

---@param options? Config
local function setup(options)
	-- Default splitting will cause your main splits to jump when opening an integration.
	-- To prevent this, set `splitkeep` to either `screen` or `topline`.
	vim.opt.splitkeep = "screen"

	---@type ConfigOptions
	opts = vim.tbl_extend("force", opts, options or {})

	vim.api.nvim_create_autocmd("CursorMoved", {
		-- TODO: use pattern for better perf
		callback = function(args)
			if vim.o.columns <= get_main_width() then
				return
			end
			if is_buff_integration(args.buf) then
				local buf_info = vim.fn.getbufinfo(args.buf)

				local filetype = vim.api.nvim_get_option_value("filetype", { buf = args.buf })
				for _, position in ipairs({ "right", "left" }) do
					for _, integration in pairs(opts[position]) do
						---@diagnostic disable-next-line: undefined-field
						if type(integration) == "table" and is_filetype(filetype, integration.filetype) then
							local new_width = math.max(get_min_width(position, filetype), math.floor((vim.o.columns - get_main_width()) / 2))
							vim.api.nvim_win_set_width(buf_info[1].windows[1], new_width)
							return
						end
					end
				end
			end
		end,
		desc = "HACK: adjust the integration when opening",
	})

	vim.api.nvim_create_autocmd({ "VimEnter", "TabNew" }, {
		callback = function()
			-- disable when window is too small
			if vim.o.columns <= get_main_width() then
				return
			end

			if vim.tbl_count(get_vsplits()) >= 2 then
				return
			end

			state[vim.api.nvim_get_current_tabpage()] = {
				left = create_window("left"),
				right = create_window("right"),
			}
			vim.cmd("wincmd h")
		end,
		desc = "Restore the last buffer when opening Neovim",
	})

	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function()
			if vim.bo.filetype == "zen-left" then
				vim.cmd("wincmd l")
			end
			if vim.bo.filetype == "zen-right" then
				vim.cmd("wincmd h")
			end
		end,
		desc = "Prevent the cursor from moving to the side buffers.",
	})

	vim.api.nvim_create_autocmd("QuitPre", {
		callback = function(args)
			if is_popup_window(vim.api.nvim_get_current_win()) then
				return
			end
			if is_buff_integration(args.buf) then
				return
			end

			local editable_count = 0
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				if not is_popup_window(win) then
					local buf = vim.api.nvim_win_get_buf(win)
					if not is_buff_integration(buf) then
						editable_count = editable_count + 1
					end
				end
			end
			if editable_count ~= 1 then
				return
			end

			close_side_buffer("left")
			close_side_buffer("right")

			for _, position in ipairs({ "top", "right", "bottom", "left" }) do
				for _, integration in pairs(opts[position]) do
					if type(integration) == "table" then
						close(integration.filetype)
					end
				end
			end
		end,
		desc = "Close left and right buffers on quit",
	})

	vim.api.nvim_create_autocmd("VimResized", {
		callback = function()
			if vim.tbl_count(get_editable_files()) ~= 1 then
				return
			end

			-- close when window is too small
			if vim.o.columns <= get_main_width() then
				close_side_buffer("left")
				close_side_buffer("right")
				return
			end

			-- enable when side buffers is big enough
			local left = vim.api.nvim_win_is_valid(get_side_buffer("left"))
			if not left and not is_integration_open("left") then
				state[vim.api.nvim_get_current_tabpage()].left = create_window("left")
				vim.cmd("wincmd l")
			end

			local right = vim.api.nvim_win_is_valid(get_side_buffer("right"))
			if not right and not is_integration_open("right") then
				state[vim.api.nvim_get_current_tabpage()].right = create_window("right")
				vim.cmd("wincmd h")
			end
			resize_side_buffers()
		end,
		desc = "Resizes side windows after terminal has been resized, closes them if not enough space left.",
	})

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = "*",
		callback = function(args)
			-- do not recreate when window is too small
			if vim.o.columns <= get_main_width() then
				return
			end
			local win_id = tonumber(args.match)
			if win_id == nil then
				return
			end

			if is_popup_window(win_id) then
				return
			end

			-- `WinClosed` fires just before the window is removed, so the stacks
			-- still have their pre-close heights here. Capture them and reclaim
			-- any slack from `WinResized`, which fires once the close has settled.
			local top_height, top_count = stack_metrics("top")
			local bottom_height, bottom_count = stack_metrics("bottom")
			vim.api.nvim_create_autocmd("WinResized", {
				once = true,
				callback = function()
					reclaim_stack_height("top", top_height, top_count)
					reclaim_stack_height("bottom", bottom_height, bottom_count)
				end,
			})

			local buf_id = vim.fn.winbufnr(win_id)
			local file_type = vim.api.nvim_get_option_value("filetype", { buf = buf_id })
			local buf_type = vim.api.nvim_get_option_value("buftype", { buf = buf_id })
			-- do not recreate when multiple vsplits are active
			local count = vim.tbl_count(get_vsplits())
			if buf_type == "" then
				count = count - 1
			end
			if count >= 2 then
				return
			end

			local left_file_types = { "fugitiveblame", "fyler_finder", "undotree", "dbui", "zen-left" }
			remove_file_type(left_file_types, file_type)
			if not filetypes_visible(left_file_types) then
				state[vim.api.nvim_get_current_tabpage()].left = create_window("left")
				vim.cmd("wincmd l")
			end

			local right_file_types = { "dapui_scopes", "neotest-summary", "zen-right" }
			remove_file_type(right_file_types, file_type)
			if not filetypes_visible(right_file_types) then
				state[vim.api.nvim_get_current_tabpage()].right = create_window("right")
				vim.cmd("wincmd h")
			end

			reposition_stack("top")
			reposition_stack("bottom")
			resize_side_buffers()
		end,
		desc = "Recreate the side buffers if they are closed.",
	})

	vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
		pattern = "*",
		callback = function(args)
			if is_popup_window(vim.api.nvim_get_current_win()) then
				return
			end
			local filetype = vim.bo[args.buf].filetype
			local is_integration = is_buff_integration(args.buf)
			if args.event == "BufWinEnter" then
				if filetype ~= "" and not is_integration and vim.tbl_count(get_vsplits()) >= 2 then
					close_side_buffer("left")
					close_side_buffer("right")
					return
				end
			end

			if not is_integration then
				return
			end

			---@type ("top"|"right"|"bottom"|"left")[]
			local positions = { "top", "right", "bottom", "left" }
			for _, position in ipairs(positions) do
				for _, integration in pairs(opts[position]) do
					if type(integration) == "table" and is_filetype(filetype, integration.filetype) then
						close_side_buffer(position)
						if integration.replace ~= false then
							for _, position_inner in ipairs(positions) do
								for _, integration_inner in pairs(opts[position_inner]) do
									if
										position_inner == position
										and type(integration_inner) == "table"
										and integration_inner.replace ~= false
										and not is_filetype(filetype, integration_inner.filetype)
									then
										close(integration_inner.filetype)
									end
								end
							end
						end

						if position == "left" or position == "right" then
							local min_width = get_min_width(position, filetype)
							if min_width > 0 then
								local win = vim.fn.bufwinid(args.buf)
								if win ~= -1 then
									local current_width = vim.api.nvim_win_get_width(win)
									if current_width < min_width then
										vim.api.nvim_win_set_width(win, min_width)
									end
								end
							end
						end
					end
				end
			end

			reposition_stack("top")
			reposition_stack("bottom")
			resize_side_buffers()
		end,
		desc = "Close side buffer plugins if another plugin is already occupying that side.",
	})
end

return { setup = setup }
