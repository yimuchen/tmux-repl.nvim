local M = {}

M.settings = {
	repl_pane_bkg_idx = 9,
	repl_pane_bkg_name = "(repl-bkg)",
	repl_start_cmd = nil, -- This can either be nil or a function to determine how the command should be executed
}

M.toggle_repl_term = function() end

M.get_tmux_identifier = function(type)
	-- Getting the current id of the tmux session that is holding the nvim session
	if vim.env.TMUX == nil then
		vim.notify("Currently not in tmux session", vim.log.levels.ERROR, { title = "tmux-repl" })
		return ""
	end
	local obj = vim.system({ "tmux", "display-message", "-p", "#" .. type }, { text = true }):wait()
	return obj.stdout:sub(1, -2)
end

M.get_tmux_session = function()
	return M.get_tmux_identifier("S")
end

M.get_tmux_window = function()
	return tonumber(M.get_tmux_identifier("I"))
end

M.get_tmux_pane = function()
	return tonumber(M.get_tmux_identifier("P"))
end

M.tmux_id_str = function(session, window, pane)
	if pane ~= nil then
		return session .. ":" .. window .. "." .. pane
	else
		return session .. ":" .. window
	end
end

-- Checking where a tmux id exists
M.check_tmux_idstr = function(id_str)
	local obj = vim.system({ "tmux", "has-session", "-t", id_str }, { text = true }):wait()
	return obj.code == 0
end

M.check_tmux_has_id = function(session, window, pane)
	local id = M.tmux_id_str(session, window, pane)
	return M.check_tmux_idstr(id)
end

-- Getting the string representing the editor window
M.tmux_editor_window = function()
	local session = M.get_tmux_session()
	local editor_window = M.get_tmux_window()
	return M.tmux_id_str(session, editor_window)
end

M.tmux_editor_pane = function()
	local session = M.get_tmux_session()
	local window = M.get_tmux_window()
	local pane = M.get_tmux_pane()
	return M.tmux_id_str(session, window, pane)
end

M.tmux_repl_fg_id = function()
	local session = M.get_tmux_session()
	local window = M.get_tmux_window()
	local pane = M.get_tmux_pane() + 1
	return M.tmux_id_str(session, window, pane)
end

M.tmux_repl_bkg_window = function()
	local session = M.get_tmux_session()
	return M.tmux_id_str(session, M.settings.repl_pane_bkg_idx)
end

M.tmux_repl_bkg_id = function()
	local session = M.get_tmux_session()
	return M.tmux_id_str(session, M.settings.repl_pane_bkg_idx, 0)
end

-- Bringing the REPL tmux to the foreground (next to the nvim pane)
-- Automatically spawn if it doesn't already exist
M.repl_pane_foreground = function()
	if M.get_tmux_session() == "" then
		return
	end
	local fg_idstr = M.tmux_repl_fg_id()
	local bkg_idstr = M.tmux_repl_bkg_id()
	local win_id = M.tmux_editor_window()
	local ed_pane = M.tmux_editor_pane()

	if not M.check_tmux_idstr(fg_idstr) then
		-- Foreground pane does not exist.
		--
		-- First we check if a background window exist, if it does we bring it to the for-group
		-- if it doesn't, then we create a new pane
		if M.check_tmux_idstr(bkg_idstr) then
			vim.system({ "tmux", "join-pane", "-s", bkg_idstr, "-t", win_id, "-h", "-l", "80" }):wait()
		else
			vim.system({ "tmux", "split-window", "-t", win_id, "-h", "-l", "80" }):wait()
			vim.system({ "tmux", "resize-pane", "-t", fg_idstr, "-x", "80" }):wait()
			if M.settings.repl_start_cmd ~= nil then
				local start_cmd = M.settings.repl_start_cmd()
				if start_cmd ~= nil then
					vim.notify(
						"Creating new pane with command [" .. start_cmd .. "]",
						vim.log.levels.INFO,
						{ title = "tmux-repl" }
					)
					vim.system({ "tmux", "respawn-pane", "-t", fg_idstr, "-k", start_cmd }):wait()
				end
			end
		end
	end

	-- Always keep the editor pane in focus regardless of what method is used
	vim.system({ "tmux", "select-pane", "-t", ed_pane }):wait()
end

-- Sending repl page to background if it doesn't already exist
M.repl_pane_background = function()
	if M.get_tmux_session() == "" then
		return
	end
	local fg_idstr = M.tmux_repl_fg_id()
	local bkg_win = M.tmux_repl_bkg_window()
	-- REPL pane is in foreground send to back
	if M.check_tmux_idstr(fg_idstr) then
		vim.system({ "tmux", "break-pane", "-d", "-s", fg_idstr, "-t", bkg_win }):wait()
		vim.system({ "tmux", "rename-window", "-t", bkg_win, M.settings.repl_pane_bkg_name }):wait()
	end
end

-- Closing the repl pane. Here we are hard shutting down with tmux kill
M.repl_pane_close = function()
	if M.get_tmux_session() == "" then
		return
	end
	local fg_idstr = M.tmux_repl_fg_id()
	if M.check_tmux_idstr(fg_idstr) then
		vim.system({ "tmux", "kill-pane", "-t", fg_idstr })
		return
	end
	local bkg_win = M.tmux_repl_bkg_window()
	if M.check_tmux_idstr(bkg_win) then
		vim.system({ "tmux", "kill-window", "-t", bkg_win })
	end
end

M.repl_pane_toggle = function()
	if M.get_tmux_session() == "" then
		return
	end
	local fg_idstr = M.tmux_repl_fg_id()
	if M.check_tmux_idstr(fg_idstr) then
		M.repl_pane_background()
	else
		M.repl_pane_foreground()
	end
end

-- Actually passing items
M.repl_send_line = function(line)
	if M.get_tmux_session() == "" then
		return
	end
	-- Bringing the repl pane to the foreground
	M.repl_pane_foreground()
	local fg_idstr = M.tmux_repl_fg_id()
	-- Running the send keys in the background to avoid setting up the items
	vim.system({ "tmux", "send-keys", "-t", fg_idstr, line, "Enter" })
end

-- Getting the visual selections line by line, this solution was from a GitHub
-- comment for ToggleTerm REPL interactions:
-- https://github.com/akinsho/toggleterm.nvim/issues/425#issuecomment-1854373704
M.repl_pass_visual = function()
	-- visual markers only update after leaving visual mode
	if M.get_tmux_session() == "" then
		return
	end

	-- Open the repl pane if not already open
	M.repl_pane_foreground()

	-- Exiting the visual selection
	local esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
	vim.api.nvim_feedkeys(esc, "x", false)

	-- get selected text
	local start_line, _ = unpack(vim.api.nvim_buf_get_mark(0, "<"))
	local end_line, _ = unpack(vim.api.nvim_buf_get_mark(0, ">"))
	local lines = vim.fn.getline(start_line, end_line)

	local line_count = 0
	local indent = nil
	for idx, line in ipairs(lines) do
		if indent == nil and line:find("[^%s]") ~= nil then
			indent = line:find("[^%s]")
		end
		-- Skipping empty line
		if idx == table.getn(lines) then
			M.repl_send_line(line .. "\n") -- No not modify the last line
		else
			M.repl_send_line(line:sub(indent or 1))
		end
	end
	if line_count > 0 then -- Add final newline to ensure the item is executed
		local fg_idstr = M.tmux_repl_fg_id()
		vim.system({ "tmux", "send-keys", "-t", fg_idstr, "KPEnter" })
	end
end

M.setup = function(opts)
	M.settings = vim.tbl_deep_extend("force", opts, M.settings)

	-- Always push REPL pane to background when vim closes, because the vim can
	-- potentially be terminated,
	vim.api.nvim_create_autocmd({ "ExitPre" }, {
		desc = "Push REPL pane to background on exit",
		callback = M.repl_pane_background,
	})
end

return M
