--- @alias Filetype string|string[]
--- @alias Position "top" | "right" | "bottom" | "left"

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
local main_width = default_width
---@type Position[]
local positions = { "top", "right", "bottom", "left" }

local function refresh_main_width()
	local width = opts.main and opts.main.width
	if type(width) == "function" then
		width = width()
	end
	main_width = type(width) == "number" and width or default_width
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

---@param position Position
---@param filetype string
---@return Integration?
local function find_integration(position, filetype)
	for _, integration in ipairs(opts[position] or {}) do
		if type(integration) == "table" and is_filetype(filetype, integration.filetype) then
			return integration
		end
	end
end

---@param position Position
---@param filetype string
---@return number
local function get_min_width(position, filetype)
	--- @type number
	local wildcard_width = 0
	for _, integration in ipairs(opts[position]) do
		if type(integration) == "table" and integration.min_width then
			if integration.filetype == "*" then
				wildcard_width = integration.min_width
			elseif is_filetype(filetype, integration.filetype) then
				return integration.min_width
			end
		end
	end
	return wildcard_width or 0
end

--- A window is either a zen padding window, a configured integration, or main.
---@param filetype string
---@return "pad" | "integration" | "main", Position?
local function classify_filetype(filetype)
	if filetype == "zen-left" then
		return "pad", "left"
	elseif filetype == "zen-right" then
		return "pad", "right"
	end
	for _, position in ipairs(positions) do
		if find_integration(position, filetype) then
			return "integration", position
		end
	end
	return "main"
end

---@param win number
local function classify(win)
	return classify_filetype(vim.bo[vim.api.nvim_win_get_buf(win)].filetype)
end

---@param buf number
---@return boolean
local function is_buff_integration(buf)
	return classify_filetype(vim.bo[buf].filetype) ~= "main"
end

---@param win number
---@return boolean
local function is_popup_window(win)
	return vim.api.nvim_win_get_config(win).relative ~= ""
end

---@param node table `winlayout()` node
---@param acc? number[]
---@return number[]
local function leaves(node, acc)
	acc = acc or {}
	if node[1] == "leaf" then
		table.insert(acc, node[2])
	else
		for _, child in ipairs(node[2]) do
			leaves(child, acc)
		end
	end
	return acc
end

---@param node table `winlayout()` node
---@return string
local function layout_key(node)
	return vim.inspect(node, { newline = "", indent = "" })
end

--- Builds a frame, merging same-type children and collapsing single-child
--- frames, the way Neovim does.
---@param kind "row" | "col"
---@param children table[]
---@return table
local function frame(kind, children)
	local flat = {}
	for _, child in ipairs(children) do
		if child[1] == kind then
			vim.list_extend(flat, child[2])
		else
			table.insert(flat, child)
		end
	end
	return #flat == 1 and flat[1] or { kind, flat }
end

--- Drops the leaves `keep` rejects from a `winlayout()` node.
---@param node table
---@param keep fun(win: number): boolean
---@return table?
local function prune_layout(node, keep)
	if node[1] == "leaf" then
		return keep(node[2]) and node or nil
	end
	local children = {}
	for _, child in ipairs(node[2]) do
		local kept = prune_layout(child, keep)
		if kept then
			table.insert(children, kept)
		end
	end
	if #children == 0 then
		return nil
	end
	return frame(node[1], children)
end

---@param node table `winlayout()` node
---@return number
local function first_leaf(node)
	while node[1] ~= "leaf" do
		node = node[2][1]
	end
	return node[2]
end

--- Moves the windows into the shape of `tree`. Siblings are lined up next to
--- the first window of their predecessor before descending, so each split
--- either adds a sibling or opens a new frame exactly where the tree has one.
--- The sizes this leaves behind are arbitrary, the size plan sets them after.
---@param tree table `winlayout()` node
local function apply_layout(tree)
	if tree[1] == "leaf" then
		return
	end
	local function place(node)
		if node[1] == "leaf" then
			return
		end
		local previous = first_leaf(node[2][1])
		for i = 2, #node[2] do
			local leaf = first_leaf(node[2][i])
			vim.api.nvim_win_set_config(leaf, { split = node[1] == "row" and "right" or "below", win = previous })
			previous = leaf
		end
		for _, child in ipairs(node[2]) do
			place(child)
		end
	end
	-- without 'equalalways' a split only takes room from the window it splits,
	-- which fails (E36) as soon as that one is small
	local equalalways = vim.o.equalalways
	vim.o.equalalways = true
	local ok, err = pcall(function()
		vim.api.nvim_win_set_config(first_leaf(tree), { split = tree[1] == "row" and "left" or "above", win = -1 })
		place(tree)
	end)
	vim.o.equalalways = equalalways
	if not ok then
		error(err, 0)
	end
end

---@alias Axis "width" | "height"
---@alias Sizes table<number, { width: number, height: number }>

---@param wins number[]
---@return Sizes
local function sizes_of(wins)
	local sizes = {}
	for _, win in ipairs(wins) do
		sizes[win] = { width = vim.api.nvim_win_get_width(win), height = vim.api.nvim_win_get_height(win) }
	end
	return sizes
end

---@param node table `winlayout()` node
---@param axis Axis
---@return boolean
local function along(node, axis)
	return (node[1] == "row") == (axis == "width")
end

--- The size of a node along `axis` in window cells, counting one cell per
--- separator. `nil` when `sizes` misses one of its windows.
---@param node table `winlayout()` node
---@param axis Axis
---@param sizes Sizes
---@return number?
local function measure(node, axis, sizes)
	if node[1] == "leaf" then
		return sizes[node[2]] and sizes[node[2]][axis]
	end
	if not along(node, axis) then
		return measure(node[2][1], axis, sizes)
	end
	local total = #node[2] - 1
	for _, child in ipairs(node[2]) do
		local size = measure(child, axis, sizes)
		if not size then
			return nil
		end
		total = total + size
	end
	return total
end

---@param node table `winlayout()` node
---@param axis Axis
---@return number
local function minimum(node, axis)
	if node[1] == "leaf" then
		return 1
	end
	local total = 0
	for _, child in ipairs(node[2]) do
		local size = minimum(child, axis)
		total = along(node, axis) and total + size or math.max(total, size)
	end
	return along(node, axis) and total + #node[2] - 1 or total
end

--- The screen cells every node of the layout covers, separators and status
--- lines included, keyed by node.
---@param tree table `winlayout()` node
---@return table<table, { width: number, height: number }>
local function geometry(tree)
	local tabline = (vim.o.showtabline == 2 or vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1) and 1 or 0
	local extents = {}
	local function walk(node, start, extent)
		extents[node] = extent
		if node[1] == "leaf" then
			return
		end
		local axis = node[1] == "row" and "width" or "height"
		local index = axis == "width" and 2 or 1
		local starts = {}
		for i, child in ipairs(node[2]) do
			starts[i] = vim.api.nvim_win_get_position(first_leaf(child))[index]
		end
		for i, child in ipairs(node[2]) do
			local child_extent = { width = extent.width, height = extent.height }
			child_extent[axis] = (starts[i + 1] or start[index] + extent[axis]) - starts[i]
			local child_start = { start[1], start[2] }
			child_start[index] = starts[i]
			walk(child, child_start, child_extent)
		end
	end
	walk(tree, vim.api.nvim_win_get_position(first_leaf(tree)), {
		width = vim.o.columns,
		height = vim.o.lines - vim.o.cmdheight - tabline - (vim.o.laststatus == 3 and 1 or 0),
	})
	return extents
end

--- Splits `total` cells by `weights`, rounding so the parts add up exactly,
--- and keeps every part at its minimum.
---@param total number
---@param weights number[]
---@param mins number[]
---@return number[]
local function distribute(total, weights, mins)
	local sum = 0
	for _, weight in ipairs(weights) do
		sum = sum + math.max(weight, 0)
	end
	local parts, fractions, rest = {}, {}, total
	for i, weight in ipairs(weights) do
		local exact = sum > 0 and total * math.max(weight, 0) / sum or total / #weights
		parts[i] = math.floor(exact)
		fractions[i] = exact - parts[i]
		rest = rest - parts[i]
	end
	local order = vim.fn.range(1, #weights)
	table.sort(order, function(a, b)
		if fractions[a] ~= fractions[b] then
			return fractions[a] > fractions[b]
		end
		return a < b
	end)
	for k = 1, rest do
		local i = order[(k - 1) % #order + 1]
		parts[i] = parts[i] + 1
	end
	for i = 1, #parts do
		while parts[i] < mins[i] do
			local donor
			for j = 1, #parts do
				if parts[j] > mins[j] and (not donor or parts[j] - mins[j] > parts[donor] - mins[donor]) then
					donor = j
				end
			end
			if not donor then
				break
			end
			parts[donor] = parts[donor] - 1
			parts[i] = parts[i] + 1
		end
	end
	return parts
end

---@class SizeOp
---@field win number
---@field axis Axis
---@field size number
---@field leaf boolean the window is the child being sized, not a frame around it

--- Sets the window sizes of a plan. Every frame was planned to add up, and a
--- resize pushes on the siblings after a window first, then the ones before.
--- So the children of a frame are set in order, each landing exactly, and a
--- window set is fixed for the rest of the pass, so that resizing the last
--- child pushes on a frame that has no window to size it by instead.
--- 'winfixwidth'/'winfixheight' are zen's to use meanwhile.
---@param ops SizeOp[]
local function apply_sizes(ops)
	local fixed = {}
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_get_config(win).relative == "" then
			fixed[win] = { vim.wo[win][0].winfixwidth, vim.wo[win][0].winfixheight }
		end
	end
	local ok, err = pcall(function()
		-- a frame sized through its siblings may still be off, a second pass
		-- settles it
		for _ = 1, 2 do
			for win in pairs(fixed) do
				vim.wo[win][0].winfixwidth = false
				vim.wo[win][0].winfixheight = false
			end
			for _, op in ipairs(ops) do
				if vim.api.nvim_win_is_valid(op.win) then
					vim.api.nvim_win_set_config(op.win, { [op.axis] = op.size })
					if op.leaf then
						vim.wo[op.win][0][op.axis == "width" and "winfixwidth" or "winfixheight"] = true
					end
				end
			end
		end
	end)
	for win, flags in pairs(fixed) do
		if vim.api.nvim_win_is_valid(win) then
			vim.wo[win][0].winfixwidth = flags[1]
			vim.wo[win][0].winfixheight = flags[2]
		end
	end
	if not ok then
		error(err, 0)
	end
end

---@param filetype Filetype
local function close(filetype)
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if is_filetype(vim.bo[vim.api.nvim_win_get_buf(win)].filetype, filetype) then
			pcall(vim.api.nvim_win_close, win, false)
		end
	end
end

---@param side "left" | "right"
local function create_pad(side)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "zen-" .. side
	local win = vim.api.nvim_open_win(buf, false, {
		split = side,
		win = -1,
		width = math.floor((vim.o.columns - main_width) / 2),
		style = "minimal",
		noautocmd = true,
	})
	vim.wo[win].winfixwidth = true
	vim.wo[win].winfixbuf = true
	-- other plugins have no business in here, only the cursor bounce below
	vim.wo[win].eventignorewin = "all,-BufEnter"
	vim.api.nvim_create_autocmd("BufEnter", {
		buffer = buf,
		callback = function()
			vim.cmd(side == "left" and "wincmd l" or "wincmd h")
		end,
		desc = "Prevent the cursor from moving to the side buffers.",
	})
end

---@param tab number
---@param closing_win? number window about to close, left out of the count
---@return number
local function count_main_windows(tab, closing_win)
	local count = 0
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		if win ~= closing_win and not is_popup_window(win) and not is_buff_integration(vim.api.nvim_win_get_buf(win)) then
			count = count + 1
		end
	end
	return count
end

--- Deleting the main buffer while another window has focus (e.g. a file
--- explorer deleting the open file) closes the main window outright, leaving
--- only side windows. Put an empty main window back between them.
---@param tab number
---@param closing_win number window about to close, ignored as main and anchor
local function restore_main_window(tab, closing_win)
	if vim.v.exiting ~= vim.NIL or not vim.api.nvim_tabpage_is_valid(tab) or count_main_windows(tab, closing_win) > 0 then
		return
	end

	local anchor, split
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		if win ~= closing_win and not is_popup_window(win) then
			local col = vim.api.nvim_win_get_position(win)[2]
			if col == 0 and vim.api.nvim_win_get_width(win) < vim.o.columns then
				anchor, split = win, "right"
				break
			elseif not anchor then
				anchor, split = win, "left"
			end
		end
	end
	if not anchor then
		return
	end

	local buf = vim.api.nvim_create_buf(true, false)
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_open_win(buf, false, { split = split, win = anchor })
end

---@class TabState last intact layout of a tab
---@field sizes Sizes
---@field basis Sizes sizes the main and side windows share out room by
---@field windows table<number, true> every window but the pads
---@field key string `layout_key()` of the whole layout
---@field frames table<string, true> keys of the frames the main windows, each side's windows and the bands form
---@field main_tree table `winlayout()` of the main windows only
---@field current number window that had focus
---@field stacks table<"top" | "bottom", Band[]> bands of the stacks

---@type table<number, TabState>
local last = {}
local updating = false
-- set when a window opened or closed, which a layout looking the same may hide,
-- or on `VimResized`: the sizes Neovim spread over the new screen are replaced
local relayout = false
---@type number? tab whose last main window is being quit
local quitting_tab = nil
---@type number? window that was current when a `wincmd` move (`HJKLxrR`) was typed or entered as a command
local moved_from = nil
local wincmd_pending = false
local wincmd_command = vim.regex([=[\v^[: ]*\d*\s*winc%[md]\s+\d*[HJKLxrR]]=])
---@type table<number, "winfixwidth" | "winfixheight"> integration windows zen fixed the size of
local fixed_by_zen = {}

---@param win number
---@return boolean
local function is_main(win)
	return classify(win) == "main"
end

--- Whether the windows, pads aside, are the ones of the last intact layout.
---@param wins number[]
---@param prev TabState?
---@return boolean
local function same_windows(wins, prev)
	if not prev then
		return false
	end
	local count = 0
	for _, win in ipairs(wins) do
		if classify(win) ~= "pad" then
			count = count + 1
			if not prev.windows[win] then
				return false
			end
		end
	end
	return count == vim.tbl_count(prev.windows)
end

---@class Band a row of the `top`/`bottom` stack
---@field key string `entry<i>` for the windows of an entry with a filetype list, `win<id>` for any other window
---@field wins number[] from left to right
---@field height? number

--- The windows of the `top`/`bottom` integrations in bands, in config order,
--- which is also their order from the top of the screen to the bottom. The
--- windows of an entry whose `filetype` is a list share a band side by side,
--- in the order of that list. Any other window gets a band of its own. Windows
--- that tie keep the order of the last pass, then the one on screen.
---@param wins number[]
---@param position "top" | "bottom"
---@param before? Band[] bands of the last pass
---@return Band[]
local function stack_bands(wins, position, before)
	local order, count = {}, 0
	for _, band in ipairs(before or {}) do
		for _, win in ipairs(band.wins) do
			count = count + 1
			order[win] = count
		end
	end
	local screen = {}
	for i, win in ipairs(wins) do
		screen[win] = i
	end
	local bands, seen = {}, {}
	for index, integration in ipairs(opts[position]) do
		if type(integration) == "table" then
			local list = type(integration.filetype) == "table" and integration.filetype or nil
			local matched, rank = {}, {}
			for _, win in ipairs(wins) do
				local role, side = classify(win)
				local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
				if
					not seen[win]
					and role == "integration"
					and side == position
					and is_filetype(filetype, integration.filetype)
				then
					seen[win] = true
					table.insert(matched, win)
					rank[win] = list and vim.fn.index(list, filetype) or 0
				end
			end
			table.sort(matched, function(a, b)
				if rank[a] ~= rank[b] then
					return rank[a] < rank[b]
				end
				local before_a, before_b = order[a] or math.huge, order[b] or math.huge
				if before_a ~= before_b then
					return before_a < before_b
				end
				return screen[a] < screen[b]
			end)
			if list and #matched > 0 then
				table.insert(bands, { key = "entry" .. index, wins = matched })
			elseif not list then
				for _, win in ipairs(matched) do
					table.insert(bands, { key = "win" .. win, wins = { win } })
				end
			end
		end
	end
	return bands
end

---@param band Band
---@return table `winlayout()` node
local function band_node(band)
	return frame(
		"row",
		vim.tbl_map(function(win)
			return { "leaf", win }
		end, band.wins)
	)
end

--- The side a node sits on when it holds nothing but that side's windows.
---@param node table `winlayout()` node
---@return ("left" | "right")?
local function side_of(node)
	---@type ("left" | "right")?
	local side
	for _, win in ipairs(leaves(node)) do
		local role, position = classify(win)
		if (position ~= "left" and position ~= "right") or role == "main" or (side and side ~= position) then
			return nil
		end
		side = position --[[@as "left" | "right"]]
	end
	return side
end

--- The pad width, or more when an integration on the side asks for it.
---@param node table `winlayout()` node
---@param pad_width number
---@return number
local function side_width(node, pad_width)
	local width = pad_width
	for _, win in ipairs(leaves(node)) do
		local role, side = classify(win)
		if role == "integration" and side then
			width = math.max(width, get_min_width(side, vim.bo[vim.api.nvim_win_get_buf(win)].filetype))
		end
	end
	return width
end

--- Keys of the frames formed by the main windows, by each side's windows and
--- by the bands of the stacks.
---@param tree table `winlayout()` node
---@param bands Band[]
---@return table<string, true>
local function frame_keys(tree, bands)
	local keys = {}
	local function collect(node)
		if node and node[1] ~= "leaf" then
			keys[layout_key(node)] = true
			for _, child in ipairs(node[2]) do
				collect(child)
			end
		end
	end
	collect(prune_layout(tree, is_main))
	for _, side in ipairs({ "left", "right" }) do
		collect(prune_layout(tree, function(win)
			return side_of({ "leaf", win }) == side
		end))
	end
	for _, band in ipairs(bands) do
		collect(band_node(band))
	end
	return keys
end

--- Integrations keep their size while Neovim shares out room among the other
--- windows ('equalalways', `CTRL-W =`).
---@param wins number[]
---@param prev TabState?
local function fix_integration_sizes(wins, prev)
	for win in pairs(fixed_by_zen) do
		if not vim.api.nvim_win_is_valid(win) then
			fixed_by_zen[win] = nil
		end
	end
	local zen_fixes = {}
	for _, option in pairs(fixed_by_zen) do
		zen_fixes[option] = true
	end
	for _, win in ipairs(wins) do
		local role, position = classify(win)
		local option = role == "integration"
				and ((position == "top" or position == "bottom") and "winfixheight" or "winfixwidth")
			or nil
		local previous = fixed_by_zen[win]
		if previous and previous ~= option then
			vim.wo[win][0][previous] = false
			fixed_by_zen[win] = nil
		end
		if option and not vim.wo[win][0][option] then
			vim.wo[win][0][option] = true
			fixed_by_zen[win] = option
		elseif role == "main" and not (prev and prev.windows[win]) then
			-- a window split off an integration copies its options
			for flag in pairs(zen_fixes) do
				vim.wo[win][0][flag] = false
			end
		end
	end
end

---@class SizePlan
---@field now Sizes current sizes
---@field extents table<table, { width: number, height: number }> cells each node covers now
---@field stacks table<number, number> heights for the `top`/`bottom` windows
---@field pad_width number
---@field source fun(node: table): Sizes sizes to share out the room of `node` by
---@field basis Sizes? sizes the last pass shared out room by
---@field kept table<number, table<Axis, boolean>> window sizes shared out by `basis`

--- Plans the sizes of the children of `node`, then of theirs. Pads and side
--- windows get their width, the stacks their height, and the rest of the room
--- goes to the other children in proportion to their size in `plan.source`.
---@param node table `winlayout()` node
---@param extent { width: number, height: number } cells `node` gets
---@param plan SizePlan
---@param ops SizeOp[]
local function plan_sizes(node, extent, plan, ops)
	if node[1] == "leaf" then
		return
	end
	local axis = node[1] == "row" and "width" or "height"
	local children = node[2]
	-- `room` ends up as the window cells, separators and status lines aside
	local room, extra, fixed, flex = extent[axis], {}, {}, {}
	for i, child in ipairs(children) do
		extra[i] = plan.extents[child][axis] - measure(child, axis, plan.now)
		room = room - extra[i]
		-- a band is sized through its first window, all of them share its height
		if axis == "height" and plan.stacks[first_leaf(child)] then
			fixed[i] = plan.stacks[first_leaf(child)]
		elseif axis == "width" and side_of(child) then
			fixed[i] = side_width(child, plan.pad_width)
		else
			table.insert(flex, i)
		end
	end
	if #flex == 0 then
		fixed[#children] = nil
		flex = { #children }
	end

	local mins, needed = {}, 0
	for k, i in ipairs(flex) do
		mins[k] = minimum(children[i], axis)
		needed = needed + mins[k]
	end
	local fixed_total = 0
	for _, size in pairs(fixed) do
		fixed_total = fixed_total + size
	end
	-- not enough room left over: the largest fixed children give some up
	local shortage = needed - (room - fixed_total)
	while shortage > 0 do
		local largest
		for i, size in pairs(fixed) do
			if size > 1 and (not largest or size > fixed[largest]) then
				largest = i
			end
		end
		if not largest then
			break
		end
		local cut = math.min(shortage, fixed[largest] - 1)
		fixed[largest] = fixed[largest] - cut
		fixed_total = fixed_total - cut
		shortage = shortage - cut
	end

	local weights = {}
	local source = #flex > 1 and plan.source(node) or plan.now
	for k, i in ipairs(flex) do
		weights[k] = measure(children[i], axis, source) or measure(children[i], axis, plan.now)
		for _, win in ipairs(leaves(children[i])) do
			plan.kept[win] = plan.kept[win] or {}
			plan.kept[win][axis] = source == plan.basis
		end
	end
	local parts = distribute(room - fixed_total, weights, mins)
	local cells = vim.deepcopy(fixed)
	for k, i in ipairs(flex) do
		cells[i] = parts[k]
	end

	-- a frame is sized through a window directly in it
	local handles, unsizable = {}, false
	for i, child in ipairs(children) do
		handles[i] = child[1] == "leaf" and child
			or vim.iter(child[2]):find(function(grandchild)
				return grandchild[1] == "leaf"
			end)
		unsizable = unsizable or not handles[i]
	end
	local child_extents = {}
	for i, child in ipairs(children) do
		child_extents[i] = { width = extent.width, height = extent.height }
		child_extents[i][axis] = cells[i] + extra[i]
		-- the one left out gets what the others leave
		local handle = handles[i]
		if handle and (unsizable or i < #children) then
			local own_extra = plan.extents[handle][axis] - plan.now[handle[2]][axis]
			table.insert(ops, {
				win = handle[2],
				axis = axis,
				size = child_extents[i][axis] - own_extra,
				leaf = child[1] == "leaf",
			})
		end
	end
	for i, child in ipairs(children) do
		plan_sizes(child, child_extents[i], plan, ops)
	end
end

--- Every pass rebuilds the layout the config asks for, around whatever main
--- windows exist:
---
---   col[ top…, row[ left | pad, main…, right | pad ], bottom… ]
---
--- Padding only exists while the main windows leave room for it. Then the
--- sizes are planned for the whole layout at once: the stacks keep their
--- heights, the sides their widths, and the main windows share what is left
--- in the proportions they had.
local function reconcile()
	local tab = vim.api.nvim_get_current_tabpage()
	local moved, mover, changed_by_event = moved_from ~= nil, moved_from, relayout
	moved_from, relayout = nil, false

	if quitting_tab then
		local quit = quitting_tab
		quitting_tab = nil
		if quit == tab and count_main_windows(tab) == 0 then
			pcall(vim.cmd, "tabclose")
			tab = vim.api.nvim_get_current_tabpage()
		end
	end
	for other in pairs(last) do
		if not vim.api.nvim_tabpage_is_valid(other) then
			last[other] = nil
		end
	end

	local current = vim.api.nvim_get_current_win()
	local tree = vim.fn.winlayout()

	if vim.o.columns <= main_width then
		for _, win in ipairs(leaves(tree)) do
			if classify(win) == "pad" then
				pcall(vim.api.nvim_win_close, win, true)
			end
		end
		last[tab] = nil
		return
	end
	local main = prune_layout(tree, is_main)
	if not main then
		last[tab] = nil
		return
	end
	local prev = last[tab]
	-- the layout and sizes as Neovim left them, before any window is moved below
	local original = tree
	local pre = sizes_of(leaves(tree))
	-- anything but resizing a window by hand, whose sizes are kept as they are
	local changed = not prev or moved or changed_by_event or layout_key(tree) ~= prev.key
	-- integrations are pinned: a move made from one is undone entirely
	if moved and prev and mover and vim.api.nvim_win_is_valid(mover) and classify(mover) ~= "main" then
		main = same_windows(leaves(tree), prev) and prev.main_tree or main
	end

	-- main windows sharing a row sit side by side, which leaves no room for pads
	local side_by_side = layout_key(main):find("row") ~= nil
	local has_integration, pads = {}, { left = {}, right = {} }
	for _, win in ipairs(leaves(tree)) do
		local role, side = classify(win)
		if role == "integration" then
			has_integration[side] = true
		elseif role == "pad" then
			table.insert(pads[side], win)
		end
	end
	for _, side in ipairs({ "left", "right" }) do
		local wanted = not side_by_side and not has_integration[side]
		for i, win in ipairs(pads[side]) do
			if not wanted or i > 1 then
				pcall(vim.api.nvim_win_close, win, true)
			end
		end
		if wanted and #pads[side] == 0 then
			create_pad(side)
		end
	end
	tree = vim.fn.winlayout()

	local wins = leaves(tree)
	local unchanged = same_windows(wins, prev)

	local function side_tree(side)
		return prune_layout(tree, function(win)
			local role, position = classify(win)
			return role ~= "main" and position == side
		end)
	end
	local middle = {}
	for _, part in ipairs({ { side_tree("left") }, { main }, { side_tree("right") } }) do
		table.insert(middle, part[1])
	end
	local bands = {
		top = stack_bands(wins, "top", prev and prev.stacks.top),
		bottom = stack_bands(wins, "bottom", prev and prev.stacks.bottom),
	}
	local column = vim.tbl_map(band_node, bands.top)
	table.insert(column, frame("row", middle))
	vim.list_extend(column, vim.tbl_map(band_node, bands.bottom))
	local target = frame("col", column)

	local rebuilt = layout_key(target) ~= layout_key(tree)
	if rebuilt then
		apply_layout(target)
		tree = vim.fn.winlayout()
	end
	wins = leaves(tree)
	fix_integration_sizes(wins, prev)

	-- After a change Neovim has shared out the room its own way, and moving
	-- windows above did so again. The sizes of the last pass are the ones the
	-- user saw: windows and frames that are still there get those back.
	local stacks = {}
	for _, position in ipairs({ "top", "bottom" }) do
		local stack = bands[position]
		local before = changed and prev and prev.stacks[position] or {}
		local known, total = {}, #before - #stack
		for _, band in ipairs(before) do
			known[band.key] = band.height
			total = total + band.height
		end
		local heights, survivors, new = {}, 0, {}
		for i, band in ipairs(stack) do
			if known[band.key] then
				heights[i] = known[band.key]
				survivors = survivors + heights[i]
			else
				heights[i] = 0
				for _, win in ipairs(band.wins) do
					heights[i] = math.max(heights[i], (pre[win] or sizes_of({ win })[win]).height)
				end
				table.insert(new, i)
			end
		end
		-- a stack keeps its height as bands leave or join it: the rows of a
		-- closed band go to the one nearest to main, a band replacing one gets
		-- the rows it left, and one joining gets an equal share. A band of an
		-- entry stays as long as any of its windows does.
		if #before > 0 and #stack > 0 then
			if #new == 0 then
				local boundary = position == "top" and #stack or 1
				heights[boundary] = heights[boundary] + total - survivors
			else
				local gone = #before - (#stack - #new)
				local sharing, room = new, total - survivors
				if gone == 0 or room < #new then
					sharing, room = vim.fn.range(1, #stack), total
				end
				local ones = vim.fn["repeat"]({ 1 }, #sharing)
				for k, size in ipairs(distribute(room, ones, ones)) do
					heights[sharing[k]] = size
				end
			end
		end
		for i, band in ipairs(stack) do
			for _, win in ipairs(band.wins) do
				stacks[win] = heights[i]
			end
		end
	end
	local now = sizes_of(wins)
	local extents = geometry(tree)
	local ops = {}
	local plan = {
		now = now,
		extents = extents,
		stacks = stacks,
		pad_width = math.floor((vim.o.columns - main_width) / 2),
		basis = prev and prev.basis,
		kept = {},
	}
	local shared_bands = {}
	for _, position in ipairs({ "top", "bottom" }) do
		for _, band in ipairs(bands[position]) do
			if #band.wins > 1 then
				shared_bands[layout_key(band_node(band))] = band
			end
		end
	end
	plan.source = function(node)
		if not changed or not prev then
			return pre
		end
		-- only moved: every window keeps the size it had
		if unchanged then
			return prev.basis
		end
		local filter = vim.iter(leaves(node)):any(is_main) and is_main
			or function(win)
				return classify(win) ~= "main"
			end
		local shared = prune_layout(node, filter)
		if shared and prev.frames[layout_key(shared)] then
			return prev.basis
		end
		-- windows only just brought together in a band share it equally, ones a
		-- plugin put side by side itself keep the widths it gave them
		local band = shared_bands[layout_key(node)]
		if band then
			local equal = {}
			for _, win in ipairs(band.wins) do
				equal[win] = { width = 1, height = 1 }
			end
			local before = prune_layout(original, function(win)
				return equal[win] ~= nil
			end)
			if not (before and before[1] == "row" and #before[2] == #band.wins) then
				return equal
			end
		end
		return pre
	end
	plan_sizes(tree, extents[tree], plan, ops)
	if vim.iter(ops):any(function(op)
		return now[op.win][op.axis] ~= op.size
	end) then
		apply_sizes(ops)
	end

	local focus = (rebuilt or moved) and unchanged and prev.current or current
	if vim.api.nvim_win_is_valid(focus) and classify(focus) ~= "pad" and focus ~= vim.api.nvim_get_current_win() then
		vim.api.nvim_set_current_win(focus)
	end
	local now_current = vim.api.nvim_get_current_win()
	local windows = {}
	for _, win in ipairs(wins) do
		windows[win] = classify(win) ~= "pad" or nil
	end
	local sizes = sizes_of(wins)
	-- sizes scaled from the basis keep it, so scaling back lands exactly, and so
	-- do the ones nothing changed since the last pass
	local basis = {}
	for win, size in pairs(sizes) do
		local kept = plan.kept[win] or {}
		local base = plan.basis and plan.basis[win] or {}
		local before = prev and prev.sizes[win] or {}
		basis[win] = {}
		for _, axis in ipairs({ "width", "height" }) do
			local keep = kept[axis] or size[axis] == before[axis]
			basis[win][axis] = keep and base[axis] or size[axis]
		end
	end
	local main_tree = prune_layout(tree, is_main) or { "leaf", 0 }
	for _, position in ipairs({ "top", "bottom" }) do
		for _, band in ipairs(bands[position]) do
			band.height = sizes[band.wins[1]].height
		end
	end
	last[tab] = {
		sizes = sizes,
		basis = basis,
		windows = windows,
		key = layout_key(tree),
		frames = frame_keys(tree, vim.list_extend(vim.list_slice(bands.top), bands.bottom)),
		main_tree = main_tree,
		current = classify(now_current) ~= "pad" and now_current or (prev and prev.current or now_current),
		stacks = bands,
	}
end

local function update()
	if updating or vim.v.exiting ~= vim.NIL then
		return
	end
	-- leave the layout alone while a command line is being typed (`:`, `q:`)
	-- or a dialog waits for an answer
	local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
	if vim.fn.getcmdwintype() ~= "" or mode == "c" or mode == "r" then
		return
	end
	if is_popup_window(vim.api.nvim_get_current_win()) then
		return
	end
	updating = true
	local eventignore = vim.o.eventignore
	vim.o.eventignore = "all"
	local ok, err = pcall(reconcile)
	vim.o.eventignore = eventignore
	updating = false
	if not ok then
		error(err, 0)
	end
end

---@param options? Config
local function setup(options)
	if vim.fn.has("nvim-0.11") == 0 then
		error("zen.nvim requires Neovim >= 0.11")
	end
	-- Default splitting will cause your main splits to jump when opening an integration.
	-- To prevent this, set `splitkeep` to either `screen` or `topline`.
	vim.opt.splitkeep = "screen"
	local group = vim.api.nvim_create_augroup("zen.nvim", { clear = true })

	---@type ConfigOptions
	opts = vim.tbl_extend("force", opts, options or {})
	refresh_main_width()

	vim.api.nvim_create_autocmd({ "VimEnter", "TabNew", "SafeState" }, {
		group = group,
		callback = update,
		desc = "Rebuild the layout around the main windows.",
	})

	vim.api.nvim_create_autocmd("VimResized", {
		group = group,
		callback = function()
			refresh_main_width()
			relayout = true
			update()
		end,
		desc = "Resize the side windows, close them if there is not enough space left.",
	})

	vim.api.nvim_create_autocmd("FocusGained", {
		group = group,
		callback = refresh_main_width,
		desc = "Refresh the main width after Neovim regains focus.",
	})

	-- `key` is what mappings turned the typed keys into, so a mapping to
	-- `<C-w>L` counts as well
	vim.on_key(function(key)
		if key == nil or key == "" then
			return
		end
		if wincmd_pending and key:match("^%d$") then
			return
		end
		if wincmd_pending and key:match("^[HJKLxrR]$") then
			moved_from = vim.api.nvim_get_current_win()
		end
		wincmd_pending = key == "\23" and vim.api.nvim_get_mode().mode == "n"
	end, vim.api.nvim_create_namespace("zen.nvim"))

	vim.api.nvim_create_autocmd("CmdlineLeave", {
		group = group,
		pattern = ":",
		callback = function()
			if not vim.v.event.abort and wincmd_command:match_str(vim.fn.getcmdline()) then
				moved_from = vim.api.nvim_get_current_win()
			end
		end,
		desc = "Remember `:wincmd` moves so integrations moved in place get their size back.",
	})

	vim.api.nvim_create_autocmd("QuitPre", {
		group = group,
		callback = function(args)
			if is_popup_window(vim.api.nvim_get_current_win()) or is_buff_integration(args.buf) then
				return
			end

			if count_main_windows(0) ~= 1 then
				return
			end

			for _, position in ipairs(positions) do
				for _, integration in ipairs(opts[position]) do
					if type(integration) == "table" then
						close(integration.filetype)
					end
				end
			end

			if vim.fn.tabpagenr("$") > 1 then
				-- `:q` only closes this tab's main window, the tab goes with it
				quitting_tab = vim.api.nvim_get_current_tabpage()
				return
			end

			-- `only_one_window()` ignores help windows: marked as help, the pads stay
			-- visible while `:q` treats the main window as the last one
			local buftypes = {}
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				local buf = vim.api.nvim_win_get_buf(win)
				-- already help while an earlier aborted quit waits to reset it
				if classify(win) == "pad" and vim.bo[buf].buftype ~= "help" then
					buftypes[buf] = vim.bo[buf].buftype
					vim.bo[buf].buftype = "help"
				end
			end
			-- `QuitPre` fires before Neovim checks for unsaved changes, so the quit can
			-- still be aborted (E37 or a cancelled `confirm`). `SafeState` only comes
			-- back once that is settled.
			vim.api.nvim_create_autocmd("SafeState", {
				group = group,
				callback = function()
					-- still waiting for the answer to a confirm dialog
					if vim.api.nvim_get_mode().mode:sub(1, 1) == "r" then
						return
					end
					for buf, buftype in pairs(buftypes) do
						if vim.api.nvim_buf_is_valid(buf) then
							vim.bo[buf].buftype = buftype
						end
					end
					return true
				end,
			})
		end,
		desc = "Let `:q` on the last main window quit, with or without side windows.",
	})

	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		callback = function(args)
			local win = tonumber(args.match)
			if vim.o.columns <= main_width or win == nil or not vim.api.nvim_win_is_valid(win) or is_popup_window(win) then
				return
			end
			local tab = vim.api.nvim_win_get_tabpage(win)
			relayout = relayout or tab == vim.api.nvim_get_current_tabpage()
			-- Restore within the close so no frame is drawn without a main window.
			if tab ~= quitting_tab and not is_buff_integration(vim.fn.winbufnr(win)) then
				restore_main_window(tab, win)
			end
		end,
		desc = "Put a main window back when the last one was closed.",
	})

	vim.api.nvim_create_autocmd("WinNew", {
		group = group,
		callback = function()
			if not is_popup_window(vim.api.nvim_get_current_win()) then
				relayout = true
			end
		end,
		desc = "Remember that a window opened, even if it is gone by the next layout pass.",
	})

	vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
		group = group,
		callback = function(args)
			if is_popup_window(vim.api.nvim_get_current_win()) then
				return
			end
			local filetype = vim.bo[args.buf].filetype
			local role, position = classify_filetype(filetype)
			local integration = position and find_integration(position, filetype)
			if role ~= "integration" or not position or not integration or integration.replace == false then
				return
			end
			for _, other in ipairs(opts[position]) do
				if type(other) == "table" and other.replace ~= false and not is_filetype(filetype, other.filetype) then
					close(other.filetype)
				end
			end
		end,
		desc = "Close the integrations that share a side with the one that was just opened.",
	})
end

return { setup = setup }
