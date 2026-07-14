local utils = require("utils")
local millennium = require("millennium")
local cjson_ok, cjson = false, nil
local fs_ok, fs = false, nil

local PLUGIN_ID = "skytools-plugin"
local BROWSER_JS = "public/skytools.js"
local BROWSER_CSS = "public/skytools.css"
local BROWSER_JS_WEBKIT = "webkit/skytools.js"
local BROWSER_CSS_WEBKIT = "webkit/skytools.css"
local BROWSER_JS_ROOT = "skytools.js"
local BROWSER_CSS_ROOT = "skytools.css"

local runtime = {
    browser_js_id = 0,
    browser_css_id = 0,
    steam_path = nil,
    last_injection = {},
    cache = {}
}

local function safe_backend_path()
    local ok, value = pcall(function()
        return utils.get_backend_path()
    end)
    if ok and value ~= nil and tostring(value) ~= "" then
        return tostring(value)
    end
    return "."
end

local function log_file_path()
    return safe_backend_path() .. "\\skytools-backend.log"
end

local function file_log(message)
    local ok = pcall(function()
        local file = io.open(log_file_path(), "a")
        if file ~= nil then
            file:write(os.date("%Y-%m-%d %H:%M:%S"), " ", tostring(message), "\n")
            file:close()
        end
    end)
    return ok
end

local function log_info(message)
    file_log(message)
end

local function log_error(message)
    file_log("ERROR " .. tostring(message))
end

local function join_path(left, right)
    local slash = "\\"
    left = tostring(left or "")
    if left:sub(-1) == slash then
        return left .. right
    end
    return left .. slash .. right
end

local function quote_arg(value)
    value = tostring(value or "")
    return '"' .. value:gsub('"', '""') .. '"'
end

local function sleep_ms(milliseconds)
    milliseconds = tonumber(milliseconds) or 0
    if utils ~= nil and utils.sleep ~= nil then
        pcall(utils.sleep, milliseconds)
        return
    end
    if millennium ~= nil and millennium.sleep ~= nil then
        pcall(millennium.sleep, milliseconds)
    end
end

local function backend_path()
    return safe_backend_path()
end

local function plugin_dir()
    local root = backend_path()
    local lowered = root:lower()
    if lowered:sub(-8) == "\\backend" or lowered:sub(-8) == "/backend" then
        return root:sub(1, #root - 8)
    end
    return join_path(root, "..")
end

local function worker_root()
    return join_path(plugin_dir(), "data")
end

local function installer_path()
    return join_path(backend_path(), "skytools_installer.js")
end

local function installed_helper_path()
    return join_path(backend_path(), "skytools_installed.js")
end

local function fixes_helper_path()
    return join_path(backend_path(), "skytools_fixes.js")
end

local function names_helper_path()
    return join_path(backend_path(), "skytools_names.js")
end

local function is_file(path)
    local file = io.open(path, "rb")
    if file ~= nil then
        file:close()
        return true
    end
    return false
end

local function parent_dir(path)
    local normalized = tostring(path or ""):gsub("/", "\\")
    return normalized:match("^(.*)\\[^\\]+$")
end

local function mkdirs(path)
    if path == nil or tostring(path) == "" then
        return false
    end

    if fs_ok and fs ~= nil and fs.exists ~= nil and fs.exists(path) then
        return true
    end

    if fs_ok and fs ~= nil and fs.create_directories ~= nil then
        local ok = pcall(fs.create_directories, path)
        return ok
    end

    return false
end

local function read_file(path)
    local file = io.open(path, "rb")
    if file == nil then
        return nil
    end
    local data = file:read("*a")
    file:close()
    return data
end

local function write_file(path, data)
    local parent = parent_dir(path)
    if parent ~= nil and parent ~= "" then
        mkdirs(parent)
    end

    local file = io.open(path, "wb")
    if file == nil then
        return false
    end
    file:write(data or "")
    file:close()
    return true
end

local function delete_file(path)
    pcall(function()
        os.remove(path)
    end)
end

local function copy_file(source, target)
    local data = read_file(source)
    if data == nil then
        log_error("Asset nao encontrado: " .. tostring(source))
        return false
    end

    local ok = write_file(target, data)
    if not ok then
        log_error("Falha ao copiar asset para: " .. tostring(target))
    end
    return ok
end

local function json_escape(value)
    value = tostring(value or "")
    value = value:gsub("\\", "\\\\")
    value = value:gsub('"', '\\"')
    value = value:gsub("\b", "\\b")
    value = value:gsub("\f", "\\f")
    value = value:gsub("\n", "\\n")
    value = value:gsub("\r", "\\r")
    value = value:gsub("\t", "\\t")
    return value
end

local function is_array(value)
    local count = 0
    local max_index = 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count = count + 1
        if key > max_index then
            max_index = key
        end
    end
    return max_index == count
end

local function json_encode_fallback(value, depth)
    depth = depth or 0
    if depth > 14 then
        return '"max depth"'
    end

    local kind = type(value)
    if kind == "nil" then
        return "null"
    end
    if kind == "boolean" then
        return value and "true" or "false"
    end
    if kind == "number" then
        return tostring(value)
    end
    if kind == "string" then
        return '"' .. json_escape(value) .. '"'
    end
    if kind ~= "table" then
        return '"' .. json_escape(value) .. '"'
    end

    local parts = {}
    if is_array(value) then
        for index = 1, #value do
            table.insert(parts, json_encode_fallback(value[index], depth + 1))
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    for key, item in pairs(value) do
        table.insert(parts, '"' .. json_escape(key) .. '":' .. json_encode_fallback(item, depth + 1))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function json_encode(value)
    if cjson_ok then
        local ok, encoded = pcall(cjson.encode, value or {})
        if ok then
            return encoded
        end
    end
    return json_encode_fallback(value or {})
end

local function json_call(callback)
    local ok, result = pcall(callback)
    if ok then
        return json_encode(result)
    end

    log_error(result)
    return json_encode({ success = false, error = tostring(result) })
end

local function detect_steam_path()
    if runtime.steam_path ~= nil and runtime.steam_path ~= "" then
        return runtime.steam_path
    end

    if millennium ~= nil and millennium.steam_path ~= nil then
        local ok, value = pcall(function()
            return millennium.steam_path()
        end)
        if ok and value ~= nil and tostring(value) ~= "" then
            runtime.steam_path = tostring(value)
            return runtime.steam_path
        end
    end

    local candidates = {
        "C:\\Program Files (x86)\\Steam",
        "C:\\Program Files\\Steam",
        "C:\\Steam"
    }
    for _, candidate in ipairs(candidates) do
        if is_file(join_path(candidate, "steam.exe")) then
            runtime.steam_path = candidate
            return candidate
        end
    end

    return ""
end

local function copy_public_assets()
    local steam_path = detect_steam_path()
    if steam_path == "" then
        runtime.last_injection.copy = { success = false, reason = "steam path not found" }
        log_error("Steam path nao encontrado; pulando injecao visual")
        return false
    end

    local public = join_path(plugin_dir(), "public")
    local steamui = join_path(steam_path, "steamui")
    local webkit = join_path(steamui, "webkit")
    local src_js = join_path(public, "skytools.js")
    local src_css = join_path(public, "skytools.css")
    local src_ico = join_path(public, "skytools_logo.ico")
    local src_png = join_path(public, "skytools_logo.png")
    local src_fa_solid = join_path(join_path(join_path(public, "fontawesome"), "webfonts"), "fa-solid-900.woff2")
    local js_webkit = copy_file(src_js, join_path(webkit, "skytools.js"))
    local css_webkit = copy_file(src_css, join_path(webkit, "skytools.css"))
    local ico_webkit = copy_file(src_ico, join_path(webkit, "skytools_logo.ico"))
    local png_webkit = copy_file(src_png, join_path(webkit, "skytools_logo.png"))
    local fa_solid_webkit = copy_file(src_fa_solid, join_path(join_path(join_path(webkit, "fontawesome"), "webfonts"), "fa-solid-900.woff2"))
    local js_root = copy_file(src_js, join_path(steamui, "skytools.js"))
    local css_root = copy_file(src_css, join_path(steamui, "skytools.css"))
    local ico_root = copy_file(src_ico, join_path(steamui, "skytools_logo.ico"))
    local png_root = copy_file(src_png, join_path(steamui, "skytools_logo.png"))
    local fa_solid_root = copy_file(src_fa_solid, join_path(join_path(join_path(steamui, "fontawesome"), "webfonts"), "fa-solid-900.woff2"))

    runtime.last_injection.copy = {
        success = js_webkit or js_root,
        steamPath = steam_path,
        jsWebkit = js_webkit,
        cssWebkit = css_webkit,
        icoWebkit = ico_webkit,
        pngWebkit = png_webkit,
        faSolidWebkit = fa_solid_webkit,
        jsRoot = js_root,
        cssRoot = css_root,
        icoRoot = ico_root,
        pngRoot = png_root,
        faSolidRoot = fa_solid_root
    }
    log_info("browser assets copied: jsWebkit=" .. tostring(js_webkit) .. ", cssWebkit=" .. tostring(css_webkit))
    return js_webkit or js_root
end

local function inject_browser_assets()
    if millennium.add_browser_css ~= nil then
        runtime.browser_css_id = millennium.add_browser_css(BROWSER_CSS)
        if runtime.browser_css_id == 0 then
            runtime.browser_css_id = millennium.add_browser_css(BROWSER_CSS_WEBKIT)
        end
        if runtime.browser_css_id == 0 then
            runtime.browser_css_id = millennium.add_browser_css(BROWSER_CSS_ROOT)
        end
    end

    if millennium.add_browser_js ~= nil then
        runtime.browser_js_id = millennium.add_browser_js(BROWSER_JS)
        if runtime.browser_js_id == 0 then
            runtime.browser_js_id = millennium.add_browser_js(BROWSER_JS_WEBKIT)
        end
        if runtime.browser_js_id == 0 then
            runtime.browser_js_id = millennium.add_browser_js(BROWSER_JS_ROOT)
        end
    end

    runtime.last_injection.inject = {
        success = runtime.browser_js_id ~= 0,
        jsModuleId = runtime.browser_js_id,
        cssModuleId = runtime.browser_css_id
    }
    log_info("browser modules injected: js=" .. tostring(runtime.browser_js_id) .. ", css=" .. tostring(runtime.browser_css_id))
end

local function data_root()
    local root = worker_root()
    mkdirs(root)
    return root
end

local function settings_path()
    return join_path(data_root(), "settings.json")
end

local function manifest_records_path()
    return join_path(data_root(), "manifest-installs.json")
end

local function name_cache_path()
    return join_path(data_root(), "skytools-app-name-cache.json")
end

local function history_path()
    return join_path(data_root(), "history.json")
end

local function launchers_dir()
    local dir = join_path(data_root(), "launchers")
    mkdirs(dir)
    return dir
end

local function launcher_path(name)
    return join_path(launchers_dir(), name)
end

local function ensure_launcher(name, content)
    local path = launcher_path(name)
    if read_file(path) ~= content then
        write_file(path, content)
    end
    return path
end

local function json_decode_fallback(text)
    text = tostring(text or "")
    local index = 1

    local function skip_ws()
        while true do
            local char = text:sub(index, index)
            if char == " " or char == "\n" or char == "\r" or char == "\t" then
                index = index + 1
            else
                break
            end
        end
    end

    local parse_value

    local function parse_string()
        if text:sub(index, index) ~= '"' then
            error("expected string")
        end
        index = index + 1
        local parts = {}
        while index <= #text do
            local char = text:sub(index, index)
            if char == '"' then
                index = index + 1
                return table.concat(parts)
            end
            if char == "\\" then
                local escaped = text:sub(index + 1, index + 1)
                if escaped == '"' or escaped == "\\" or escaped == "/" then
                    table.insert(parts, escaped)
                    index = index + 2
                elseif escaped == "b" then
                    table.insert(parts, "\b")
                    index = index + 2
                elseif escaped == "f" then
                    table.insert(parts, "\f")
                    index = index + 2
                elseif escaped == "n" then
                    table.insert(parts, "\n")
                    index = index + 2
                elseif escaped == "r" then
                    table.insert(parts, "\r")
                    index = index + 2
                elseif escaped == "t" then
                    table.insert(parts, "\t")
                    index = index + 2
                elseif escaped == "u" then
                    local hex = text:sub(index + 2, index + 5)
                    local code = tonumber(hex, 16)
                    if code ~= nil and code < 128 then
                        table.insert(parts, string.char(code))
                    else
                        table.insert(parts, "?")
                    end
                    index = index + 6
                else
                    table.insert(parts, escaped)
                    index = index + 2
                end
            else
                table.insert(parts, char)
                index = index + 1
            end
        end
        error("unterminated string")
    end

    local function parse_number()
        local start = index
        local char = text:sub(index, index)
        while char:match("[%d%+%-%e%E%.]") ~= nil do
            index = index + 1
            char = text:sub(index, index)
        end
        return tonumber(text:sub(start, index - 1))
    end

    local function parse_array()
        local result = {}
        index = index + 1
        skip_ws()
        if text:sub(index, index) == "]" then
            index = index + 1
            return result
        end
        while true do
            table.insert(result, parse_value())
            skip_ws()
            local char = text:sub(index, index)
            if char == "]" then
                index = index + 1
                return result
            end
            if char ~= "," then
                error("expected comma in array")
            end
            index = index + 1
        end
    end

    local function parse_object()
        local result = {}
        index = index + 1
        skip_ws()
        if text:sub(index, index) == "}" then
            index = index + 1
            return result
        end
        while true do
            skip_ws()
            local key = parse_string()
            skip_ws()
            if text:sub(index, index) ~= ":" then
                error("expected colon")
            end
            index = index + 1
            result[key] = parse_value()
            skip_ws()
            local char = text:sub(index, index)
            if char == "}" then
                index = index + 1
                return result
            end
            if char ~= "," then
                error("expected comma in object")
            end
            index = index + 1
        end
    end

    function parse_value()
        skip_ws()
        local char = text:sub(index, index)
        if char == '"' then return parse_string() end
        if char == "{" then return parse_object() end
        if char == "[" then return parse_array() end
        if text:sub(index, index + 3) == "true" then
            index = index + 4
            return true
        end
        if text:sub(index, index + 4) == "false" then
            index = index + 5
            return false
        end
        if text:sub(index, index + 3) == "null" then
            index = index + 4
            return nil
        end
        return parse_number()
    end

    local ok, value = pcall(parse_value)
    if ok then
        return value
    end
    return nil
end

local function json_decode(text, fallback)
    if text == nil or tostring(text) == "" then
        return fallback
    end
    text = tostring(text):gsub("^\239\187\191", "")
    if cjson_ok then
        local ok, decoded = pcall(cjson.decode, text)
        if ok and decoded ~= nil then
            return decoded
        end
    end
    local decoded = json_decode_fallback(text)
    if decoded ~= nil then
        return decoded
    end
    return fallback
end

local function read_json(path, fallback)
    return json_decode(read_file(path), fallback)
end

local function write_json(path, value)
    return write_file(path, json_encode(value))
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function get_prop(source, upper, lower, fallback)
    if type(source) ~= "table" then
        return fallback
    end
    if source[upper] ~= nil then
        return source[upper]
    end
    if source[lower] ~= nil then
        return source[lower]
    end
    return fallback
end

local function get_first_prop(source, keys, fallback)
    if type(source) ~= "table" then
        return fallback
    end
    for _, key in ipairs(keys or {}) do
        if source[key] ~= nil then
            return source[key]
        end
    end
    return fallback
end

local function normalize_payload(payload)
    if payload == nil then
        return {}
    end
    if type(payload) == "number" then
        return { appid = payload }
    end
    if type(payload) == "string" then
        local text = trim(payload)
        if text == "" then
            return {}
        end
        if text:sub(1, 1) == "{" or text:sub(1, 1) == "[" then
            local decoded = json_decode(text, nil)
            if type(decoded) == "table" then
                return normalize_payload(decoded)
            end
        end
        if text:match("^%d+$") ~= nil then
            return { appid = tonumber(text) }
        end
        return { query = text, name = text }
    end
    if type(payload) ~= "table" then
        return {}
    end

    if type(payload.payload) == "table" or type(payload.payload) == "string" then
        return normalize_payload(payload.payload)
    end
    if type(payload.data) == "table" or type(payload.data) == "string" then
        return normalize_payload(payload.data)
    end
    if type(payload[1]) == "table" or type(payload[1]) == "string" or type(payload[1]) == "number" then
        local nested = normalize_payload(payload[1])
        if next(nested) ~= nil then
            return nested
        end
    end
    return payload
end

local function payload_appid(payload)
    payload = normalize_payload(payload)
    local value = get_prop(payload, "appid", "appId", nil)
    if value == nil then
        value = get_prop(payload, "AppId", "id", nil)
    end
    if type(value) == "table" then
        value = get_prop(value, "appid", "appId", nil)
    end
    value = tostring(value or ""):match("(%d+)")
    return tonumber(value or "0") or 0
end

local function cache_get(key, ttl_seconds)
    local item = runtime.cache[key]
    if item ~= nil and item.expires_at ~= nil and os.time() < item.expires_at then
        return item.value
    end
    return nil
end

local function cache_set(key, value, ttl_seconds)
    runtime.cache[key] = {
        value = value,
        expires_at = os.time() + (ttl_seconds or 10)
    }
    return value
end

local function cache_clear()
    runtime.cache = {}
end

local function load_settings()
    local settings = read_json(settings_path(), {})
    if type(settings) ~= "table" then
        settings = {}
    end
    return settings
end

local function active_script_directory()
    local steam_path = detect_steam_path()
    if steam_path == "" then
        return ""
    end

    local settings = load_settings()
    local integration = trim(get_prop(settings, "IntegrationTool", "integrationTool", "SkyTools")):lower()
    local custom = trim(get_prop(settings, "CustomScriptDirectory", "customScriptDirectory", ""))
    if integration == "customfolder" and custom ~= "" then
        return custom
    end
    if integration == "opensteamtool" then
        return join_path(join_path(steam_path, "config"), "lua")
    end
    return join_path(join_path(steam_path, "config"), "stplug-in")
end

local function script_directories()
    local steam_path = detect_steam_path()
    local dirs = {}
    local seen = {}

    local function add_dir(path)
        path = trim(path)
        if path ~= "" then
            local key = path:lower()
            if seen[key] ~= true then
                seen[key] = true
                table.insert(dirs, path)
            end
        end
    end

    if steam_path ~= "" then
        add_dir(join_path(join_path(steam_path, "config"), "stplug-in"))
        add_dir(join_path(join_path(steam_path, "config"), "lua"))
    end

    local settings = load_settings()
    add_dir(get_prop(settings, "CustomScriptDirectory", "customScriptDirectory", ""))
    add_dir(active_script_directory())

    return dirs
end

local function list_script_files(script_dir)
    -- Avoid LuaFileSystem in the Millennium backend process: on some builds it can
    -- crash the plugin host with 0xC0000005 while iterating Steam folders.
    return {}
end

local function jobs_dir()
    local dir = join_path(data_root(), "jobs")
    mkdirs(dir)
    return dir
end

local function job_result_path(name)
    return join_path(jobs_dir(), tostring(name or "job") .. ".json")
end

local function run_hidden_command(command, wait_for_exit)
    local command_path = launcher_path("run-hidden-command.txt")
    if not write_file(command_path, tostring(command or "")) then
        return false
    end

    local vbs_path = ensure_launcher("run-hidden.vbs", table.concat({
        'Set fso = CreateObject("Scripting.FileSystemObject")',
        'Set sh = CreateObject("WScript.Shell")',
        'cmd = ""',
        'waitForExit = False',
        'If WScript.Arguments.Count > 0 Then',
        '  commandPath = WScript.Arguments.Item(0)',
        '  If fso.FileExists(commandPath) Then',
        '    Set file = fso.OpenTextFile(commandPath, 1, False)',
        '    cmd = file.ReadAll',
        '    file.Close',
        '    cmd = Replace(cmd, vbCr, "")',
        '    cmd = Replace(cmd, vbLf, "")',
        '  End If',
        'End If',
        'If WScript.Arguments.Count > 1 Then waitForExit = (LCase(WScript.Arguments.Item(1)) = "true")',
        'If cmd <> "" Then sh.Run cmd, 0, waitForExit'
    }, "\r\n"))

    return pcall(function()
        return utils.exec("wscript.exe //B //Nologo " .. quote_arg(vbs_path) .. " " .. quote_arg(command_path) .. " " .. quote_arg(wait_for_exit and "true" or "false"))
    end)
end

local function scan_installed_with_helper(directories)
    local helper = installed_helper_path()
    if not is_file(helper) then
        return nil
    end

    local result_path = job_result_path("installed")
    delete_file(result_path)

    local command = {
        "wscript.exe",
        "//B",
        "//Nologo",
        quote_arg(helper),
        quote_arg(result_path)
    }
    for _, directory in ipairs(directories or {}) do
        if trim(directory) ~= "" then
            table.insert(command, quote_arg(directory))
        end
    end

    local ok = run_hidden_command(table.concat(command, " "), false)
    if not ok then
        return nil
    end

    local waited = 0
    while waited < 10000 and not is_file(result_path) do
        sleep_ms(250)
        waited = waited + 250
    end

    if not is_file(result_path) then
        return nil
    end

    local result = read_json(result_path, nil)
    if type(result) == "table" and result.success == true then
        local data = get_prop(result, "data", "scripts", {})
        if type(data) == "table" then
            return data
        end
    end
    return nil
end

local function load_name_cache()
    local cached = read_json(name_cache_path(), {})
    if type(cached) ~= "table" then
        return {}
    end
    return cached
end

local function name_cache_map()
    local map = {}
    local cache = load_name_cache()
    for key, item in pairs(cache) do
        if type(item) == "string" then
            if trim(item) ~= "" then
                map[tostring(key)] = trim(item)
            end
        elseif type(item) == "table" then
            local appid = get_prop(item, "AppId", "appId", key)
            local name = get_prop(item, "Name", "name", "")
            if appid ~= nil and trim(name) ~= "" then
                map[tostring(appid)] = trim(name)
            end
        end
    end
    return map
end

local function save_name_cache_map(map)
    local cache = {}
    for appid, name in pairs(map or {}) do
        if trim(name) ~= "" then
            cache[tostring(appid)] = {
                AppId = tonumber(appid) or appid,
                Name = trim(name)
            }
        end
    end
    write_json(name_cache_path(), cache)
end

local function count_map_values(map)
    local count = 0
    if type(map) ~= "table" then
        return 0
    end
    for _, _ in pairs(map) do
        count = count + 1
    end
    return count
end

local function resolve_missing_names(appids, names)
    local helper = names_helper_path()
    if not is_file(helper) then
        return names
    end
    local missing = {}
    local seen = {}
    for _, appid in ipairs(appids or {}) do
        local key = tostring(appid)
        if key ~= "" and seen[key] ~= true and trim(names[key]) == "" then
            seen[key] = true
            table.insert(missing, key)
        end
    end
    if #missing == 0 then
        return names
    end

    local result_path = job_result_path("names")
    delete_file(result_path)

    local command = {
        "wscript.exe",
        "//B",
        "//Nologo",
        quote_arg(helper),
        quote_arg(result_path)
    }
    for _, appid in ipairs(missing) do
        table.insert(command, quote_arg(appid))
    end

    local ok = run_hidden_command(table.concat(command, " "), false)
    if not ok then
        return names
    end

    local waited = 0
    while waited < 15000 and not is_file(result_path) do
        sleep_ms(250)
        waited = waited + 250
    end

    local result = read_json(result_path, nil)
    if type(result) == "table" and result.success == true then
        local data = get_prop(result, "data", "names", {})
        if type(data) == "table" then
            for appid, name in pairs(data) do
                if trim(name) ~= "" then
                    names[tostring(appid)] = trim(name)
                end
            end
            save_name_cache_map(names)
        end
    end
    return names
end

local function is_placeholder_game_name(name, appid)
    local value = trim(name)
    local id = tostring(appid or "")
    if value == "" then
        return true
    end
    if id ~= "" and value == id then
        return true
    end
    if id ~= "" and value:lower() == ("appid " .. id):lower() then
        return true
    end
    if value:lower():match("^appid%s+%d+$") ~= nil then
        return true
    end
    return false
end

local function resolve_game_name_for_appid(appid, candidate)
    if not is_placeholder_game_name(candidate, appid) then
        return trim(candidate)
    end

    local id = tostring(appid or "")
    local names = name_cache_map()
    if trim(names[id]) ~= "" then
        return trim(names[id])
    end

    names = resolve_missing_names({ id }, names)
    if trim(names[id]) ~= "" then
        return trim(names[id])
    end

    return "AppID " .. id
end

local function load_manifest_records()
    local records = read_json(manifest_records_path(), {})
    if type(records) ~= "table" then
        return {}
    end
    return records
end

local function save_manifest_records(records)
    write_json(manifest_records_path(), records or {})
end

local function installed_direct()
    log_info("SkyToolsInstalled iniciado")
    local cached = cache_get("installed", 8)
    if cached ~= nil then
        log_info("SkyToolsInstalled usando cache: " .. tostring(#cached))
        return cached
    end

    local directories = script_directories()
    local scripts = scan_installed_with_helper(directories) or {}
    log_info("SkyToolsInstalled scan retornou: " .. tostring(#scripts))

    table.sort(scripts, function(left, right)
        return (tonumber(left.appId or left.appid or 0) or 0) < (tonumber(right.appId or right.appid or 0) or 0)
    end)
    local records = load_manifest_records()
    local names = name_cache_map()
    local record_names = {}

    for _, record in pairs(records) do
        if type(record) == "table" then
            local appid = get_prop(record, "AppId", "appId", nil)
            local game_name = get_prop(record, "GameName", "gameName", "")
            if appid ~= nil and trim(game_name) ~= "" and not is_placeholder_game_name(game_name, appid) then
                record_names[tostring(appid)] = trim(game_name)
            end
        end
    end

    local missing_appids = {}
    for _, script in ipairs(scripts) do
        local id = tostring(script.appId or script.appid or "")
        if id ~= "" and trim(record_names[id] or names[id] or "") == "" then
            table.insert(missing_appids, id)
        end
    end
    names = resolve_missing_names(missing_appids, names)

    for _, script in ipairs(scripts) do
        script.appId = tonumber(script.appId or script.appid or 0) or 0
        script.appid = script.appId
        local id = tostring(script.appId)
        script.gameName = record_names[id] or names[id] or ""
        script.name = script.gameName
        script.dlcCount = tonumber(script.dlcCount or script.DlcCount or script.dlc_count or 0) or 0
        script.imageUrl = "https://cdn.akamai.steamstatic.com/steam/apps/" .. id .. "/header.jpg"
        script.hasDenuvo = false
        script.hasAvailableFix = false
        script.hasAppliedFix = false
        script.isSteamInstalled = false
        script.metadataLoaded = false
        script.metadataLoading = false
    end

    return cache_set("installed", scripts, 8)
end

local function cached_installed_count()
    local cached = cache_get("installed", 8)
    if type(cached) == "table" then
        return #cached
    end

    local seen = {}
    local count = 0
    for _, record in pairs(load_manifest_records()) do
        if type(record) == "table" then
            local appid = tostring(get_prop(record, "AppId", "appId", ""))
            if appid ~= "" and seen[appid] ~= true then
                seen[appid] = true
                count = count + 1
            end
        end
    end
    return count
end

local function status_direct(payload)
    local settings = load_settings()
    return {
        steamPath = detect_steam_path(),
        scriptDirectory = active_script_directory(),
        dataPath = data_root(),
        appNameCachePath = name_cache_path(),
        appNameCacheCount = count_map_values(name_cache_map()),
        integration = trim(get_prop(settings, "IntegrationTool", "integrationTool", "SkyTools")),
        configuredIntegration = trim(get_prop(settings, "IntegrationTool", "integrationTool", "SkyTools")),
        installedCount = cached_installed_count(),
        preferredApi = trim(get_prop(settings, "PreferredDownloadApi", "preferredDownloadApi", "Automatic")),
        apiOrderCount = count_map_values(get_prop(settings, "ApiOrder", "apiOrder", {})),
        hasMorrenusKey = trim(get_prop(settings, "MorrenusApiKey", "morrenusApiKey", "")) ~= "",
        pluginId = get_prop(payload, "pluginId", "pluginId", PLUGIN_ID),
        injection = runtime.last_injection,
        browserJsId = runtime.browser_js_id,
        browserCssId = runtime.browser_css_id,
        backendMode = "lua-inline-wsh-installer"
    }
end

local function apis_direct()
    local settings = load_settings()
    local custom = get_prop(settings, "CustomManifestApis", "customManifestApis", {})
    local api_order = get_prop(settings, "ApiOrder", "apiOrder", {})
    local disabled_api_ids = get_prop(settings, "DisabledApiIds", "disabledApiIds", {})
    local native_api_keys = get_prop(settings, "NativeApiKeys", "nativeApiKeys", {})
    if type(custom) ~= "table" then
        custom = {}
    end
    if type(api_order) ~= "table" then
        api_order = {}
    end
    if type(disabled_api_ids) ~= "table" then
        disabled_api_ids = {}
    end
    if type(native_api_keys) ~= "table" then
        native_api_keys = {}
    end
    local disabled = {}
    for _, id in ipairs(disabled_api_ids) do
        disabled[tostring(id):lower()] = true
    end
    return {
        preferred = trim(get_prop(settings, "PreferredDownloadApi", "preferredDownloadApi", "Automatic")),
        morrenusApiKey = trim(get_prop(settings, "MorrenusApiKey", "morrenusApiKey", "")),
        apiOrder = api_order,
        builtIn = {
            { id = "morrenus", name = "Morrenus", editable = false, native = true, enabled = disabled.morrenus ~= true, requiresKey = true, apiKey = trim(get_prop(settings, "MorrenusApiKey", "morrenusApiKey", "")), urlTemplate = "https://hubcapmanifest.com/api/v1/manifest/<appid>?api_key=<moapikey>" },
            { id = "sushi", name = "Sushi", editable = false, native = true, enabled = disabled.sushi ~= true, requiresKey = false, apiKey = trim(native_api_keys.sushi or ""), urlTemplate = "https://raw.githubusercontent.com/sushi-dev55-alt/sushitools-games-repo-alt/refs/heads/main/<appid>.zip" },
            { id = "skyapi", name = "SkyAPI", editable = false, native = true, enabled = disabled.skyapi ~= true, requiresKey = false, apiKey = trim(native_api_keys.skyapi or ""), urlTemplate = "https://raw.githubusercontent.com/skyflarefox/Skyapi/refs/heads/main/<appid>.zip" }
        },
        custom = custom
    }
end

local function remove_game_direct(payload)
    payload = normalize_payload(payload)
    local appid = payload_appid(payload)
    if appid == nil or appid <= 0 then
        return { success = false, error = "AppID invalido." }
    end

    local steam_path = detect_steam_path()
    if steam_path == "" then
        return { success = false, error = "Steam nao encontrada." }
    end

    local dirs = {
        join_path(join_path(steam_path, "config"), "stplug-in"),
        join_path(join_path(steam_path, "config"), "lua"),
        active_script_directory()
    }
    for _, dir in ipairs(dirs) do
        if dir ~= nil and dir ~= "" then
            delete_file(join_path(dir, tostring(appid) .. ".lua"))
            delete_file(join_path(dir, tostring(appid) .. ".lua.disabled"))
        end
    end

    local kept = {}
    for _, record in pairs(load_manifest_records()) do
        if type(record) ~= "table" or tonumber(get_prop(record, "AppId", "appId", 0)) ~= appid then
            table.insert(kept, record)
        end
    end
    save_manifest_records(kept)
    cache_clear()
    return { appId = appid, removed = true }
end

local function save_api_direct(payload)
    local settings = load_settings()
    local custom = get_prop(settings, "CustomManifestApis", "customManifestApis", {})
    if type(custom) ~= "table" then
        custom = {}
    end

    local api = {
        id = trim(get_prop(payload, "id", "Id", "")),
        native = get_prop(payload, "native", "Native", false) == true,
        name = trim(get_prop(payload, "name", "Name", "")),
        urlTemplate = trim(get_prop(payload, "urlTemplate", "UrlTemplate", "")),
        apiKey = trim(get_prop(payload, "apiKey", "ApiKey", "")),
        useProxy = get_prop(payload, "useProxy", "UseProxy", false) == true,
        proxyUrlTemplate = trim(get_prop(payload, "proxyUrlTemplate", "ProxyUrlTemplate", "")),
        successCode = tonumber(get_prop(payload, "successCode", "SuccessCode", 200)) or 200,
        unavailableCode = tonumber(get_prop(payload, "unavailableCode", "UnavailableCode", 404)) or 404,
        enabled = get_prop(payload, "enabled", "Enabled", true) ~= false
    }

    local native_ids = { morrenus = true, sushi = true, skyapi = true }
    if native_ids[api.id:lower()] == true then
        local disabled_api_ids = get_prop(settings, "DisabledApiIds", "disabledApiIds", {})
        local native_api_keys = get_prop(settings, "NativeApiKeys", "nativeApiKeys", {})
        if type(disabled_api_ids) ~= "table" then
            disabled_api_ids = {}
        end
        if type(native_api_keys) ~= "table" then
            native_api_keys = {}
        end

        local kept_disabled = {}
        for _, item in ipairs(disabled_api_ids) do
            if tostring(item):lower() ~= api.id:lower() then
                table.insert(kept_disabled, item)
            end
        end
        if api.enabled == false then
            table.insert(kept_disabled, api.id)
        end
        settings.DisabledApiIds = kept_disabled

        native_api_keys[api.id] = api.apiKey
        settings.NativeApiKeys = native_api_keys
        if api.id:lower() == "morrenus" then
            settings.MorrenusApiKey = api.apiKey
        end
        write_json(settings_path(), settings)
        cache_clear()
        return { id = api.id, name = api.name, native = true, enabled = api.enabled }
    end
    end

    if api.name == "" then
        return { success = false, error = "Informe um nome para a API." }
    end
    if api.urlTemplate == "" or api.urlTemplate:find("<appid>", 1, true) == nil then
        return { success = false, error = "A URL da API precisa conter <appid>." }
    end
    if api.id == "" then
        api.id = "skytools-" .. tostring(os.time())
    end

    local replaced = false
    for index, item in ipairs(custom) do
        if type(item) == "table" and trim(get_prop(item, "id", "Id", "")) == api.id then
            custom[index] = api
            replaced = true
        end
    end
    if not replaced then
        table.insert(custom, api)
    end

    settings.CustomManifestApis = custom
    local api_order = get_prop(settings, "ApiOrder", "apiOrder", {})
    if type(api_order) ~= "table" then
        api_order = {}
    end
    local found_in_order = false
    for _, item in ipairs(api_order) do
        if tostring(item):lower() == api.id:lower() then
            found_in_order = true
        end
    end
    if not found_in_order then
        table.insert(api_order, api.id)
        settings.ApiOrder = api_order
    end
    write_json(settings_path(), settings)
    cache_clear()
    return api
end

local function save_api_settings_direct(payload)
    local settings = load_settings()
    local preferred = trim(get_first_prop(payload, { "preferred", "preferredApi", "PreferredDownloadApi" }, "Automatic"))
    local morrenus_key = trim(get_prop(payload, "morrenusApiKey", "MorrenusApiKey", ""))
    local api_order = get_prop(payload, "apiOrder", "ApiOrder", nil)
    if type(api_order) == "table" then
        local clean_order = {}
        local seen = {}
        for _, item in ipairs(api_order) do
            local id = trim(item)
            local key = id:lower()
            if id ~= "" and seen[key] ~= true then
                seen[key] = true
                table.insert(clean_order, id)
            end
        end
        settings.ApiOrder = clean_order
    end
    if preferred ~= "" then
        settings.PreferredDownloadApi = preferred
    end
    if morrenus_key ~= "" then
        settings.MorrenusApiKey = morrenus_key
    end
    write_json(settings_path(), settings)
    cache_clear()
    return apis_direct()
end

local function delete_api_direct(payload)
    local id = trim(get_prop(payload, "id", "Id", ""))
    local settings = load_settings()
    local lower_id = id:lower()
    if lower_id == "morrenus" or lower_id == "sushi" or lower_id == "skyapi" then
        local disabled_api_ids = get_prop(settings, "DisabledApiIds", "disabledApiIds", {})
        if type(disabled_api_ids) ~= "table" then
            disabled_api_ids = {}
        end
        local exists = false
        for _, item in ipairs(disabled_api_ids) do
            if tostring(item):lower() == lower_id then
                exists = true
            end
        end
        if not exists then
            table.insert(disabled_api_ids, id)
        end
        settings.DisabledApiIds = disabled_api_ids
        write_json(settings_path(), settings)
        cache_clear()
        return { id = id, disabled = true }
    end

    local custom = get_prop(settings, "CustomManifestApis", "customManifestApis", {})
    local kept = {}
    local removed_name = ""
    if type(custom) == "table" then
        for _, item in ipairs(custom) do
            if type(item) ~= "table" or trim(get_prop(item, "id", "Id", "")) ~= id then
                table.insert(kept, item)
            else
                removed_name = trim(get_prop(item, "name", "Name", ""))
            end
        end
    end
    settings.CustomManifestApis = kept
    local api_order = get_prop(settings, "ApiOrder", "apiOrder", {})
    if type(api_order) == "table" then
        local kept_order = {}
        for _, item in ipairs(api_order) do
            if tostring(item):lower() ~= id:lower() then
                table.insert(kept_order, item)
            end
        end
        settings.ApiOrder = kept_order
    end
    local preferred = trim(get_prop(settings, "PreferredDownloadApi", "preferredDownloadApi", "Automatic"))
    if preferred:lower() == id:lower() or (removed_name ~= "" and preferred:lower() == removed_name:lower()) then
        settings.PreferredDownloadApi = "Automatic"
    end
    write_json(settings_path(), settings)
    cache_clear()
    return { id = id, removed = true }
end

local run_wscript_installer

local function backup_export_direct(payload)
    local out = trim(get_prop(payload, "path", "Path", ""))
    if out == "" then
        out = join_path(data_root(), "skytools-library-" .. tostring(os.time()) .. ".json")
    end
    local games = {}
    for _, game in ipairs(installed_direct()) do
        table.insert(games, { appId = game.appId, name = game.gameName or "" })
    end
    write_json(out, { version = 1, createdAt = os.date("%Y-%m-%dT%H:%M:%S"), games = games })
    return { path = out }
end

local function backup_restore_direct(payload)
    payload = normalize_payload(payload)
    local backup = get_prop(payload, "backup", "Backup", payload)
    local games = get_prop(backup, "games", "Games", {})
    if type(games) ~= "table" then
        return { success = false, error = "Backup invalido." }
    end

    local installed = {}
    for _, game in ipairs(installed_direct()) do
        installed[tostring(game.appId or game.appid or "")] = true
    end

    local restored = 0
    local skipped = 0
    local failed = 0
    local results = {}
    for _, item in ipairs(games) do
        if type(item) == "table" then
            local appid = tonumber(get_first_prop(item, { "appId", "appid", "AppId", "id" }, 0)) or 0
            local name = trim(get_first_prop(item, { "name", "gameName", "GameName", "Name" }, ""))
            local key = tostring(appid)
            if appid > 0 then
                if installed[key] == true then
                    skipped = skipped + 1
                    table.insert(results, { appId = appid, name = name, status = "skipped" })
                else
                    local result = run_wscript_installer({ appid = appid, name = name })
                    if type(result) == "table" and result.success ~= false then
                        restored = restored + 1
                        installed[key] = true
                        table.insert(results, { appId = appid, name = name, status = "restored" })
                    else
                        failed = failed + 1
                        table.insert(results, { appId = appid, name = name, status = "failed", error = get_prop(result or {}, "error", "Error", "Falha ao restaurar.") })
                    end
                end
            end
        end
    end

    cache_clear()
    return {
        restored = restored,
        skipped = skipped,
        failed = failed,
        total = #games,
        results = results,
        message = "Restauracao concluida."
    }
end

local function integration_direct(payload)
    local settings = load_settings()
    settings.IntegrationTool = trim(get_prop(payload, "target", "integration", "SkyTools"))
    write_json(settings_path(), settings)
    mkdirs(active_script_directory())
    cache_clear()
    return { integration = settings.IntegrationTool }
end

function run_wscript_installer(payload)
    payload = normalize_payload(payload)
    local appid = payload_appid(payload)
    if appid == nil or appid <= 0 then
        return { success = false, error = "AppID invalido.", details = "Payload recebido: " .. json_encode(payload) }
    end

    local installer = installer_path()
    if not is_file(installer) then
        return { success = false, error = "Instalador interno nao encontrado: " .. installer }
    end

    local steam_path = detect_steam_path()
    if steam_path == "" then
        return { success = false, error = "Steam nao encontrada." }
    end

    local settings = load_settings()
    local root = data_root()

    local app_name = resolve_game_name_for_appid(appid, get_prop(payload, "name", "gameName", ""))

    local result_path = job_result_path("add-" .. tostring(appid))
    delete_file(result_path)

    local preferred = trim(get_prop(settings, "PreferredDownloadApi", "preferredDownloadApi", "Automatic"))
    if preferred == "" then
        preferred = "Automatic"
    end
    local morrenus_key = trim(get_prop(settings, "MorrenusApiKey", "morrenusApiKey", ""))
    local morrenus_arg = morrenus_key
    if morrenus_arg == "" then
        morrenus_arg = "-"
    end

    local command = table.concat({
        "wscript.exe",
        "//B",
        "//Nologo",
        quote_arg(installer),
        quote_arg(root),
        quote_arg(steam_path),
        quote_arg(active_script_directory()),
        quote_arg(tostring(appid)),
        quote_arg(app_name),
        quote_arg(preferred),
        quote_arg(morrenus_arg),
        quote_arg(result_path)
    }, " ")

    log_info("SkyTools installer iniciado para appid=" .. tostring(appid))
    local ok = run_hidden_command(command, false)
    local exec_result = ""
    if not ok then
        return {
            success = false,
            error = "Nao foi possivel iniciar o instalador interno oculto. Verifique se o Windows Script Host esta habilitado."
        }
    end

    local waited = 0
    while waited < 180000 and not is_file(result_path) do
        sleep_ms(500)
        waited = waited + 500
    end

    if not is_file(result_path) then
        return {
            success = false,
            error = "O instalador interno nao respondeu a tempo.",
            details = tostring(exec_result or "")
        }
    end

    local result = read_json(result_path, nil)
    if type(result) ~= "table" then
        local preview = read_file(result_path) or ""
        return {
            success = false,
            error = "Resposta invalida do instalador interno.",
            details = preview:sub(1, 500)
        }
    end
    cache_clear()
    return result
end

local function ps_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

local function repair_script_path(kind)
    local dir = join_path(data_root(), "repairs")
    mkdirs(dir)
    return join_path(dir, "repair-" .. tostring(kind or "task") .. "-" .. tostring(os.time()) .. ".ps1")
end

local function launch_elevated_powershell(script_path)
    local vbs_path = ensure_launcher("run-elevated-powershell.vbs", table.concat({
        'Set app = CreateObject("Shell.Application")',
        'scriptPath = ""',
        'If WScript.Arguments.Count > 0 Then scriptPath = WScript.Arguments.Item(0)',
        'If scriptPath <> "" Then',
        '  args = "-NoProfile -ExecutionPolicy Bypass -File " & Chr(34) & scriptPath & Chr(34)',
        '  app.ShellExecute "powershell.exe", args, "", "runas", 0',
        'End If'
    }, "\r\n"))
    local ok = run_hidden_command("wscript.exe //B //Nologo " .. quote_arg(vbs_path) .. " " .. quote_arg(script_path), false)
    return ok
end

local function run_powershell_script(script_path)
    return run_hidden_command("powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File " .. quote_arg(script_path), false)
end

local function run_repair_direct(payload)
    payload = normalize_payload(payload)
    local repair = trim(get_prop(payload, "repair", "kind", "")):lower()
    local appid = payload_appid(payload)
    local steam_path = detect_steam_path()
    local script = ""
    local elevated = false
    local message = "Reparo iniciado."

    if repair == "dns" then
        elevated = true
        script = [[
$ErrorActionPreference = 'Stop'
Get-WmiObject -Class Win32_IP4RouteTable |
  Where-Object { $_.destination -eq '0.0.0.0' -and $_.mask -eq '0.0.0.0' } |
  Sort-Object metric1 |
  Select-Object -First 1 |
  Select-Object -ExpandProperty interfaceindex |
  Set-DnsClientServerAddress -ServerAddresses ('1.1.1.1', '1.0.0.1')
]]
        message = "DNS Cloudflare iniciado. Confirme a permissao do Windows se aparecer."
    elseif repair == "error54" then
        if steam_path == "" then
            return { success = false, error = "Steam nao encontrada." }
        end
        local appcache = join_path(steam_path, "appcache")
        script = "$ErrorActionPreference = 'SilentlyContinue'\r\n" ..
            "Get-Process steam | Stop-Process -Force\r\n" ..
            "Start-Sleep -Seconds 2\r\n" ..
            "$cache = " .. ps_quote(appcache) .. "\r\n" ..
            "$files = @('appinfo.vdf','packageinfo.vdf','packcode.vdf','version')\r\n" ..
            "foreach ($file in $files) { $p = Join-Path $cache $file; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force } }\r\n" ..
            "Start-Process -FilePath " .. ps_quote(join_path(steam_path, "steam.exe")) .. " -ArgumentList '-clearbeta'\r\n"
        message = "Cache da Steam limpo e Steam reiniciada."
    elseif repair == "vcredist" or repair == "vcredist2022" or repair == "visualcpp" then
        elevated = true
        local download_dir = join_path(data_root(), "downloads")
        mkdirs(download_dir)
        local exe_path = join_path(download_dir, "VisualCppRedist_AIO_x86_x64.exe")
        script = "$ErrorActionPreference = 'Stop'\r\n" ..
            "$file = " .. ps_quote(exe_path) .. "\r\n" ..
            "Invoke-WebRequest 'https://github.com/abbodi1406/vcredist/releases/latest/download/VisualCppRedist_AIO_x86_x64.exe' -OutFile $file\r\n" ..
            "Start-Process -FilePath $file -ArgumentList '/ai /gm2' -Wait\r\n"
        message = "Instalador Visual C++ iniciado. Confirme a permissao do Windows se aparecer."
    else
        return { success = false, error = "Reparo desconhecido: " .. tostring(repair) }
    end

    local path = repair_script_path(repair)
    write_file(path, script)
    local ok = elevated and launch_elevated_powershell(path) or run_powershell_script(path)
    if not ok then
        return { success = false, error = "Nao foi possivel iniciar o reparo externo." }
    end
    return { success = true, data = { repair = repair, scriptPath = path, elevated = elevated, message = message }, error = "" }
end

local function find_fix_sources_direct(payload)
    payload = normalize_payload(payload)
    local appid = tostring(payload_appid(payload))
    local name = trim(get_prop(payload, "name", "gameName", appid))
    local sources = {}

    local helper = fixes_helper_path()
    if is_file(helper) then
        local result_path = job_result_path("fixes-" .. appid)
        delete_file(result_path)
        local command = table.concat({
            "wscript.exe",
            "//B",
            "//Nologo",
            quote_arg(helper),
            quote_arg(result_path),
            quote_arg(appid),
            quote_arg(name)
        }, " ")
        run_hidden_command(command, false)
        local waited = 0
        while waited < 15000 and not is_file(result_path) do
            sleep_ms(250)
            waited = waited + 250
        end
        local result = read_json(result_path, nil)
        if type(result) == "table" and result.success == true then
            local data = get_prop(result, "data", "Data", {})
            local found = get_prop(data, "sources", "Sources", {})
            if type(found) == "table" then
                sources = found
            end
        end
    end

    if #sources == 0 then
        table.insert(sources, {
            name = "Pesquisar no Ryuu",
            type = "Busca manual",
            provider = "Ryuu",
            downloadUrl = "https://generator.ryuu.lol/fixes",
            size = ""
        })
        table.insert(sources, {
            name = "Pesquisar no Online-Fix",
            type = "Busca manual",
            provider = "Online-Fix",
            downloadUrl = "https://online-fix.me/index.php?do=search&subaction=search&story=" .. name,
            size = ""
        })
    end

    return {
        gamePath = "",
        sources = sources
    }
end

local function simple_fix_sources(payload, kind)
    payload = normalize_payload(payload)
    local appid = tostring(get_prop(payload, "appid", "appId", ""))
    local name = trim(get_prop(payload, "name", "gameName", appid))
    if kind == "online" then
        return {
            {
                title = "Pesquisar no Online-Fix",
                provider = "Online-Fix",
                url = "https://online-fix.me/index.php?do=search&subaction=search&story=" .. name
            }
        }
    end
    if kind == "denuvo" then
        return {
            {
                title = "Pesquisar correcoes Denuvo",
                provider = "Ryuu/GitHub",
                sourceUrl = "https://github.com/search?q=" .. name .. "%20denuvo%20fix"
            }
        }
    end
    return { gamePath = "", sources = {} }
end

local function apply_fix_direct(payload)
    payload = normalize_payload(payload)
    local appid = tostring(get_prop(payload, "appid", "appId", ""))
    local name = trim(get_prop(payload, "name", "gameName", appid))
    local source = get_prop(payload, "source", "sourceJson", {})
    if type(source) == "string" then
        source = json_decode(source, {})
    end
    if type(source) ~= "table" then
        source = {}
    end

    local url = trim(get_first_prop(source, { "downloadUrl", "sourceUrl", "url" }, ""))
    if url == "" then
        return { success = false, error = "Fonte sem link para abrir." }
    end

    local records_path = join_path(data_root(), "fix-actions.json")
    local records = read_json(records_path, {})
    if type(records) ~= "table" then
        records = {}
    end
    table.insert(records, {
        appId = tonumber(appid) or appid,
        name = name,
        source = source,
        url = url,
        createdAt = os.date("%Y-%m-%dT%H:%M:%S")
    })
    write_json(records_path, records)

    return {
        appId = tonumber(appid) or appid,
        name = name,
        url = url,
        message = "Fonte preparada. Abra o link e siga as instrucoes da pagina."
    }
end

local function dispatch_inline(method, payload)
    payload = payload or {}
    if method == "status" then return { success = true, data = status_direct(payload), error = "" } end
    if method == "installed" then return { success = true, data = installed_direct(), error = "" } end
    if method == "name-cache" then
        local cache = load_name_cache()
        return { success = true, data = { path = name_cache_path(), games = cache, count = count_map_values(cache) }, error = "" }
    end
    if method == "apis" then return { success = true, data = apis_direct(), error = "" } end
    if method == "save-api" then
        local result = save_api_direct(payload)
        if result.success == false then return result end
        return { success = true, data = result, error = "" }
    end
    if method == "save-api-settings" then return { success = true, data = save_api_settings_direct(payload), error = "" } end
    if method == "delete-api" then return { success = true, data = delete_api_direct(payload), error = "" } end
    if method == "remove-game" then
        local result = remove_game_direct(payload)
        if result.success == false then return result end
        return { success = true, data = result, error = "" }
    end
    if method == "backup-export" then return { success = true, data = backup_export_direct(payload), error = "" } end
    if method == "backup-restore" then
        local result = backup_restore_direct(payload)
        if result.success == false then return result end
        return { success = true, data = result, error = "" }
    end
    if method == "fix-sources" then return { success = true, data = find_fix_sources_direct(payload), error = "" } end
    if method == "online-fix" then return { success = true, data = simple_fix_sources(payload, "online"), error = "" } end
    if method == "denuvo-fix" then return { success = true, data = simple_fix_sources(payload, "denuvo"), error = "" } end
    if method == "repair" then return run_repair_direct(payload) end
    if method == "apply-fix" then
        local result = apply_fix_direct(payload)
        if result.success == false then return result end
        return { success = true, data = result, error = "" }
    end
    if method == "integration" then return { success = true, data = integration_direct(payload), error = "" } end
    if method == "add-game" then return run_wscript_installer(payload) end
    return { success = false, error = "Metodo desconhecido: " .. tostring(method) }
end

local function worker_call(method, payload, timeout_seconds)
    return json_call(function()
        return dispatch_inline(method, normalize_payload(payload or {}))
    end)
end

Logger = {}
function Logger.log(payload)
    if type(payload) == "table" then
        payload = payload.message
    end
    log_info(payload or "")
    return json_encode({ success = true })
end
_G["Logger.log"] = Logger.log

function SkyToolsStatus()
    return worker_call("status", {
        pluginId = PLUGIN_ID,
        injection = runtime.last_injection,
        browserJsId = runtime.browser_js_id,
        browserCssId = runtime.browser_css_id,
        steamPath = detect_steam_path()
    }, 30)
end

function SkyToolsInstalled()
    return worker_call("installed", {}, 60)
end

function SkyToolsNameCache()
    return worker_call("name-cache", {}, 30)
end

function SkyToolsApis()
    return worker_call("apis", {}, 30)
end

function SkyToolsSaveApi(payload)
    return worker_call("save-api", payload or {}, 30)
end

function SkyToolsSaveApiSettings(payload)
    return worker_call("save-api-settings", payload or {}, 30)
end

function SkyToolsDeleteApi(payload)
    return worker_call("delete-api", payload or {}, 30)
end

function SkyToolsAddGame(payload)
    return worker_call("add-game", payload or {}, 180)
end

function SkyToolsRemoveGame(payload)
    return worker_call("remove-game", payload or {}, 60)
end

function SkyToolsBackupExport(payload)
    return worker_call("backup-export", payload or {}, 60)
end

function SkyToolsBackupRestore(payload)
    return worker_call("backup-restore", payload or {}, 120)
end

function SkyToolsFixSources(payload)
    return worker_call("fix-sources", payload or {}, 60)
end

function SkyToolsOnlineFix(payload)
    return worker_call("online-fix", payload or {}, 60)
end

function SkyToolsDenuvoFix(payload)
    return worker_call("denuvo-fix", payload or {}, 60)
end

function SkyToolsApplyFix(payload)
    return worker_call("apply-fix", payload or {}, 60)
end

function SkyToolsRepair(payload)
    return worker_call("repair", payload or {}, 90)
end

function SkyToolsIntegration(payload)
    return worker_call("integration", payload or {}, 60)
end

function SkyToolsInjectionStatus()
    return json_encode({
        success = true,
        copy = runtime.last_injection.copy or {},
        inject = runtime.last_injection.inject or {},
        steamPath = detect_steam_path(),
        pluginDir = plugin_dir(),
        dataPath = data_root(),
        backendMode = "lua-inline-wsh-installer",
        browserJsId = runtime.browser_js_id,
        browserCssId = runtime.browser_css_id
    })
end

function skytools_status()
    return SkyToolsStatus()
end
_G["skytools_status"] = skytools_status

function skytools_installed()
    return SkyToolsInstalled()
end
_G["skytools_installed"] = skytools_installed

function skytools_apis()
    return SkyToolsApis()
end
_G["skytools_apis"] = skytools_apis

function skytools_add_game(params, name)
    if type(params) == "table" then
        return SkyToolsAddGame(params)
    end
    return SkyToolsAddGame({ appid = params, name = name })
end
_G["skytools_add_game"] = skytools_add_game

function skytools_remove_game(params, name)
    if type(params) == "table" then
        return SkyToolsRemoveGame(params)
    end
    return SkyToolsRemoveGame({ appid = params, name = name })
end
_G["skytools_remove_game"] = skytools_remove_game

function skytools_save_api(api)
    return SkyToolsSaveApi(api or {})
end
_G["skytools_save_api"] = skytools_save_api

function skytools_save_api_settings(params)
    return SkyToolsSaveApiSettings(params or {})
end
_G["skytools_save_api_settings"] = skytools_save_api_settings

function skytools_delete_api(params)
    if type(params) == "table" then
        return SkyToolsDeleteApi(params)
    end
    return SkyToolsDeleteApi({ id = params })
end
_G["skytools_delete_api"] = skytools_delete_api

function skytools_backup_export(params)
    if type(params) == "table" then
        return SkyToolsBackupExport(params)
    end
    return SkyToolsBackupExport({ path = params })
end
_G["skytools_backup_export"] = skytools_backup_export

function skytools_fix_sources(params, name)
    if type(params) == "table" then
        return SkyToolsFixSources(params)
    end
    return SkyToolsFixSources({ appid = params, name = name })
end
_G["skytools_fix_sources"] = skytools_fix_sources

function skytools_apply_fix(params, name, game_path, source)
    if type(params) == "table" then
        return SkyToolsApplyFix(params)
    end
    return SkyToolsApplyFix({ appid = params, name = name, gamePath = game_path, source = source or {} })
end
_G["skytools_apply_fix"] = skytools_apply_fix

function skytools_online_fix(params, name)
    if type(params) == "table" then
        return SkyToolsOnlineFix(params)
    end
    return SkyToolsOnlineFix({ appid = params, name = name })
end
_G["skytools_online_fix"] = skytools_online_fix

function skytools_denuvo_fix(params, name)
    if type(params) == "table" then
        return SkyToolsDenuvoFix(params)
    end
    return SkyToolsDenuvoFix({ appid = params, name = name })
end
_G["skytools_denuvo_fix"] = skytools_denuvo_fix

function skytools_repair(params, appid)
    if type(params) == "table" then
        return SkyToolsRepair(params)
    end
    return SkyToolsRepair({ repair = params, appid = appid })
end
_G["skytools_repair"] = skytools_repair

function skytools_integration(params)
    if type(params) == "table" then
        return SkyToolsIntegration(params)
    end
    return SkyToolsIntegration({ target = params })
end
_G["skytools_integration"] = skytools_integration

local function on_load()
    pcall(function()
        millennium.ready()
    end)
end

local function on_unload()
    if millennium.remove_browser_module ~= nil then
        if runtime.browser_js_id ~= nil and runtime.browser_js_id ~= 0 then
            pcall(millennium.remove_browser_module, runtime.browser_js_id)
        end
        if runtime.browser_css_id ~= nil and runtime.browser_css_id ~= 0 then
            pcall(millennium.remove_browser_module, runtime.browser_css_id)
        end
    end
end

local function on_frontend_loaded()
end

return {
    on_load = on_load,
    on_unload = on_unload,
    on_frontend_loaded = on_frontend_loaded
}
