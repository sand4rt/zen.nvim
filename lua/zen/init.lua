--- @type {
---     width: number;
---     min_integration_width: number;
---     integrations: {
---         position: "top" | "left" | "right" | "bottom";
---         filetype: string | string[];
---     }[];
--- }
local opts = {}
local state = {
	[vim.api.nvim_get_current_tabpage()] = { left = nil, right = nil },
}

local function create_window(position)
	if position == "left" then
		vim.cmd("topleft vnew")
	elseif position == "right" then
		vim.cmd("botright vnew")
	end

	local win_id = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_width(win_id, math.floor((vim.o.columns - opts.width) / 2))
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
---@param filetype string|string[]
---@return boolean
local function is_filetype(target, filetype)
	if type(filetype) == "string" then
		return filetype == target
	elseif type(filetype) == "table" then
		return vim.tbl_contains(filetype, target)
	end
	return false
end

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

local function remove_file_type(file_types, type_to_remove)
	for i, file_type in ipairs(file_types) do
		if file_type == type_to_remove then
			table.remove(file_types, i)
			break
		end
	end
end

local function is_buff_integration(buf)
	local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
	if filetype == "zen-left" or filetype == "zen-right" then
		return true
	end
	for _, integration in pairs(opts.integrations) do
		if is_filetype(filetype, integration.filetype) then
			return true
		end
	end
	return false
end

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

local function is_popup_window(win_id)
	return vim.api.nvim_win_get_config(win_id).relative ~= ""
end

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

local function is_hsplit(buf)
	local win_id = vim.fn.bufwinid(buf)
	local width = vim.api.nvim_win_get_width(win_id)
	local height = vim.api.nvim_win_get_height(win_id)
	return width > height
end

local function is_integration_open(position)
	for _, integration in pairs(opts.integrations) do
		if integration.position == position then
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if
					vim.api.nvim_buf_is_loaded(buf)
					and is_filetype(vim.api.nvim_get_option_value("filetype", { buf = buf }), integration.filetype)
				then
					return true
				end
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

local function adjust_top_bottom_window_hack(target_window, position)
	if target_window then
		vim.api.nvim_win_call(target_window, function()
			vim.cmd("wincmd " .. position)
		end)
	end
end

local function resize_side_buffers()
	local new_width = math.floor((vim.o.columns - opts.width) / 2)
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

local function setup(options)
	-- Default splitting will cause your main splits to jump when opening an edgebar.
	-- To prevent this, set `splitkeep` to either `screen` or `topline`.
	vim.opt.splitkeep = "screen"

	opts = vim.tbl_extend("force", opts, options or {})

	vim.api.nvim_create_autocmd("CursorMoved", {
		-- TODO: use pattern for better perf
		callback = function(args)
			if is_buff_integration(args.buf) then
				local buf_info = vim.fn.getbufinfo(args.buf)
				local new_width = math.max(opts.min_integration_width, math.floor((vim.o.columns - opts.width) / 2))
				vim.api.nvim_win_set_width(buf_info[1].windows[1], new_width)
			end
		end,
		desc = "HACK: adjust the integration with when opening",
	})

	vim.api.nvim_create_autocmd({ "VimEnter", "TabNew" }, {
		callback = function()
			-- disable when window is too small
			if vim.o.columns <= opts.width then
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
			if vim.tbl_count(get_editable_files()) == 1 and not is_buff_integration(args.buf) then
				close_side_buffer("left")
				close_side_buffer("right")
				for _, integration in pairs(opts.integrations) do
					close(integration.filetype)
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
			if vim.o.columns <= opts.width then
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
			if vim.o.columns <= opts.width then
				return
			end
			local win_id = tonumber(args.match)
			if win_id == nil then
				return
			end

			if is_popup_window(win_id) then
				return
			end

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

			local left_file_types = { "fugitiveblame", "fyler", "undotree", "dbui", "zen-left" }
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

			for _, integration in pairs(opts.integrations) do
				local target_window = get_window_by_filetype(integration.filetype)
				if integration.position == "top" then
					adjust_top_bottom_window_hack(target_window, "K")
				end
				if integration.position == "bottom" then
					adjust_top_bottom_window_hack(target_window, "J")
				end
			end
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

			for _, integration in pairs(opts.integrations) do
				if is_filetype(filetype, integration.filetype) then
					close_side_buffer(integration.position)
					for _, integrate in pairs(opts.integrations) do
						if
							integrate.position == integration.position and not is_filetype(filetype, integrate.filetype)
						then
							close(integrate.filetype)
						end
					end
				end

				local target_window = get_window_by_filetype(integration.filetype)
				if integration.position == "top" and not is_hsplit(args.buf) then
					adjust_top_bottom_window_hack(target_window, "K")
				end
				if integration.position == "bottom" and not is_hsplit(args.buf) then
					adjust_top_bottom_window_hack(target_window, "J")
				end
			end
			resize_side_buffers()
		end,
		desc = "Close side buffer plugins if another plugin is already occupying that side.",
	})
end

return { setup = setup }
