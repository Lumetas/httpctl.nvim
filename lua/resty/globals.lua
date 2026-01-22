local M = {}
local global_variables = {}

function M.get_global_variables()
	return global_variables
end

function M.set_global_variables(gvars)
	global_variables = gvars
end

function M.set_global_variable(key, value)
	global_variables[key] = value
end

function M.get_global_variable(key)
	return global_variables[key]
end	

function M.test()
	print(global_variables)
end

return M

