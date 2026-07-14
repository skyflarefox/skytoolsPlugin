local utils = require("utils")
local millennium = require("millennium")
local cjson_ok, cjson = false, nil
local fs_ok, fs = false, nil

cjson_ok, cjson = pcall(require, "json")
if not cjson_ok then
    cjson_ok, cjson = pcall(require, "cjson")
end
if not cjson_ok then
    cjson_ok, cjson = pcall(require, "dkjson")
end

fs_ok, fs = pcall(require, "fs")

local PLUGIN_ID = "skytools-plugin"
local BROWSER_JS = "public/skytools.js"
local BROWSER_CSS = "public/skytools.css"
local BROWSER_JS_WEBKIT = "webkit/SkyTools/skytools.js"
local BROWSER_CSS_WEBKIT = "webkit/SkyTools/skytools.css"
local DEFAULT_API_ORDER = { "skyapi", "morrenus", "sushi" }

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

local function steam_installed_helper_path()
    return join_path(backend_path(), "skytools_steam_installed.js")
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

local function path_exists(path)
    path = tostring(path or ""):match("^%s*(.-)%s*$") or ""
    if path == "" then
        return false
    end
    if fs_ok and fs ~= nil and fs.exists ~= nil then
        local ok, exists = pcall(fs.exists, path)
        if ok then
            return exists == true
        end
    end
    if fs_ok and fs ~= nil and fs.list ~= nil then
        local ok, entries = pcall(fs.list, path)
        if ok and type(entries) == "table" then
            return true
        end
    end
    if is_file(path) then
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
        if ok then
            return true
        end
    end

    local command = "cmd.exe /c mkdir " .. quote_arg(path) .. " >nul 2>nul"
    local ok = pcall(function()
        if utils ~= nil and utils.exec ~= nil then
            return utils.exec(command)
        end
        return os.execute(command)
    end)
    if ok then
        return true
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

local function sync_file_if_different(source, target)
    local source_data = read_file(source)
    if source_data == nil then
        log_error("Arquivo de origem nao encontrado: " .. tostring(source))
        return false
    end
    local target_data = read_file(target)
    if target_data == source_data then
        return true
    end
    return write_file(target, source_data)
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

local function url_encode(value)
    value = tostring(value or ""):gsub("\r", " "):gsub("\n", " ")
    value = value:gsub("([^%w%-%_%.%~ ])", function(char)
        return string.format("%%%02X", string.byte(char))
    end)
    return value:gsub(" ", "+")
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
    local public = join_path(plugin_dir(), "public")
    local webkit = join_path(plugin_dir(), "webkit")
    local webkit_skytools = join_path(webkit, "SkyTools")
    local steam_path = detect_steam_path()
    local src_js = join_path(public, "skytools.js")
    local src_css = join_path(public, "skytools.css")
    local src_ico = join_path(public, "skytools_logo.ico")
    local src_png = join_path(public, "skytools_logo.png")
    local src_fa_solid = join_path(join_path(join_path(public, "fontawesome"), "webfonts"), "fa-solid-900.woff2")
    local js_webkit = copy_file(src_js, join_path(webkit_skytools, "skytools.js"))
    local css_webkit = copy_file(src_css, join_path(webkit_skytools, "skytools.css"))
    local ico_webkit = copy_file(src_ico, join_path(webkit_skytools, "skytools_logo.ico"))
    local png_webkit = copy_file(src_png, join_path(webkit_skytools, "skytools_logo.png"))
    local fa_solid_webkit = copy_file(src_fa_solid, join_path(join_path(join_path(webkit_skytools, "fontawesome"), "webfonts"), "fa-solid-900.woff2"))
    local js_steamui_webkit = false
    local css_steamui_webkit = false
    local png_steamui_webkit = false
    local ico_steamui_webkit = false
    local fa_steamui_webkit = false

    if steam_path ~= "" then
        local steamui = join_path(steam_path, "steamui")
        local steamui_webkit = join_path(join_path(steamui, "webkit"), "SkyTools")
        delete_file(join_path(steamui, "skytools.js"))
        delete_file(join_path(steamui, "skytools.css"))
        delete_file(join_path(steamui, "skytools_logo.ico"))
        delete_file(join_path(steamui, "skytools_logo.png"))
        delete_file(join_path(join_path(steamui, "webkit"), "skytools.js"))
        delete_file(join_path(join_path(steamui, "webkit"), "skytools.css"))
        delete_file(join_path(join_path(steamui, "webkit"), "skytools_logo.ico"))
        delete_file(join_path(join_path(steamui, "webkit"), "skytools_logo.png"))
        js_steamui_webkit = sync_file_if_different(src_js, join_path(steamui_webkit, "skytools.js"))
        css_steamui_webkit = sync_file_if_different(src_css, join_path(steamui_webkit, "skytools.css"))
        ico_steamui_webkit = sync_file_if_different(src_ico, join_path(steamui_webkit, "skytools_logo.ico"))
        png_steamui_webkit = sync_file_if_different(src_png, join_path(steamui_webkit, "skytools_logo.png"))
        fa_steamui_webkit = sync_file_if_different(src_fa_solid, join_path(join_path(join_path(steamui_webkit, "fontawesome"), "webfonts"), "fa-solid-900.woff2"))
    end

    runtime.last_injection.copy = {
        success = js_webkit,
        jsWebkit = js_webkit,
        cssWebkit = css_webkit,
        icoWebkit = ico_webkit,
        pngWebkit = png_webkit,
        faSolidWebkit = fa_solid_webkit,
        jsSteamUiWebkit = js_steamui_webkit,
        cssSteamUiWebkit = css_steamui_webkit,
        icoSteamUiWebkit = ico_steamui_webkit,
        pngSteamUiWebkit = png_steamui_webkit,
        faSteamUiWebkit = fa_steamui_webkit
    }
    log_info("browser assets synced: jsWebkit=" .. tostring(js_webkit) .. ", jsSteamUiWebkit=" .. tostring(js_steamui_webkit))
    return js_webkit
end

local function inject_browser_assets()
    if millennium.add_browser_css ~= nil then
        local ok, id = pcall(millennium.add_browser_css, BROWSER_CSS)
        if ok and id ~= nil then
            runtime.browser_css_id = id
        end
        if runtime.browser_css_id == 0 or runtime.browser_css_id == -1 then
            ok, id = pcall(millennium.add_browser_css, BROWSER_CSS_WEBKIT)
            if ok and id ~= nil then
                runtime.browser_css_id = id
            end
        end
    end

    if millennium.add_browser_js ~= nil then
        local ok, id = pcall(millennium.add_browser_js, BROWSER_JS)
        if ok and id ~= nil then
            runtime.browser_js_id = id
        end
        if runtime.browser_js_id == 0 or runtime.browser_js_id == -1 then
            ok, id = pcall(millennium.add_browser_js, BROWSER_JS_WEBKIT)
            if ok and id ~= nil then
                runtime.browser_js_id = id
            end
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

local function installed_index_path()
    return join_path(data_root(), "skytools-job-installed.json")
end

local function history_path()
    return join_path(data_root(), "history.json")
end

local function launchers_dir()
    return data_root()
end

local function launcher_path(name)
    return join_path(launchers_dir(), "skytools-" .. tostring(name or "launcher"))
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

local function get_prop(source, ...)
    local count = select("#", ...)
    local fallback = nil
    if count > 0 then
        fallback = select(count, ...)
    end
    if type(source) ~= "table" then
        return fallback
    end
    for index = 1, count - 1 do
        local key = select(index, ...)
        if key ~= nil and source[key] ~= nil then
            return source[key]
        end
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
    for _, key in ipairs(keys or {}) do
        local wanted = tostring(key or ""):lower()
        if wanted ~= "" then
            for actual, value in pairs(source) do
                if tostring(actual or ""):lower() == wanted then
                    return value
                end
            end
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
    if type(payload.params) == "table" or type(payload.params) == "string" then
        return normalize_payload(payload.params)
    end
    if type(payload.args) == "table" or type(payload.args) == "string" then
        return normalize_payload(payload.args)
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

local function steam_library_paths()
    local steam_path = detect_steam_path()
    local libraries = {}
    local seen = {}
    local function add(path)
        path = trim(path)
        if path == "" then
            return
        end
        local steamapps = join_path(path, "steamapps")
        local key = steamapps:lower()
        if seen[key] ~= true then
            seen[key] = true
            table.insert(libraries, steamapps)
        end
    end

    if steam_path ~= "" then
        add(steam_path)
        local text = read_file(join_path(join_path(steam_path, "steamapps"), "libraryfolders.vdf")) or read_file(join_path(join_path(steam_path, "config"), "libraryfolders.vdf")) or ""
        for path in text:gmatch('"path"%s+"([^"]+)"') do
            add(path:gsub("\\\\", "\\"))
        end
    end
    return libraries
end

local function steam_game_metadata(appid)
    appid = tostring(appid or ""):match("(%d+)") or ""
    if appid == "" then
        return nil
    end
    for _, steamapps in ipairs(steam_library_paths()) do
        local manifest = join_path(steamapps, "appmanifest_" .. appid .. ".acf")
        local text = read_file(manifest)
        if text ~= nil then
            local function value(key)
                local found = text:match('"' .. tostring(key or "") .. '"%s+"([^"]*)"')
                return found ~= nil and found:gsub("\\\\", "\\") or ""
            end
            local manifest_appid = value("appid")
            local installdir = value("installdir")
            local name = value("name")
            local game_path = ""
            if trim(installdir) ~= "" then
                game_path = join_path(join_path(steamapps, "common"), installdir)
            end
            return {
                appId = tonumber(manifest_appid ~= "" and manifest_appid or appid) or appid,
                name = trim(name),
                gameName = trim(name),
                manifestPath = manifest,
                fullPath = manifest,
                installDir = installdir,
                gamePath = game_path,
                installPath = game_path,
                steamapps = steamapps
            }
        end
    end
    return nil
end

local function steam_game_install_path(appid)
    local metadata = steam_game_metadata(appid)
    return metadata ~= nil and trim(metadata.gamePath) or ""
end

local function acf_value(text, key)
    local pattern = '"' .. tostring(key or "") .. '"%s+"([^"]*)"'
    local value = tostring(text or ""):match(pattern)
    if value == nil then
        return ""
    end
    return value:gsub("\\\\", "\\")
end

local function list_manifest_files(steamapps)
    local files = {}
    local directory = trim(steamapps)
    if directory == "" or not fs_ok or fs == nil or fs.list == nil then
        return files
    end

    local ok, entries = pcall(fs.list, directory)
    if not ok or type(entries) ~= "table" then
        return files
    end

    for _, entry in ipairs(entries) do
        local name = ""
        local path = ""
        if type(entry) == "table" then
            name = trim(entry.name or entry.filename or "")
            path = trim(entry.path or entry.fullPath or "")
        else
            path = trim(entry)
            name = path:match("[^\\/]+$") or path
        end
        if name == "" and path ~= "" then
            name = path:match("[^\\/]+$") or ""
        end
        if name:match("^appmanifest_%d+%.acf$") ~= nil then
            table.insert(files, path ~= "" and path or join_path(directory, name))
        end
    end
    return files
end

local function scan_steam_installed_with_helper(libraries)
    local helper = steam_installed_helper_path()
    if not is_file(helper) then
        return nil
    end

    local result_path = join_path(data_root(), "skytools-job-steam-installed.json")
    delete_file(result_path)

    local command = {
        "cscript.exe",
        "//Nologo",
        quote_arg(helper),
        quote_arg(result_path)
    }
    for _, steamapps in ipairs(libraries or {}) do
        if trim(steamapps) ~= "" then
            table.insert(command, quote_arg(steamapps))
        end
    end

    local ok = pcall(function()
        if utils ~= nil and utils.exec ~= nil then
            return utils.exec(table.concat(command, " "))
        end
        return os.execute(table.concat(command, " "))
    end)
    if not ok or not is_file(result_path) then
        return nil
    end

    local result = read_json(result_path, nil)
    if type(result) == "table" and result.success == true then
        local data = get_prop(result, "data", "games", {})
        if type(data) == "table" then
            return data
        end
    end
    return nil
end

local function steam_installed_direct()
    local cached = cache_get("steam-installed", 10)
    if cached ~= nil then
        return cached
    end

    local records = read_json(join_path(data_root(), "fix-actions.json"), {})
    local applied = {}
    if type(records) == "table" then
        for _, record in pairs(records) do
            if type(record) == "table" then
                local appid = tostring(get_prop(record, "appId", "appid", "AppId", ""))
                if appid ~= "" then
                    applied[appid] = true
                end
            end
        end
    end

    local libraries = steam_library_paths()
    local items = {}
    local seen = {}
    local helper_items = scan_steam_installed_with_helper(libraries)
    if type(helper_items) == "table" then
        for _, item in ipairs(helper_items) do
            if type(item) == "table" then
                local appid = tostring(get_prop(item, "appId", "appid", "AppId", ""))
                if appid ~= "" and seen[appid] ~= true then
                    seen[appid] = true
                    item.hasAppliedFix = applied[appid] == true
                    table.insert(items, item)
                end
            end
        end
    end

    if #items == 0 then
        for _, steamapps in ipairs(libraries) do
            for _, manifest in ipairs(list_manifest_files(steamapps)) do
                local text = read_file(manifest)
                if text ~= nil then
                    local appid = manifest:match("appmanifest_(%d+)%.acf$") or acf_value(text, "appid")
                    local name = acf_value(text, "name")
                    local installdir = acf_value(text, "installdir")
                    if appid ~= "" and installdir ~= "" and seen[appid] ~= true then
                        local game_path = join_path(join_path(steamapps, "common"), installdir)
                        if path_exists(game_path) then
                            seen[appid] = true
                            table.insert(items, {
                                appId = tonumber(appid) or appid,
                                appid = tonumber(appid) or appid,
                                gameName = trim(name) ~= "" and trim(name) or ("AppID " .. appid),
                                name = trim(name) ~= "" and trim(name) or ("AppID " .. appid),
                                fileName = "appmanifest_" .. appid .. ".acf",
                                fullPath = manifest,
                                manifestPath = manifest,
                                gamePath = game_path,
                                installPath = game_path,
                                isDisabled = false,
                                isSteamInstalled = true,
                                hasAppliedFix = applied[appid] == true,
                                imageUrl = "https://cdn.akamai.steamstatic.com/steam/apps/" .. appid .. "/header.jpg"
                            })
                        end
                    end
                end
            end
        end
    end

    table.sort(items, function(left, right)
        return trim(left.gameName):lower() < trim(right.gameName):lower()
    end)
    return cache_set("steam-installed", items, 10)
end

local function count_dlcs_from_script(path, appid)
    local text = read_file(path)
    if text == nil then
        return 0
    end
    local root_appid = tostring(appid or "")
    local seen = {}
    local count = 0
    for id in text:gmatch("addappid%s*%(%s*(%d+)") do
        id = tostring(id or "")
        if id ~= "" and id ~= root_appid and seen[id] ~= true then
            seen[id] = true
            count = count + 1
        end
    end
    return count
end

local function list_script_files(script_dir)
    local items = {}
    local directory = trim(script_dir)
    if directory == "" or not fs_ok or fs == nil or fs.list == nil then
        return items
    end

    local ok, entries = pcall(fs.list, directory)
    if not ok or type(entries) ~= "table" then
        return items
    end

    for _, entry in ipairs(entries) do
        local name = ""
        local path = ""
        if type(entry) == "table" then
            name = trim(entry.name or entry.filename or "")
            path = trim(entry.path or entry.fullPath or "")
        else
            path = trim(entry)
            name = path:match("[^\\/]+$") or path
        end
        if name == "" and path ~= "" then
            name = path:match("[^\\/]+$") or ""
        end

        local appid = name:match("^(%d+)%.lua%.disabled$") or name:match("^(%d+)%.lua$")
        if appid ~= nil then
            local full_path = path ~= "" and path or join_path(directory, name)
            table.insert(items, {
                appId = tonumber(appid) or 0,
                appid = tonumber(appid) or 0,
                fileName = name,
                fullPath = full_path,
                scriptDirectory = directory,
                dlcCount = count_dlcs_from_script(full_path, appid),
                isDisabled = name:match("%.disabled$") ~= nil
            })
        end
    end

    return items
end

local function jobs_dir()
    return data_root()
end

local function job_result_path(name)
    return join_path(jobs_dir(), "skytools-job-" .. tostring(name or "job") .. ".json")
end

local function run_minimized_command(command, wait_for_exit)
    local start_flags = wait_for_exit and "/wait /min" or "/min"
    local launch_command = "cmd.exe /c start \"SkyTools\" " .. start_flags .. " " .. tostring(command or "")
    local ok = pcall(function()
        return utils.exec(launch_command)
    end)
    if not ok then
        log_error("Falha ao iniciar comando minimizado.")
    end
    return ok
end

local function scan_installed_with_helper(directories)
    local helper = installed_helper_path()
    if not is_file(helper) then
        return nil
    end

    local result_path = job_result_path("installed")
    delete_file(result_path)

    local command = {
        "cscript.exe",
        "//Nologo",
        quote_arg(helper),
        quote_arg(result_path)
    }
    for _, directory in ipairs(directories or {}) do
        if trim(directory) ~= "" then
            table.insert(command, quote_arg(directory))
        end
    end

    local ok = run_minimized_command(table.concat(command, " "), false)
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
        "cscript.exe",
        "//Nologo",
        quote_arg(helper),
        quote_arg(result_path)
    }
    for _, appid in ipairs(missing) do
        table.insert(command, quote_arg(appid))
    end

    local ok = run_minimized_command(table.concat(command, " "), false)
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

local function normalize_installed_item(item)
    if type(item) ~= "table" then
        return nil
    end
    local appid = tonumber(get_prop(item, "appId", "appid", "AppId", 0)) or 0
    if appid <= 0 then
        return nil
    end
    local full_path = trim(get_prop(item, "fullPath", "FullPath", "scriptPath", "ScriptPath", ""))
    local script_dir = trim(get_prop(item, "scriptDirectory", "ScriptDirectory", ""))
    if script_dir == "" and full_path ~= "" then
        script_dir = parent_dir(full_path) or ""
    end
    if full_path == "" and script_dir ~= "" then
        full_path = join_path(script_dir, tostring(appid) .. ".lua")
    end
    local file_name = trim(get_prop(item, "fileName", "FileName", ""))
    if file_name == "" then
        file_name = tostring(appid) .. ".lua"
    end
    return {
        appId = appid,
        appid = appid,
        fileName = file_name,
        fullPath = full_path,
        scriptDirectory = script_dir,
        dlcCount = tonumber(get_prop(item, "dlcCount", "DlcCount", "dlc_count", 0)) or 0,
        isDisabled = get_prop(item, "isDisabled", "IsDisabled", false) == true
    }
end

local function load_installed_index()
    local raw = read_json(installed_index_path(), nil)
    local data = nil
    if type(raw) == "table" and type(raw.data) == "table" then
        data = raw.data
    elseif type(raw) == "table" then
        data = raw
    end
    if type(data) ~= "table" then
        return {}
    end

    local items = {}
    local seen = {}
    for _, item in pairs(data) do
        local normalized = normalize_installed_item(item)
        if normalized ~= nil then
            local key = tostring(normalized.appId)
            if seen[key] ~= true then
                seen[key] = true
                table.insert(items, normalized)
            end
        end
    end
    return items
end

local function installed_items_from_name_cache()
    local items = {}
    local names = name_cache_map()
    for appid, _ in pairs(names) do
        local numeric = tonumber(appid) or 0
        if numeric > 0 then
            local script_path = join_path(active_script_directory(), tostring(numeric) .. ".lua")
            table.insert(items, {
                appId = numeric,
                appid = numeric,
                fileName = tostring(numeric) .. ".lua",
                fullPath = script_path,
                scriptDirectory = active_script_directory(),
                dlcCount = count_dlcs_from_script(script_path, numeric),
                isDisabled = false
            })
        end
    end
    table.sort(items, function(left, right)
        return (tonumber(left.appId or 0) or 0) < (tonumber(right.appId or 0) or 0)
    end)
    return items
end

local function save_installed_index(items)
    write_json(installed_index_path(), {
        success = true,
        data = items or {},
        error = ""
    })
end

local function merge_manifest_records_into_index(items)
    local by_id = {}
    local merged = {}
    for _, item in ipairs(items or {}) do
        local normalized = normalize_installed_item(item)
        if normalized ~= nil then
            local key = tostring(normalized.appId)
            by_id[key] = normalized
            table.insert(merged, normalized)
        end
    end

    for _, record in pairs(load_manifest_records()) do
        if type(record) == "table" then
            local appid = tonumber(get_prop(record, "AppId", "appId", 0)) or 0
            if appid > 0 and by_id[tostring(appid)] == nil then
                local script_path = trim(get_prop(record, "ScriptPath", "scriptPath", ""))
                if script_path == "" then
                    script_path = join_path(active_script_directory(), tostring(appid) .. ".lua")
                end
                local item = normalize_installed_item({
                    appId = appid,
                    fullPath = script_path,
                    scriptDirectory = parent_dir(script_path) or active_script_directory(),
                    dlcCount = count_dlcs_from_script(script_path, appid),
                    isDisabled = false
                })
                if item ~= nil then
                    by_id[tostring(appid)] = item
                    table.insert(merged, item)
                end
            end
        end
    end

    return merged
end

local function update_installed_index_entry(appid, patch)
    appid = tonumber(appid) or 0
    if appid <= 0 then
        return
    end
    local items = load_installed_index()
    local updated = false
    for index, item in ipairs(items) do
        if tonumber(item.appId or item.appid or 0) == appid then
            for key, value in pairs(patch or {}) do
                item[key] = value
            end
            item.appId = appid
            item.appid = appid
            items[index] = normalize_installed_item(item) or item
            updated = true
            break
        end
    end
    if updated ~= true then
        local item = patch or {}
        item.appId = appid
        item.appid = appid
        table.insert(items, normalize_installed_item(item) or item)
    end
    save_installed_index(items)
end

local function remove_installed_index_entry(appid)
    appid = tonumber(appid) or 0
    if appid <= 0 then
        return
    end
    local kept = {}
    for _, item in ipairs(load_installed_index()) do
        if tonumber(item.appId or item.appid or 0) ~= appid then
            table.insert(kept, item)
        end
    end
    save_installed_index(kept)
end

local function installed_direct()
    log_info("SkyToolsInstalled iniciado")
    local cached = cache_get("installed", 8)
    if cached ~= nil then
        log_info("SkyToolsInstalled usando cache: " .. tostring(#cached))
        return cached
    end

    local index_items = {}
    local by_id = {}
    for _, directory in ipairs(script_directories()) do
        for _, item in ipairs(list_script_files(directory)) do
            local key = tostring(item.appId or item.appid or "")
            if key ~= "" and (by_id[key] == nil or item.isDisabled ~= true) then
                by_id[key] = item
            end
        end
    end
    for _, item in pairs(by_id) do
        table.insert(index_items, item)
    end

    if #index_items > 0 then
        log_info("SkyToolsInstalled fs.list retornou: " .. tostring(#index_items))
    else
        index_items = load_installed_index()
    end

    if #index_items == 0 then
        index_items = installed_items_from_name_cache()
        log_info("SkyToolsInstalled usando cache de nomes: " .. tostring(#index_items))
    end

    local scripts = merge_manifest_records_into_index(index_items)
    log_info("SkyToolsInstalled indice retornou: " .. tostring(#scripts))

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

    local names_dirty = false
    for _, script in ipairs(scripts) do
        script.appId = tonumber(script.appId or script.appid or 0) or 0
        script.appid = script.appId
        local id = tostring(script.appId)
        local metadata = steam_game_metadata(script.appId)
        local manifest_name = metadata ~= nil and trim(metadata.gameName or metadata.name) or ""
        if trim(names[id]) == "" and manifest_name ~= "" and not is_placeholder_game_name(manifest_name, id) then
            names[id] = manifest_name
            names_dirty = true
        end
        script.gameName = record_names[id] or names[id] or (manifest_name ~= "" and manifest_name or "AppID " .. id)
        script.name = script.gameName
        script.dlcCount = tonumber(script.dlcCount or script.DlcCount or script.dlc_count or 0) or 0
        if script.dlcCount <= 0 and trim(script.fullPath) ~= "" then
            script.dlcCount = count_dlcs_from_script(script.fullPath, script.appId)
        end
        script.imageUrl = "https://cdn.akamai.steamstatic.com/steam/apps/" .. id .. "/header.jpg"
        script.hasDenuvo = false
        script.hasAvailableFix = false
        script.hasAppliedFix = false
        script.isSteamInstalled = false
        script.gamePath = metadata ~= nil and trim(metadata.gamePath) or steam_game_install_path(script.appId)
        script.metadataLoaded = false
        script.metadataLoading = false
    end

    if names_dirty then
        save_name_cache_map(names)
    end

    if #scripts > 0 then
        save_installed_index(scripts)
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
    for _, item in ipairs(load_installed_index()) do
        local appid = tostring(item.appId or item.appid or "")
        if appid ~= "" and seen[appid] ~= true then
            seen[appid] = true
            count = count + 1
        end
    end
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
        hasMorrenusKey = trim(get_prop(settings, "MorrenusApiKey", "morrenusApiKey", "")) ~= "",
        pluginId = get_prop(payload, "pluginId", "pluginId", PLUGIN_ID),
        injection = runtime.last_injection,
        browserJsId = runtime.browser_js_id,
        browserCssId = runtime.browser_css_id,
        fsAvailable = fs_ok and fs ~= nil,
        fsListAvailable = fs_ok and fs ~= nil and fs.list ~= nil,
        backendMode = "lua-inline-wsh-installer"
    }
end

local clean_api_order

local function collect_api_order_values(order)
    local values = {}
    if type(order) == "string" then
        local text = trim(order)
        if text:sub(1, 1) == "[" or text:sub(1, 1) == "{" then
            local decoded = json_decode(text, nil)
            if type(decoded) == "table" then
                return collect_api_order_values(decoded)
            end
        end
        for id in text:gmatch("[^,%s]+") do
            table.insert(values, id)
        end
        return values
    end

    if type(order) ~= "table" then
        return values
    end

    local indexed = {}
    for key, value in pairs(order) do
        local index = tonumber(key)
        if index ~= nil then
            table.insert(indexed, { index = index, value = value })
        end
    end
    table.sort(indexed, function(left, right)
        return left.index < right.index
    end)
    for _, item in ipairs(indexed) do
        table.insert(values, item.value)
    end

    if #values == 0 then
        for _, value in ipairs(order) do
            table.insert(values, value)
        end
    end
    return values
end

local function apis_direct()
    local settings = load_settings()
    local custom = get_prop(settings, "CustomManifestApis", "customManifestApis", {})
    local native_overrides = get_prop(settings, "NativeManifestApis", "nativeManifestApis", {})
    local disabled_api_ids = get_prop(settings, "DisabledApiIds", "disabledApiIds", {})
    local api_order = get_prop(settings, "ApiOrder", "apiOrder", {})
    if type(custom) ~= "table" or not is_array(custom) then
        custom = {}
    end
    if type(native_overrides) ~= "table" then
        native_overrides = {}
    end
    if type(disabled_api_ids) ~= "table" then
        disabled_api_ids = {}
    end
    if type(api_order) ~= "table" then
        api_order = DEFAULT_API_ORDER
    end

    local clean_custom = {}
    for _, item in ipairs(custom) do
        if type(item) == "table" then
            local id = trim(get_prop(item, "id", "Id", ""))
            local name = trim(get_prop(item, "name", "Name", ""))
            local url = trim(get_prop(item, "urlTemplate", "UrlTemplate", ""))
            if id ~= "" and name ~= "" and url ~= "" and url:find("<appid>", 1, true) ~= nil then
                table.insert(clean_custom, item)
            end
        end
    end
    custom = clean_custom

    local disabled = {}
    for _, id in ipairs(disabled_api_ids) do
        disabled[tostring(id):lower()] = true
    end

    local function native_api(id, name, requires_key, url)
        local override = native_overrides[id] or native_overrides[id:lower()] or {}
        if type(override) ~= "table" then
            override = {}
        end
        local api_key = trim(get_prop(override, "apiKey", "ApiKey", ""))
        if id == "morrenus" and api_key == "" then
            api_key = trim(get_prop(settings, "MorrenusApiKey", "morrenusApiKey", ""))
        end
        return {
            id = id,
            name = trim(get_prop(override, "name", "Name", name)),
            editable = true,
            native = true,
            enabled = disabled[id] ~= true and get_prop(override, "enabled", "Enabled", true) ~= false,
            requiresKey = requires_key,
            urlTemplate = trim(get_prop(override, "urlTemplate", "UrlTemplate", url)),
            apiKey = api_key,
            useProxy = get_prop(override, "useProxy", "UseProxy", false) == true,
            proxyUrlTemplate = trim(get_prop(override, "proxyUrlTemplate", "ProxyUrlTemplate", "")),
            successCode = tonumber(get_prop(override, "successCode", "SuccessCode", 200)) or 200,
            unavailableCode = tonumber(get_prop(override, "unavailableCode", "UnavailableCode", 404)) or 404
        }
    end

    return {
        preferred = trim(get_prop(settings, "PreferredDownloadApi", "preferredDownloadApi", "Automatic")),
        morrenusApiKey = trim(get_prop(settings, "MorrenusApiKey", "morrenusApiKey", "")),
        apiOrder = clean_api_order(api_order, custom, nil),
        builtIn = {
            native_api("skyapi", "SkyAPI", false, "https://raw.githubusercontent.com/skyflarefox/Skyapi/refs/heads/main/<appid>.zip"),
            native_api("morrenus", "Morrenus", true, "https://hubcapmanifest.com/api/v1/manifest/<appid>?api_key=<moapikey>"),
            native_api("sushi", "Sushi", false, "https://raw.githubusercontent.com/sushi-dev55-alt/sushitools-games-repo-alt/refs/heads/main/<appid>.zip")
        },
        custom = custom
    }
end

function clean_api_order(order, custom, include_id)
    local allowed = { skyapi = true, morrenus = true, sushi = true }
    for _, item in ipairs(custom or {}) do
        if type(item) == "table" then
            local id = trim(get_prop(item, "id", "Id", ""))
            if id ~= "" then
                allowed[id:lower()] = true
            end
        end
    end
    if include_id ~= nil and trim(include_id) ~= "" then
        allowed[trim(include_id):lower()] = true
    end

    local clean = {}
    local seen = {}
    local function add(id)
        id = trim(id)
        local key = id:lower()
        if id ~= "" and allowed[key] == true and seen[key] ~= true then
            seen[key] = true
            table.insert(clean, id)
        end
    end

    for _, id in ipairs(collect_api_order_values(order)) do
        add(id)
    end
    for _, id in ipairs(DEFAULT_API_ORDER) do
        add(id)
    end
    for _, item in ipairs(custom or {}) do
        if type(item) == "table" then
            add(get_prop(item, "id", "Id", ""))
        end
    end
    if include_id ~= nil then
        add(include_id)
    end
    return clean
end

local function same_string_array(left, right)
    if type(left) ~= "table" or type(right) ~= "table" or #left ~= #right then
        return false
    end
    for index = 1, #left do
        if tostring(left[index] or "") ~= tostring(right[index] or "") then
            return false
        end
    end
    return true
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
    remove_installed_index_entry(appid)
    cache_clear()
    return { appId = appid, removed = true }
end

local function save_api_direct(payload)
    local settings = load_settings()
    local custom = get_prop(settings, "CustomManifestApis", "customManifestApis", {})
    if type(custom) ~= "table" or not is_array(custom) then
        custom = {}
    end
    local native_ids = { skyapi = true, morrenus = true, sushi = true }

    local api = {
        id = trim(get_prop(payload, "id", "Id", "")),
        name = trim(get_prop(payload, "name", "Name", "")),
        urlTemplate = trim(get_prop(payload, "urlTemplate", "UrlTemplate", "")),
        apiKey = trim(get_prop(payload, "apiKey", "ApiKey", "")),
        useProxy = get_prop(payload, "useProxy", "UseProxy", false) == true,
        proxyUrlTemplate = trim(get_prop(payload, "proxyUrlTemplate", "ProxyUrlTemplate", "")),
        successCode = tonumber(get_prop(payload, "successCode", "SuccessCode", 200)) or 200,
        unavailableCode = tonumber(get_prop(payload, "unavailableCode", "UnavailableCode", 404)) or 404,
        enabled = get_prop(payload, "enabled", "Enabled", true) ~= false
    }
    local lower_id = api.id:lower()

    if api.name == "" then
        return { success = false, error = "Informe um nome para a API." }
    end
    if api.urlTemplate == "" or api.urlTemplate:find("<appid>", 1, true) == nil then
        return { success = false, error = "A URL da API precisa conter <appid>." }
    end
    if api.id == "" then
        api.id = "skytools-" .. tostring(os.time())
        lower_id = api.id:lower()
    end

    if native_ids[lower_id] == true then
        local native_overrides = get_prop(settings, "NativeManifestApis", "nativeManifestApis", {})
        local disabled_api_ids = get_prop(settings, "DisabledApiIds", "disabledApiIds", {})
        if type(native_overrides) ~= "table" then
            native_overrides = {}
        end
        if type(disabled_api_ids) ~= "table" then
            disabled_api_ids = {}
        end

        native_overrides[lower_id] = api
        settings.NativeManifestApis = native_overrides
        if lower_id == "morrenus" then
            settings.MorrenusApiKey = api.apiKey
        end

        local kept_disabled = {}
        for _, id in ipairs(disabled_api_ids) do
            if tostring(id):lower() ~= lower_id then
                table.insert(kept_disabled, id)
            end
        end
        if api.enabled == false then
            table.insert(kept_disabled, lower_id)
        end
        settings.DisabledApiIds = kept_disabled
        settings.ApiOrder = clean_api_order(get_prop(settings, "ApiOrder", "apiOrder", DEFAULT_API_ORDER), custom, lower_id)
        write_json(settings_path(), settings)
        cache_clear()
        return api
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
    settings.ApiOrder = clean_api_order(get_prop(settings, "ApiOrder", "apiOrder", DEFAULT_API_ORDER), custom, api.id)
    write_json(settings_path(), settings)
    cache_clear()
    return api
end

local function save_api_settings_direct(payload)
    payload = normalize_payload(payload)
    local settings = load_settings()
    local preferred = trim(get_first_prop(payload, { "preferred", "preferredApi", "PreferredDownloadApi", "preferredDownloadApi" }, ""))
    local morrenus_key = trim(get_prop(payload, "morrenusApiKey", "MorrenusApiKey", ""))
    local api_order = get_first_prop(payload, { "apiOrder", "ApiOrder", "order", "Order", "apiOrderText", "ApiOrderText", "orderText" }, nil)
    if api_order == nil and type(payload) == "table" and is_array(payload) then
        api_order = payload
    end
    if preferred ~= "" then
        settings.PreferredDownloadApi = preferred
    end
    if morrenus_key ~= "" then
        settings.MorrenusApiKey = morrenus_key
    end
    local custom = get_prop(settings, "CustomManifestApis", "customManifestApis", {})
    if type(custom) ~= "table" or not is_array(custom) then
        custom = {}
    end
    if type(api_order) == "table" or type(api_order) == "string" then
        settings.ApiOrder = clean_api_order(api_order, custom, nil)
    else
        return { success = false, error = "Ordem das APIs nao recebida pelo backend." }
    end
    if not write_json(settings_path(), settings) then
        return { success = false, error = "Nao foi possivel gravar settings.json." }
    end
    local saved_settings = read_json(settings_path(), {})
    local saved_order = clean_api_order(get_prop(saved_settings, "ApiOrder", "apiOrder", {}), custom, nil)
    if not same_string_array(saved_order, settings.ApiOrder) then
        return { success = false, error = "A ordem das APIs nao foi persistida em settings.json." }
    end
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
            table.insert(disabled_api_ids, lower_id)
        end
        settings.DisabledApiIds = disabled_api_ids
        write_json(settings_path(), settings)
        cache_clear()
        return { id = id, disabled = true }
    end

    local custom = get_prop(settings, "CustomManifestApis", "customManifestApis", {})
    local kept = {}
    local removed_name = ""
    if type(custom) == "table" and is_array(custom) then
        for _, item in ipairs(custom) do
            if type(item) ~= "table" or trim(get_prop(item, "id", "Id", "")) ~= id then
                table.insert(kept, item)
            else
                removed_name = trim(get_prop(item, "name", "Name", ""))
            end
        end
    end
    settings.CustomManifestApis = kept
    settings.ApiOrder = clean_api_order(get_prop(settings, "ApiOrder", "apiOrder", DEFAULT_API_ORDER), kept, nil)
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
        "cscript.exe",
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
    local ok = run_minimized_command(command, false)
    local exec_result = ""
    if not ok then
        return {
            success = false,
            error = "Nao foi possivel iniciar o instalador interno. Verifique se o Windows Script Host esta habilitado."
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
    if result.success == true then
        local data = get_prop(result, "data", "Data", {})
        if type(data) == "table" then
            local script_path = trim(get_prop(data, "scriptPath", "ScriptPath", ""))
            update_installed_index_entry(appid, {
                fileName = tostring(appid) .. ".lua",
                fullPath = script_path ~= "" and script_path or join_path(active_script_directory(), tostring(appid) .. ".lua"),
                scriptDirectory = script_path ~= "" and (parent_dir(script_path) or active_script_directory()) or active_script_directory(),
                dlcCount = tonumber(get_prop(data, "dlcCount", "DlcCount", 0)) or 0,
                isDisabled = false
            })
        end
    end
    cache_clear()
    return result
end

local function ps_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

local function repair_script_path(kind)
    return join_path(data_root(), "skytools-repair-" .. tostring(kind or "task") .. ".ps1")
end

local function launch_elevated_powershell(script_path)
    local vbs_path = ensure_launcher("run-elevated-powershell.vbs", table.concat({
        'Set app = CreateObject("Shell.Application")',
        'scriptPath = ""',
        'If WScript.Arguments.Count > 0 Then scriptPath = WScript.Arguments.Item(0)',
        'If scriptPath <> "" Then',
        '  args = "-NoProfile -ExecutionPolicy Bypass -File " & Chr(34) & scriptPath & Chr(34)',
        '  app.ShellExecute "powershell.exe", args, "", "runas", 7',
        'End If'
    }, "\r\n"))
    local ok = run_minimized_command("cscript.exe //Nologo " .. quote_arg(vbs_path) .. " " .. quote_arg(script_path), false)
    return ok
end

local function run_powershell_script(script_path)
    return run_minimized_command("powershell.exe -WindowStyle Minimized -NoProfile -ExecutionPolicy Bypass -File " .. quote_arg(script_path), false)
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
        local exe_path = join_path(data_root(), "SkyTools-VisualCppRedist_AIO_x86_x64.exe")
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
    local game_path = trim(get_prop(payload, "gamePath", "installPath", ""))
    if game_path == "" then
        game_path = steam_game_install_path(appid)
    end
    local sources = {}

    local helper = fixes_helper_path()
    if is_file(helper) then
        local result_path = job_result_path("fixes-" .. appid)
        delete_file(result_path)
        local command = table.concat({
            "cscript.exe",
            "//Nologo",
            quote_arg(helper),
            quote_arg(result_path),
            quote_arg(appid),
            quote_arg(name)
        }, " ")
        run_minimized_command(command, false)
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

    for _, source in ipairs(sources) do
        if type(source) == "table" then
            source.provider = trim(get_prop(source, "provider", "Provider", "Ryuu"))
            source.action = "apply"
            source.gamePath = game_path
        end
    end

    return {
        gamePath = game_path,
        sources = sources
    }
end

local function simple_fix_sources(payload, kind)
    payload = normalize_payload(payload)
    local appid = tostring(get_prop(payload, "appid", "appId", ""))
    local name = trim(get_prop(payload, "name", "gameName", appid))
    if kind == "online" then
        return { success = false, error = "OnlineFix foi removido do SkyTools. Use as correcoes Ryuu." }
    end
    if kind == "denuvo" then
        return find_fix_sources_direct({ appid = appid, name = name })
    end
    return { gamePath = "", sources = {} }
end

local function archive_extension(value)
    local text = trim(value):lower()
    local path = text:match("^[^?]+") or text
    local extension = path:match("%.([^%.\\/]+)$") or ""
    if extension == "zip" or extension == "rar" or extension == "7z" then
        return extension
    end
    return ""
end

local function apply_fix_direct(payload)
    payload = normalize_payload(payload)
    local appid = tostring(get_prop(payload, "appid", "appId", ""))
    local name = trim(get_prop(payload, "name", "gameName", appid))
    local game_path = trim(get_prop(payload, "gamePath", "installPath", ""))
    local source = get_prop(payload, "source", {})
    local source_json = get_prop(payload, "sourceJson", "source_json", "")
    if type(source) == "string" then
        source = json_decode(source, {})
    end
    if type(source) ~= "table" then
        source = {}
    end
    if trim(get_first_prop(source, { "downloadUrl", "DownloadUrl", "sourceUrl", "SourceUrl", "url", "Url", "href", "link" }, "")) == "" and trim(source_json) ~= "" then
        local decoded = json_decode(source_json, nil)
        if type(decoded) == "table" then
            source = decoded
        end
    end

    local url = trim(get_first_prop(source, { "downloadUrl", "DownloadUrl", "sourceUrl", "SourceUrl", "url", "Url", "href", "link" }, ""))
    if url == "" then
        url = trim(get_first_prop(payload, { "downloadUrl", "DownloadUrl", "sourceUrl", "SourceUrl", "url", "Url", "href", "link" }, ""))
        if url ~= "" then
            source.downloadUrl = url
            source.name = trim(get_first_prop(source, { "name", "title" }, get_first_prop(payload, { "sourceName", "name" }, "")))
            source.type = trim(get_first_prop(source, { "type" }, get_first_prop(payload, { "sourceType", "type" }, "")))
            source.provider = trim(get_first_prop(source, { "provider" }, get_prop(payload, "provider", "Ryuu")))
            source.size = trim(get_first_prop(source, { "size" }, get_prop(payload, "size", "")))
        end
    end
    if url == "" then
        local source_name = trim(get_first_prop(source, { "name", "title" }, get_prop(payload, "sourceName", "")))
        if archive_extension(source_name) ~= "" then
            url = "https://generator.ryuu.lol/fixes/" .. source_name:gsub(" ", "%%20")
            source.downloadUrl = url
            source.name = source_name
        end
    end
    if url == "" then
        return { success = false, error = "Fonte sem link para abrir." }
    end
    if game_path == "" then
        game_path = trim(get_prop(source, "gamePath", "installPath", ""))
    end
    if game_path == "" then
        game_path = steam_game_install_path(appid)
    end

    local provider = trim(get_prop(source, "provider", "Provider", ""))
    local action = trim(get_prop(source, "action", "Action", ""))
    local extension = archive_extension(url)
    if extension == "" then
        return {
            success = false,
            error = "Aplicacao automatica suporta apenas pacotes .zip, .rar e .7z.",
            url = url
        }
    end
    if game_path == "" then
        return { success = false, error = "Pasta instalada do jogo nao encontrada." }
    end

    local script_path = join_path(data_root(), "skytools-apply-fix-" .. appid .. ".ps1")
    local package_path = join_path(data_root(), "skytools-fix-" .. appid .. "." .. extension)
    local extract_path = join_path(data_root(), "skytools-fix-" .. appid .. "-extract")
    local backup_path = join_path(data_root(), "fix-backups\\" .. appid .. "\\" .. tostring(os.time()))
    local log_path = join_path(game_path, "skytools-fix-log-" .. appid .. ".log")
    local source_type = trim(get_prop(source, "type", "Type", "Fix"))
    local script = table.concat({
        "$ErrorActionPreference = 'Stop'",
        "$url = " .. ps_quote(url),
        "$appid = " .. ps_quote(appid),
        "$game = " .. ps_quote(name ~= "" and name or ("AppID " .. appid)),
        "$sourceType = " .. ps_quote(source_type ~= "" and source_type or "Fix"),
        "$gamePath = " .. ps_quote(game_path),
        "$package = " .. ps_quote(package_path),
        "$extract = " .. ps_quote(extract_path),
        "$backup = " .. ps_quote(backup_path),
        "$log = " .. ps_quote(log_path),
        "if (!(Test-Path -LiteralPath $gamePath)) { throw 'Pasta do jogo nao encontrada.' }",
        "Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue",
        "New-Item -ItemType Directory -Path (Split-Path -Parent $package) -Force | Out-Null",
        "New-Item -ItemType Directory -Path $extract -Force | Out-Null",
        "Invoke-WebRequest -Uri $url -OutFile $package",
        "$ext = [IO.Path]::GetExtension($package).ToLowerInvariant()",
        "function Expand-FixArchive {",
        "  if ($ext -eq '.zip') {",
        "    try { Expand-Archive -LiteralPath $package -DestinationPath $extract -Force; return } catch { }",
        "  }",
        "  $tar = (Get-Command tar.exe -ErrorAction SilentlyContinue).Source",
        "  if ($tar) {",
        "    & $tar -xf $package -C $extract",
        "    if ($LASTEXITCODE -eq 0) { return }",
        "  }",
        "  $candidates = @(",
        "    (Join-Path $env:ProgramFiles '7-Zip\\7z.exe'),",
        "    (Join-Path ${env:ProgramFiles(x86)} '7-Zip\\7z.exe'),",
        "    (Join-Path (Split-Path -Parent $package) '7z.exe')",
        "  )",
        "  $seven = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1",
        "  if (!$seven) { throw 'Nao foi possivel extrair o pacote. Instale o 7-Zip ou use Windows com tar.exe/libarchive.' }",
        "  & $seven x $package ('-o' + $extract) -y | Out-Null",
        "  if ($LASTEXITCODE -ne 0) { throw '7-Zip nao conseguiu extrair o pacote.' }",
        "}",
        "Expand-FixArchive",
        "$sourceRoot = $extract",
        "$appidDir = Join-Path $extract $appid",
        "if (Test-Path -LiteralPath $appidDir) { $sourceRoot = $appidDir }",
        "else {",
        "  $topFiles = @(Get-ChildItem -LiteralPath $extract -File -Force)",
        "  $topDirs = @(Get-ChildItem -LiteralPath $extract -Directory -Force)",
        "  if ($topFiles.Count -eq 0 -and $topDirs.Count -eq 1) { $sourceRoot = $topDirs[0].FullName }",
        "}",
        "$gameRoot = [IO.Path]::GetFullPath($gamePath).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar",
        "$sourceRootFull = [IO.Path]::GetFullPath($sourceRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar",
        "$files = Get-ChildItem -LiteralPath $sourceRoot -File -Recurse",
        "if (!$files -or $files.Count -eq 0) { throw 'Pacote de correcao vazio.' }",
        "New-Item -ItemType Directory -Path $backup -Force | Out-Null",
        "$written = @()",
        "foreach ($file in $files) {",
        "  $fileFull = [IO.Path]::GetFullPath($file.FullName)",
        "  if (!$fileFull.StartsWith($sourceRootFull, [StringComparison]::OrdinalIgnoreCase)) { continue }",
        "  $relative = $fileFull.Substring($sourceRootFull.Length)",
        "  $dest = [IO.Path]::GetFullPath((Join-Path $gameRoot $relative))",
        "  if (!$dest.StartsWith($gameRoot, [StringComparison]::OrdinalIgnoreCase)) { continue }",
        "  if (Test-Path -LiteralPath $dest) {",
        "    $backupDest = Join-Path $backup $relative",
        "    New-Item -ItemType Directory -Path (Split-Path -Parent $backupDest) -Force | Out-Null",
        "    Copy-Item -LiteralPath $dest -Destination $backupDest -Force",
        "  }",
        "  New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null",
        "  Copy-Item -LiteralPath $file.FullName -Destination $dest -Force",
        "  $written += $relative",
        "}",
        "$entry = @('[FIX]', 'Date: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), 'Game: ' + $game, 'Provider: Ryuu', 'Type: ' + $sourceType, 'Download URL: ' + $url, 'Backup: ' + $backup, 'Files:') + $written + @('[/FIX]', '')",
        "Add-Content -LiteralPath $log -Value $entry -Encoding UTF8"
    }, "\r\n")
    write_file(script_path, script)
    local ok = run_powershell_script(script_path)
    if not ok then
        return { success = false, error = "Nao foi possivel iniciar a aplicacao da correcao." }
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
        type = source_type,
        gamePath = game_path,
        createdAt = os.date("%Y-%m-%dT%H:%M:%S")
    })
    write_json(records_path, records)

    return {
        appId = tonumber(appid) or appid,
        name = name,
        url = url,
        type = source_type,
        gamePath = game_path,
        message = "Correcao Ryuu iniciada em segundo plano."
    }
end

local function response_from_result(result)
    if type(result) == "table" and result.success == false then
        return result
    end
    if type(result) == "table" and result.success == true and result.data ~= nil then
        return result
    end
    return { success = true, data = result, error = "" }
end

local function dispatch_inline(method, payload)
    payload = payload or {}
    if method == "status" then return response_from_result(status_direct(payload)) end
    if method == "installed" then return response_from_result(installed_direct()) end
    if method == "steam-installed" then return response_from_result(steam_installed_direct()) end
    if method == "name-cache" then
        local cache = load_name_cache()
        return response_from_result({ path = name_cache_path(), games = cache, count = count_map_values(cache) })
    end
    if method == "apis" then return response_from_result(apis_direct()) end
    if method == "save-api" then
        local result = save_api_direct(payload)
        return response_from_result(result)
    end
    if method == "save-api-settings" then
        local result = save_api_settings_direct(payload)
        return response_from_result(result)
    end
    if method == "delete-api" then return response_from_result(delete_api_direct(payload)) end
    if method == "remove-game" then
        local result = remove_game_direct(payload)
        return response_from_result(result)
    end
    if method == "backup-export" then return response_from_result(backup_export_direct(payload)) end
    if method == "backup-restore" then
        local result = backup_restore_direct(payload)
        return response_from_result(result)
    end
    if method == "fix-sources" then return response_from_result(find_fix_sources_direct(payload)) end
    if method == "online-fix" then return response_from_result(simple_fix_sources(payload, "online")) end
    if method == "denuvo-fix" then return response_from_result(simple_fix_sources(payload, "denuvo")) end
    if method == "repair" then return response_from_result(run_repair_direct(payload)) end
    if method == "apply-fix" then
        local result = apply_fix_direct(payload)
        return response_from_result(result)
    end
    if method == "integration" then return response_from_result(integration_direct(payload)) end
    if method == "add-game" then return response_from_result(run_wscript_installer(payload)) end
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

function SkyToolsSteamInstalled()
    return worker_call("steam-installed", {}, 60)
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

function skytools_steam_installed()
    return SkyToolsSteamInstalled()
end
_G["skytools_steam_installed"] = skytools_steam_installed

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
        log_info("SkyTools Lua backend carregado em " .. safe_backend_path())
        millennium.ready()
    end)
    pcall(copy_public_assets)
    pcall(inject_browser_assets)
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
