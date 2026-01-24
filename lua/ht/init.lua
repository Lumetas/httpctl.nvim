P = function(tab)
	print(vim.inspect(tab))
end

local parser = require("ht.parser")
local output = require("ht.output")
local diagnostic = require("ht.diagnostic")
local util = require("ht.util")

local default_config = {
	output = {
		move_to_win = true,
		body_pretty_print = false,
	},
	response = {
		with_folding = true,
		bufname = "ht_response",
		output_window_split = "right", -- Split direction: "left", "right", "above", "below".
		auto_focus_response = true,
	},
	highlight = {
		hint_replace = "LightYellow",
	},
}

-- change with: ':let g:ht.diagnostics = v:false'
-- print current value: ':lua print(vim.g.ht.diagnostics)'
vim.g.ht = { diagnostics = true, completion = true, variables_preview = true }

local M = {
	output = output.new(default_config),
	config = default_config,
	last_parser_result = nil,
}

M.setup = function(user_configs)
	M.config = vim.tbl_deep_extend("force", default_config, user_configs)
	

	M.output = output.new(M.config)
end

_G._ht_select_window = function(win_id)
	M.output:select_window(win_id)
end

M.last = function()
	if M.last_parser_result then
		M.output:exec_and_show_response(M.last_parser_result)
	else
		error("No last request found. Run first [HT run]", 0)
	end
end

M.run = function(input)
	if input and input:len() > 0 then
		M._run(input)
		return
	end

	local lines, row = util.get_lines_and_row_from_current_buf()
	M._run(lines, row, 0)
end

-- check, is telescope installed for viewing favorites
local has_telescope = pcall(require, "telescope")
local f = require("ht.extension.favorites")

M.favorite = function(favorite, bufnr)
	-- bufnr = f.get_current_bufnr(bufnr)
	bufnr = bufnr or 0
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)

	if favorite and #favorite > 0 then
		local row = f.find_favorite(lines, favorite)
		if row then
			M._run(lines, row, bufnr)
		else
			error("Favorite: '" .. favorite .. "' not found", 0)
		end
	elseif has_telescope then
		local favorites = f.find_all_favorites(lines)
		require("ht.extension.favorites_view").show(favorites, lines, function(row)
			M._run(lines, row, bufnr)
		end)
	else
		error("For this action you must install: 'telescope.nvim'", 0)
	end
end

M._run = function(lines, row, bufnr)
	local result = parser.parse(lines, row)
	if diagnostic.check_errors(bufnr, result) then
		return
	end

	-- save the last result
	M.last_parser_result = result
	M.output:exec_and_show_response(M.last_parser_result)
end

M.show_debug_info = function()
	local lines, row = util.get_lines_and_row_from_current_buf()
	local result = parser.parse(lines, row)

	M.output:show_debug_info(result)
end

--[[
package.loaded["ht"] = nil
package.loaded["ht.output"] = nil
package.loaded["ht.output.winbar"] = nil
]]

return M
