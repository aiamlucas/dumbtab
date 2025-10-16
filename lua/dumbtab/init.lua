local M = {}

local function set_bufopt(buf, name, val)
	local ok = pcall(vim.api.nvim_set_option_value, name, val, { buf = buf })
	if not ok then
		vim.bo[buf][name] = val
	end
end

local function is_enabled()
	if vim.t.dumbtab_disabled == nil then
		-- default from setup(): true unless explicitly set to false
		return M.opts.enabled ~= false
	end
	return vim.t.dumbtab_disabled ~= true
end

local function ensure_pad_for_tab(width)
	if not is_enabled() then
		return
	end
	if vim.t.dumbtab_win and vim.api.nvim_win_is_valid(vim.t.dumbtab_win) then
		return
	end

	-- Leftmost vertical split
	vim.cmd("topleft vnew")
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_get_current_buf()

	-- Buffer: dummy + invisible to UIs
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "dumbtab"
	set_bufopt(buf, "buflisted", false)

	-- Window: fixed width, no UI chrome
	vim.wo[win].winfixwidth = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].list = false
	vim.wo[win].cursorline = false
	vim.wo[win].statuscolumn = ""
	vim.wo[win].winbar = ""

	-- Size + store
	vim.api.nvim_win_set_width(win, width)
	vim.t.dumbtab_win = win

	-- Keymaps inside pad: never stay here
	local function map(lhs, rhs)
		vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, nowait = true })
	end
	map("q", "<Cmd>wincmd l<CR>")
	map("<CR>", "<Cmd>wincmd l<CR>")
	map("<Tab>", "<Cmd>wincmd l<CR>")
	map("<C-w>w", "<Cmd>wincmd l<CR>")
	map("<C-w>l", "<Cmd>wincmd l<CR>")
	map("<C-w>h", "<Cmd>wincmd l<CR>")
	map("h", "<Cmd>wincmd l<CR>")
	map("<Left>", "<Cmd>wincmd l<CR>")

	-- Return focus to the right
	vim.cmd("wincmd l")
end

-- Bounce focus if it ever lands in the pad
local function bounce_if_pad()
	local win = vim.api.nvim_get_current_win()
	if win == vim.t.dumbtab_win then
		vim.schedule(function()
			if vim.api.nvim_win_is_valid(win) then
				vim.cmd("wincmd l")
			end
		end)
	end
end

M.opts = { width = 20, enabled = true }

M.setup = function(opts)
	M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

	-- Create at startup and on new tabs
	vim.api.nvim_create_autocmd({ "VimEnter", "TabEnter" }, {
		callback = function()
			ensure_pad_for_tab(M.opts.width)
		end,
	})

	-- Recreate if closed (only when enabled)
	vim.api.nvim_create_autocmd("WinClosed", {
		callback = function()
			vim.schedule(function()
				if is_enabled() and not (vim.t.dumbtab_win and vim.api.nvim_win_is_valid(vim.t.dumbtab_win)) then
					ensure_pad_for_tab(M.opts.width)
				end
			end)
		end,
	})

	-- Never keep focus in the pad
	vim.api.nvim_create_autocmd("WinEnter", {
		callback = bounce_if_pad,
	})

	-- Create immediately for the current tab
	ensure_pad_for_tab(M.opts.width)

	-- Toggle per tab
	vim.api.nvim_create_user_command("DumbtabToggle", function()
		if is_enabled() then
			-- disable for this tab and close if present
			vim.t.dumbtab_disabled = true
			if vim.t.dumbtab_win and vim.api.nvim_win_is_valid(vim.t.dumbtab_win) then
				pcall(vim.api.nvim_win_close, vim.t.dumbtab_win, true)
			end
			vim.t.dumbtab_win = nil
		else
			-- enable and (re)create
			vim.t.dumbtab_disabled = false
			ensure_pad_for_tab(M.opts.width)
		end
	end, {})
end

return M
