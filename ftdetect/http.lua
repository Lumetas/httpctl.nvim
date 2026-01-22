vim.filetype.add({ extension = { http = "http" } })

--[[
-- Reset diagnostic by changing the file
vim.api.nvim_create_augroup("HTDiagnostic", { clear = true })
-- text change in Insert and Normal mode => diagnostic reset
vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
	group = "HTDiagnostic",
	pattern = "*.http",
	callback = function(ev)
		require("ht.diagnostic").reset(ev.buf)
	end,
})
-- text change in Esc and Normal mode => diagnostic on
-- vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
-- 	group = "HTDiagnostic",
-- 	pattern = "*.http",
-- 	callback = function(ev)
-- 		local winnr = vim.api.nvim_get_current_win()
-- 		local row = vim.api.nvim_win_get_cursor(winnr)[1]
-- 		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
--
-- 		-- local r = require("ht.parser").parse(lines, row)
-- 		local r = require("ht.parser").parse(lines, row)
-- 		require("ht.diagnostic").show(ev.buf, r)
-- 	end,
-- })
-- ]]
