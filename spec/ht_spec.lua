local ht = require("ht")
local exec = require("ht.exec")
local assert = require("luassert")
local stub = require("luassert.stub")

describe("ht:", function()
	it("default setup", function()
		ht.setup({})
		assert.is_true(ht.config.response.with_folding)
		assert.are.same("ht_response", ht.config.response.bufname)
	end)

	it("setup", function()
		ht.setup({ response = { with_folding = false, bufname = "foo" } })
		assert.is_false(ht.config.response.with_folding)
		assert.are.same("foo", ht.config.response.bufname)
	end)

	-- create an curl stub
	local curl = stub.new(exec, "curl")

	-- mock the curl call
	curl.invokes(function(_, callback, _)
		callback({
			body = '{"name": "foo"}',
			status = 200,
			headers = {},
			global_variables = {},
		})

		-- returns a dummy metatable, else the exec function interpreted the call as dry-run
		return setmetatable({}, { __index = {} })
	end)

	it("_run and run_last", function()
		assert.are.same(0, ht.output.current_menu_id)

		-- call ht command RUN
		ht._run({
			"###",
			"GET https://dummy",
			"postId = 5",
			"id=21",
		})
		vim.wait(50, function()
			return false
		end)

		assert.is_true(ht.output.curl.duration > 0)

		-- show response body
		assert.are.same(1, ht.output.current_menu_id)
		assert.are.same("json", vim.api.nvim_get_option_value("filetype", { buf = ht.output.bufnr }))
		assert.are.same({ "", '{"name": "foo"}' }, vim.api.nvim_buf_get_lines(ht.output.bufnr, 0, -1, false))

		-- call ht command LAST
		ht.last()
		vim.wait(50, function()
			return false
		end)

		assert.is_true(ht.output.curl.duration > 0)

		-- show response body
		assert.are.same(1, ht.output.current_menu_id)
		assert.are.same("json", vim.api.nvim_get_option_value("filetype", { buf = ht.output.bufnr }))
		assert.are.same({ "", '{"name": "foo"}' }, vim.api.nvim_buf_get_lines(ht.output.bufnr, 0, -1, false))
	end)

	it("run input", function()
		ht.run("GET http://dummy\n id = 7")
		vim.wait(50, function()
			return false
		end)

		-- no parse errors
		assert.are.same({}, ht.output.parse_result.diagnostics)

		assert.is_true(ht.output.curl.duration > 0)

		-- show response body
		assert.are.same(1, ht.output.current_menu_id)
		assert.are.same("json", vim.api.nvim_get_option_value("filetype", { buf = ht.output.bufnr }))
		assert.are.same({ "", '{"name": "foo"}' }, vim.api.nvim_buf_get_lines(ht.output.bufnr, 0, -1, false))
	end)
end)
