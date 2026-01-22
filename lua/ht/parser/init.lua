local util = require("ht.util")
local result = require("ht.parser.result")
local curl_cmd = require("ht.parser.curl")

local INF = vim.diagnostic.severity.INFO
local WRN = vim.diagnostic.severity.WARN
local ERR = vim.diagnostic.severity.ERROR

local M = {}

M.set_global_variables = function(gvars)
    result.global_variables = vim.tbl_deep_extend("force", result.global_variables, gvars)
end

M.new = function(input, selected, opts)
    local lines = util.input_to_lines(input)

    local parser = setmetatable({
        lines = lines,
        len = #lines,
    }, { __index = M })

    if not selected then
        selected = 1
    elseif selected > parser.len then
        selected = parser.len
    elseif selected <= 0 then
        selected = 1
    end
    -- NOTE: maybe better on result?
    parser.selected = selected

    parser.r = result.new(opts)

    return parser
end

function M:find_area()
    self.r.meta.area.starts = 1
    self.r.meta.area.ends = self.len

    -- start
    for i = self.selected, 1, -1 do
        if string.sub(self.lines[i], 1, 3) == "###" then
            self.r.meta.area.starts = i + 1
            break
        end
    end

    -- end
    for i = self.selected, self.len do
        if string.sub(self.lines[i], 1, 3) == "###" and i ~= self.selected then
            self.r.meta.area.ends = i - 1
            break
        end
    end

    return self.r.meta.area.starts, self.r.meta.area.ends
end

M.parse = function(input, selected, opts)
    local start = vim.loop.hrtime()

    local parser = M.new(input, selected, opts)
    local s, e = parser:find_area()

    -- start > 1, means, there are global variables
    if s > 1 then
        parser.cursor = 1
        parser.len = s - 1
        parser:_parse_variables(nil, true)
    end

    parser:parse_definition(s, e)

    parser.r.duration = vim.loop.hrtime() - start
    return parser.r
end

-- parse only the fined area (e.g. between two ###)
M.parse_area = function(input, selected, opts)
    local parser = M.new(input, selected, opts)
    return parser:parse_definition(parser:find_area()).r
end

function M:parse_definition(from, to)
    self.cursor = from
    self.len = to

    local line = self:_parse_variables()
    -- no more lines available
    -- only variables are ok for global area
    if not line then
        -- LOCAL variables
        if self.r.meta.area.starts ~= 1 then
            self.r:add_diag(ERR, "no request URL found", 0, 0, from, to)
        -- GLOBAL variables: self.r.meta.area.starts = 1
        elseif self.r.opts.is_in_execute_mode == true then
            self.r:add_diag(ERR, "no request URL found. please set the cursor to an valid request", 0, 0, from, to)
        end
        return self
    end

    local parsers = nil

    -- check, the current line: a request or a curl command
    if line:sub(1, 5) == ">curl" then
        parsers = {
            M._parse_curl_command,
            M._parse_script,
            M._parse_after_last,
        }
    else
        parsers = {
            M._parse_request,
            M._parse_headers_queries,
            M._parse_body,
            M._parse_script,
            M._parse_after_last,
        }
    end

    for _, parse in ipairs(parsers) do
        line = parse(self, line)
        if not line then
            break
        end
    end

    if not self.r.request.url or self.r.request.url == "" then
        self.r:add_diag(ERR, "no request URL found", 0, 0, from, to)
    end

    self.r:url_with_query_string()
    return self
end

function M:_parse_curl_command(line)
    local curl = curl_cmd.new(self.r)
    self.r.meta.curl = { starts = self.cursor, ends = self.cursor }

    curl.c = 5 -- cut: '>curl'
    curl:parse_line(line, self.cursor)
    self.cursor = self.cursor + 1

    for lnum = self.cursor, self.len do
        line = self.lines[lnum]

        -- an empty line, then stop
        if string.match(line, "^%s*$") then
            self.cursor = lnum
            return line
        else
            self.r.meta.curl.ends = lnum
            self.cursor = lnum
            curl.c = 1
            curl:parse_line(line, lnum)
        end
    end
end

local WS = "([%s]*)"
local REST = "(.*)"
local VALUE = "([^#]*)"

-- -------
-- request
-- -------
local METHOD = "^([%a]+)"
local URL = "([^#%s]*)"
local HTTP_VERSION = "([HTTP%/%.%d]*)"

local REQUEST = METHOD .. WS .. URL .. WS .. HTTP_VERSION .. WS .. REST

local methods =
    { GET = "", HEAD = "", OPTIONS = "", TRACE = "", PUT = "", DELETE = "", POST = "", PATCH = "", CONNECT = "" }

function M:_parse_request(line)
    local req = self.r.request

    line = self.r:replace_variable(line, self.cursor)

    local method, ws1, url, ws2, hv, ws3, rest = string.match(line, REQUEST)

    if not method then
        self.r:add_diag(ERR, "http method is missing or doesn't start with a letter", 0, 0, self.cursor)
        return line
    elseif ws1 == "" then
        local _, no_letter = string.match(line, "([%a]+)([^%s]?)")
        if no_letter and no_letter ~= "" then
            self.r:add_diag(ERR, "this is not a valid http method", 0, #method, self.cursor)
        else
            self.r:add_diag(ERR, "white space after http method is missing", 0, #method, self.cursor)
        end
        return line
    elseif url == "" then
        local msg = "url is missing"
        if methods[method] ~= "" then
            msg = "unknown http method and missing url"
        end
        self.r:add_diag(ERR, msg, 0, #method + #ws1 + #url, self.cursor)
        return line
    elseif #rest > 0 and not string.match(rest, "[%s]*#") then
        self.r:add_diag(
            INF,
            "invalid input after the request definition: '" .. rest .. "', maybe spaces?",
            0,
            #method + #ws1 + #url + #ws2 + #hv + #ws3,
            self.cursor
        )
    end

    if hv ~= "" then
        req.http_version = hv
    end

    if methods[method] ~= "" then
        self.r:add_diag(INF, "unknown http method", 0, #method, self.cursor)
    end

    if string.sub(url, 1, 4) ~= "http" then
        self.r:add_diag(ERR, "url must start with http", 0, #method + #ws1 + #url, self.cursor)
    end

    req.method = method
    req.url = url
    self.r.meta.request = self.cursor
    self.cursor = self.cursor + 1

    return line
end

-- ---------
-- variables
-- ---------
local VKEY = "^@([%a][%w%-_%.]*)"
local VARIABLE = VKEY .. WS .. "([=]?)" .. WS .. VALUE .. REST

local configures = { insecure = "", raw = "", timeout = "", proxy = "", dry_run = "", check_json_body = "" }

function M:_parse_variables(_, is_global)
    local _globals = require("ht.globals")
    for lnum = self.cursor, self.len do
        local line = self.lines[lnum]
        local first_char = string.sub(line, 1, 1)

        if is_global and string.sub(line, 1, 3) == "###" then
            -- stop searching for global variables if you find a new request
            self.cursor = lnum
            return line
        elseif first_char == "" or first_char == "#" or line:match("^%s") then
            -- ignore comment and blank line
        elseif first_char ~= "@" then
            self.cursor = lnum
            return line
        else
            local k, ws1, d, ws2, v, rest = string.match(line, VARIABLE)
            self.cursor = lnum + 1

            if not k then
                self.r:add_diag(ERR, "valid variable key is missing", 0, 1, lnum)
            elseif d == "" then
                self.r:add_diag(ERR, "variable delimiter is missing", 0, 1 + #k + #ws1, lnum)
            elseif v == "" then
                self.r:add_diag(ERR, "variable value is missing", 0, 1 + #k + #ws1 + #d + #ws2, lnum)
            elseif rest and rest ~= "" and not string.match(rest, "^#") then
                local col = 1 + #k + #ws1 + #d + #ws2 + #v
                self.r:add_diag(INF, "invalid input after the variable: " .. rest, 0, col, lnum)
            end

            if k and v ~= "" then
                local key = string.sub(k, 1, 4)
                if key == "cfg." and #k > 4 then
                    key = string.sub(k, 5)
                    if configures[key] ~= "" then
                        self.r:add_diag(INF, "unknown configuration key", 0, #k, lnum)
                    end
                    self.r.request[key] = self.r:to_cfg_value(key, v, lnum)
                else
                    v = self.r:replace_variable(v, lnum)
                    self.r.variables[k] = vim.trim(v)
                    _globals.set_global_variable(k, v)
                    self.r.meta.variables[k] = lnum

                    if not self.r.meta.variables.starts then
                        self.r.meta.variables.starts = lnum
                        self.r.meta.variables.ends = lnum
                    else
                        self.r.meta.variables.ends = lnum
                    end
                end
            end
        end
    end

    -- on the end, means only variables or nothing found
    -- -> must be the global variables area
    return nil
end

-- -------------------
-- headers and queries
-- -------------------
local HQKEY = "([^=:%s]+)"
local HEADER_QUERY = HQKEY .. WS .. "([:=]?)" .. WS .. VALUE .. REST

function M:_parse_headers_queries()
    -- Парсим заголовки пока они есть
    while self.cursor <= self.len do
        local line = self.lines[self.cursor]
        local first_char = string.sub(line, 1, 1)
        
        -- Если пустая строка, комментарий или не начинается с буквы - это конец заголовков
        if first_char == "" or first_char == "#" or line:match("^%s") or not string.match(first_char, "%a") then
            return line  -- Возвращаем текущую строку для следующего парсера
        end
        
        local k, ws1, d, ws2, v, rest = string.match(line, HEADER_QUERY)
        
        if not k or not d then
            -- Если не похоже на заголовок/query, прекращаем парсинг заголовков
            return line
        end
        
        self.cursor = self.cursor + 1
        
        if d == "" then
            self.r:add_diag(ERR, "header: ':' or query: '=' delimiter is missing", 0, #k + #ws1, self.cursor - 1)
        elseif v == "" then
            local kind = "header"
            if d == "=" then
                kind = "query"
            end
            self.r:add_diag(ERR, kind .. " value is missing", 0, #k + #ws1 + #d + #ws2, self.cursor - 1)
        elseif rest and rest ~= "" and not string.match(rest, "^#") then
            local col = #k + #ws1 + #d + #ws2 + #v
            local kind = "header"
            if d == "=" then
                kind = "query"
            end
            self.r:add_diag(INF, "invalid input after the " .. kind .. ": " .. rest, 0, col, self.cursor - 1)
        end

        if v ~= "" then
            v = self.r:replace_variable(v, self.cursor - 1)
            v = vim.trim(v)

            if d == ":" then
                self.r.request.headers = self.r.request.headers or {}

                local val = self.r.request.headers[k]
                if val then
                    self.r:add_diag(WRN, "overwrite header key: " .. k, 0, #k, self.cursor - 1)
                end
                self.r.request.headers[k] = v
            else
                self.r.request.query = self.r.request.query or {}

                local val = self.r.request.query[k]
                if val then
                    self.r:add_diag(WRN, "overwrite query key: " .. k, 0, #k, self.cursor - 1)
                end
                self.r.request.query[k] = v
            end

            -- add meta for headers and query
            if not self.r.meta.headers_query.starts then
                self.r.meta.headers_query.starts = self.cursor - 1
                self.r.meta.headers_query.ends = self.cursor - 1
            else
                self.r.meta.headers_query.ends = self.cursor - 1
            end
        end
    end
    
    -- Если дошли сюда, значит больше строк нет
    return nil
end

M._file_path_buffer = ""

function M:_parse_body()
    -- Пропускаем пустые строки и комментарии
    local line = self:_skip_empty_and_comments()
    
    if not line then
        return nil
    end

    -- Check for script start - если следующая строка это скрипт, то тела нет
    if string.match(line, "^--{%%%s*$") or string.match(line, "^>%s{%%%s*$") then
        return line
    end

    -- Check if body is from a file (starts with <)
    local first_char = string.sub(line, 1, 1)
    if first_char == "<" then
        local fp = vim.trim(line:sub(2))
        if vim.loop.fs_stat(fp) then
            -- It's a file
            M._file_path_buffer = fp
            self.r.meta.body = { starts = self.cursor, ends = self.cursor, from_file = true }
            
            -- Replace variables in file path if needed
            fp = self.r:replace_variable(fp, self.cursor)
            self.r.request.body = fp
            self.cursor = self.cursor + 1
            return self:_skip_empty_and_comments()
        end
    end

    -- Тело запроса (может быть любым текстом)
    local body_start = self.cursor
    local body_end = body_start - 1  -- Начинаем с -1 чтобы корректно обработать случай без тела
    local has_content = false

    -- Собираем все строки тела до скрипта, комментария или пустой строки
    for i = self.cursor, self.len do
        line = self.lines[i]
        
        -- Проверяем начало скрипта
        if string.match(line, "^--{%%%s*$") or string.match(line, "^>%s{%%%s*$") then
            break
        end
        
        -- Останавливаемся на комментарии
        if string.match(line, "^#") then
            break
        end
        
        -- Пустая строка тоже останавливает парсинг тела
        if string.match(line, "^%s*$") then
            break
        end
        
        body_end = i
        has_content = true
    end

    -- Обрабатываем тело только если нашли контент
    if has_content and body_start <= body_end then
        -- Store body metadata
        self.r.meta.body = { starts = body_start, ends = body_end, from_file = false }
        
        -- Combine all body lines
        local body_lines = {}
        for i = body_start, body_end do
            table.insert(body_lines, self.lines[i])
        end
        
        local raw_body = table.concat(body_lines, "\n")
        
        -- Replace variables in the body
        local processed_body = self.r:replace_variable(raw_body, body_start)
        self.r.request.body = processed_body
        
        -- Check if it's JSON for validation (if enabled)
        local first_body_char = string.sub(self.lines[body_start], 1, 1)
        if first_body_char == "{" or first_body_char == "[" then
            self.r:check_json_body_if_enabled(body_start, body_end)
        end
        
        self.cursor = body_end + 1
        return self:_skip_empty_and_comments()
    end

    -- Если тела нет, возвращаем текущую строку
    return line
end

function M:_skip_empty_and_comments()
    while self.cursor <= self.len do
        local line = self.lines[self.cursor]
        local first_char = string.sub(line, 1, 1)
        
        if first_char == "" or first_char == "#" or line:match("^%s*$") then
            self.cursor = self.cursor + 1
        else
            return line
        end
    end
    return nil
end

function M:_parse_script()
    local line = self:_skip_empty_and_comments()
    
    if not line then
        return nil
    end

    -- ht: '--{%' and '--%}' or treesitter-http: '> {%' and  '%}'
    if string.match(line, "^--{%%%s*$") or string.match(line, "^>%s{%%%s*$") then
        local script_start_line = self.cursor
        self.cursor = self.cursor + 1
        local start = self.cursor
        local is_pre = false
        local is_post = false
        local post_start = start
        local end_pre = nil
        local pre_start = start

        -- Check if we have pre-script marker on the next line
        if start <= self.len then
            local next_line = self.lines[start]
            if next_line and string.match(next_line, "^[%s]*%-%-pre[%s]*$") then
                is_pre = true
                pre_start = start + 1  -- Skip the --pre line
            else
                is_post = true
            end
        end

        -- Поиск конца скрипта
        for i = start, self.len do
            line = self.lines[i]
            self.cursor = i

            -- Check for post-script marker
            if string.match(line, "^[%s]*%-%-post[%s]*$") then
                if is_pre then
                    end_pre = i - 1
                end
                post_start = i + 1  -- Skip the --post line
                is_post = true
            end

            -- Check for end of script
            if string.match(line, "^--%%}%s*$") or string.match(line, "^%%}%s*$") then
                -- Store pre-script if exists
                if is_pre and pre_start <= self.len then
                    local pre_end = end_pre or (i - 1)
                    if pre_start <= pre_end then
                        self.r.meta.pre_script = { starts = pre_start, ends = pre_end }
                        self.r.request.pre_script = table.concat(self.lines, "\n", pre_start, pre_end)
                    end
                end
                
                -- Store post-script if exists
                if is_post and post_start <= self.len then
                    local post_end = i - 1
                    if post_start <= post_end then
                        self.r.meta.script = { starts = post_start, ends = post_end }
                        self.r.request.script = table.concat(self.lines, "\n", post_start, post_end)
                    end
                end
                
                self.cursor = self.cursor + 1
                return self:_skip_empty_and_comments()
            end
        end

        self.r:add_diag(ERR, "missing end of script", 0, 0, script_start_line)
        return nil
    end

    return line
end

function M:_parse_after_last()
    for i = self.cursor, self.len do
        local line = self.lines[i]
        local first_char = string.sub(line, 1, 1)

        if first_char == "" or first_char == "#" or line:match("^%s") then
            -- do nothing, comment or empty line
        else
            self.cursor = i
            self.r:add_diag(
                ERR,
                "invalid input, this and the following lines are ignored",
                0,
                #line,
                self.cursor,
                self.len
            )
            return line
        end
    end

    self.cursor = self.len
    return nil
end

M.get_replace_variable_str = function(lines, row, col)
    local key = nil
    for s, k, e in string.gmatch(lines[row], "(){{(.-)}}()") do
        if s - 1 <= col and e - 1 > col then
            key = k
            break
        end
    end

    -- early return, if not replacement exist in the current line
    if not key then
        return nil
    end

    local r = M.parse(lines, row, { is_in_execute_mode = false })
    local value = r.variables[key]

    -- resolve environment and exec variables
    if not value then
        value = r:replace_variable_by_key(key)
    end

    if value then
        local lnum_str = ""
        -- environment or exec variables have no line number
        local lnum = r.meta.variables[key]
        if lnum then
            lnum_str = "[" .. lnum .. "] "
        end
        return lnum_str .. key .. " = " .. value, lnum
    else
        local isPrompt = string.sub(key, 1, 1) == ":"
        if isPrompt == true then
            return "prompt variables are not supported for a preview"
        end

        if key == "" then
            return "no key found"
        end
        return "no value found for key: " .. key
    end
end

return M
