local curl = require("plenary.curl")
local pjob = require("plenary.job")
local _globals = require("resty.globals")

local M = {
	is_jq_installed = true,
	-- global_variables = require("resty.parser").get_global_variables()
}

-- --------- JQ -------------------
M._create_jq_job = function(json, callback, jq_filter)
	local filter = jq_filter or "."
	return pjob:new({
		command = "jq",
		args = { filter },
		writer = json,
		on_exit = function(job, code)
			local output

			if code == 0 then
				output = job:result()
			else
				output = job:stderr_result()
				table.insert(output, 1, "ERROR in parsing json with jq:")
				table.insert(output, 2, "")
				table.insert(output, "")
				table.insert(output, "")
				table.insert(output, ">>> you can press key: 'r' to [r]eset the view")
			end

			vim.schedule(function()
				job.is_finished = true
				callback(output, code)
			end)
		end,
	})
end

---  Create an async job for the jq commend.
---
---@param json string the JSON string
---@param callback function callback function where to get the result
---@param jq_filter? string a jq filter, default is '.'
M.jq = function(json, callback, jq_filter)
	if M.is_jq_installed == true then
		local ok, job = pcall(M._create_jq_job, json, callback, jq_filter)
		if ok then
			job:start()
		else
			M.is_jq_installed = false
			vim.notify("jq is not installed")
		end
	end

	return M.is_jq_installed
end

---  Create an sync job for the jq commend.
---
---@param timeout number  the timeout value in ms
---@param json string the JSON string
---@param callback function callback function where to get the result
---@param jq_filter? string a jq filter, default is '.'
M.jq_wait = function(timeout, json, callback, jq_filter)
	if M.is_jq_installed == true then
		local ok, job = pcall(M._create_jq_job, json, callback, jq_filter)
		if ok then
			job:start()

			vim.wait(timeout, function()
				return job.is_finished
			end)

			job:shutdown()
		else
			M.is_jq_installed = false
			vim.notify("jq is not installed")
		end
	end

	return M.is_jq_installed
end

-- --------- CURL -------------------

---  Create an async job for the curl commend.
---
---@param request table  the request definition
---@param callback function callback function where to get the result
---@param error function callback function to get the error result if it occurred
M.curl = function(request, callback, error)
	return M._create_curl_job(request, callback, error)
end

---  Create an sync job for the curl commend.
---
---@param timeout number  the timeout value in ms
---@param request table  the request definition
---@param callback function callback function where to get the result
---@param error function callback function to get the error result if it occurred
M.curl_wait = function(timeout, request, callback, error)
	local job = M._create_curl_job(request, callback, error)
	vim.wait(timeout, function()
		return job.is_finished
	end)

	job:shutdown()
end

M.exec_with_stop_time = function(fn, ...)
	local start_time = vim.loop.hrtime()
	local results = { fn(...) }
	table.insert(results, vim.loop.hrtime() - start_time)
	---@diagnostic disable-next-line: deprecated
	return unpack(results)
end

M.cmd = function(cmd)
	local handle = io.popen(cmd .. " 2>&1")
	if handle then
		-- read the cmd output
		local result = handle:read("*a")
		handle:close()
		return result
	end

	return "could not create a handle for command: " .. cmd
end


function M.run_pre_script(code, request)
    if not code or vim.trim(code):len() == 0 then
        return request
    end
    
    M.global_variables = _globals.get_global_variables()
    
    -- Функция для замены переменных вида %var% в строке
    local function replace_variables(str)
        if not str or type(str) ~= "string" then
            return str
        end
        
        return str:gsub("%%([^%%]+)%%", function(var_name)
            -- Сначала проверяем динамические переменные
            local dynamic_value = request.dynamic_variables and request.dynamic_variables[tostring(var_name)]
            if dynamic_value then
                return dynamic_value
            end
            
            -- Затем проверяем глобальные переменные
            local global_value = _globals.get_global_variable(tostring(var_name))
            if global_value then
                return global_value
            end
            
            -- Если переменная не найдена, оставляем как есть
            return "%" .. var_name .. "%"
        end)
    end
    
    -- Функция для замены переменных в таблице
    local function replace_in_table(tbl)
        if not tbl or type(tbl) ~= "table" then
            return tbl
        end
        
        local result = {}
        for k, v in pairs(tbl) do
            if type(v) == "string" then
                result[k] = replace_variables(v)
            elseif type(v) == "table" then
                result[k] = replace_in_table(v)
            else
                result[k] = v
            end
        end
        return result
    end
    
    -- Функция для применения замены переменных ко всему запросу
    local function apply_variable_substitution(req)
        -- Заменяем в URL
        if req.url and type(req.url) == "string" then
            req.url = replace_variables(req.url)
        end
        
        -- Заменяем в headers
        if req.headers and type(req.headers) == "table" then
            req.headers = replace_in_table(req.headers)
        end
        
        -- Заменяем в query параметрах
        if req.query and type(req.query) == "table" then
            req.query = replace_in_table(req.query)
        end
        
        -- Заменяем в body
        if req.body then
            if type(req.body) == "string" then
                req.body = replace_variables(req.body)
            elseif type(req.body) == "table" then
                req.body = replace_in_table(req.body)
            end
        end
        
        return req
    end
    
    local ctx = {
        -- Доступ к текущему запросу
        request = request,
        set_dynamic = function(key, value)
            if not request.dynamic_variables then
                request.dynamic_variables = {}
            end
            request.dynamic_variables[tostring(key)] = tostring(value)
        end,
        -- get global variable
        get = function(key)
            return _globals.get_global_variable(tostring(key))
        end,
        -- Модифицировать запрос перед выполнением
        modify_request = function(modifications)
            if modifications.method then
                request.method = modifications.method
            end
            if modifications.url then
                request.url = modifications.url
            end
            if modifications.headers then
                request.headers = vim.tbl_extend("force", request.headers or {}, modifications.headers)
            end
            if modifications.query then
                request.query = vim.tbl_extend("force", request.query or {}, modifications.query)
            end
            if modifications.body then
                request.body = modifications.body
            end
        end,
        -- Выполнить команду
        exec = function(cmd)
            return M.cmd(cmd)
        end
    }
    
    local env = { api = ctx }
    setmetatable(env, { __index = _G })
    
    local f, err = load(code, "pre-script error", "bt", env)
    if f then
        f()
    else
        vim.notify("Pre-script error: " .. err, vim.log.levels.ERROR)
    end
    
    -- Применяем подстановку переменных перед возвратом запроса
    apply_variable_substitution(request)
    
    return request
end


-- Обновим функцию _create_curl_job чтобы выполнять pre-script перед запросом
M._create_curl_job = function(request, callback, error_callback)
    local job
    
    -- Выполняем pre-script если есть
    if request.pre_script then
        request = M.run_pre_script(request.pre_script, request)
    end
    
    request.callback = function(result)
        job.is_finished = true
        
        if request.script then
            result.global_variables = M.script(request.script, result)
        else
            result.global_variables = {}
        end
        
        callback(result)
    end
    request.on_error = function(result)
        job.is_finished = true
        error_callback(result)
    end
    
    job = curl.request(request.url, request)
    job.is_finished = false
    
    return job
end

-- Также обновим функцию script для post-scripts чтобы было понятнее:
function M.script(code, result)
    if not code or vim.trim(code):len() == 0 then
        return {}
    end
    
    M.global_variables = _globals.get_global_variables()
    
    local ctx = {
        -- body = '{}', status = 200, headers = {}, exit = 0, global_variables = {}
        result = result,
        response = result,
        -- set global variables with key and value
        set = function(key, value)
            M.global_variables[tostring(key)] = tostring(value)
        end,
        -- JSON parse the body
        json_body = function()
            return vim.json.decode(result.body)
        end,
        
        get = function(key)
            return M.global_variables[tostring(key)]
        end,
        
        -- jq to the body
        jq_body = function(filter)
            local b = string.gsub(result.body, "\n", " ")
            local c = "echo '" .. b .. "' | jq '" .. filter .. "'"
            local r = M.cmd(c)
            return string.gsub(r, "\n", "")
        end,
        
        -- Доступ к оригинальному запросу (если нужно)
        request = result._request or {},
    }
    
    local env = { api = ctx }
    setmetatable(env, { __index = _G })
    
    local f, err = load(code, "script error", "bt", env)
    if f then
        f()
    else
        error(err, 0)
    end
    
    return M.global_variables
end


return M
