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
local DEFAULT_API_ORDER = { "skyapi", "morrenus", "ryzen" }
local HIDDEN_CONSOLE_WORKER_VERSION = "2026-07-24-no-visible-process-1"

local runtime = {
    browser_js_id = 0,
    browser_css_id = 0,
    steam_path = nil,
    last_injection = {},
    cache = {},
    operations = {},
    hidden_console_job_id = 0
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

    if fs_ok and fs ~= nil and fs.exists ~= nil then
        local ok, exists = pcall(fs.exists, path)
        if ok and exists then
            return true
        end
    end

    if fs_ok and fs ~= nil and fs.create_directories ~= nil then
        local ok, created = pcall(fs.create_directories, path)
        if ok and created ~= false then
            return true
        end
    end

    log_error("Nao foi possivel criar diretorio sem usar shell bloqueante: " .. tostring(path))
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

local function list_directory_entries(path)
    if not (fs_ok and fs ~= nil and fs.list ~= nil) then
        return nil
    end
    local ok, entries = pcall(fs.list, path)
    if ok and type(entries) == "table" then
        return entries
    end
    return nil
end

local function entry_path(directory, entry)
    local value = tostring(entry or "")
    if value:find("[\\/]") ~= nil then
        return value
    end
    return join_path(directory, value)
end

local function delete_directory(path)
    path = tostring(path or "")
    if path == "" then
        return false
    end

    local entries = list_directory_entries(path)
    if entries ~= nil then
        for _, entry in ipairs(entries) do
            local child = entry_path(path, entry)
            if is_file(child) then
                delete_file(child)
            else
                delete_directory(child)
            end
        end
    elseif is_file(path) then
        delete_file(path)
        return true
    else
        log_error("Nao foi possivel listar diretorio para remover sem shell bloqueante: " .. tostring(path))
        return false
    end

    pcall(function()
        os.remove(path)
    end)
    return not path_exists(path)
end

local copy_file

local function copy_directory(source, target)
    source = tostring(source or "")
    target = tostring(target or "")
    if source == "" or target == "" or not path_exists(source) then
        return false
    end
    delete_directory(target)
    mkdirs(target)

    local entries = list_directory_entries(source)
    if entries == nil then
        log_error("Nao foi possivel listar diretorio para copiar sem shell bloqueante: " .. tostring(source))
        return false
    end

    local ok = true
    for _, entry in ipairs(entries) do
        local src_child = entry_path(source, entry)
        local name = tostring(entry):match("[^\\/]+$") or tostring(entry)
        local dst_child = join_path(target, name)
        if is_file(src_child) then
            if not copy_file(src_child, dst_child) then
                ok = false
            end
        else
            if not copy_directory(src_child, dst_child) then
                ok = false
            end
        end
    end
    return ok
end

function copy_file(source, target)
    local data = read_file(source)
    if data == nil then
        log_error("Asset não encontrado: " .. tostring(source))
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
        log_error("Arquivo de origem não encontrado: " .. tostring(source))
        return false
    end
    local target_data = read_file(target)
    if target_data == source_data then
        return true
    end
    return write_file(target, source_data)
end

local function sync_theme_directory(source, target)
    source = tostring(source or "")
    target = tostring(target or "")
    if source == "" or target == "" or not path_exists(source) then
        return false
    end

    mkdirs(target)
    local copied = false
    local seen = {}

    local function copy_theme(file_name)
        file_name = tostring(file_name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if file_name:match("^[%w%._%- ]+%.css$") == nil or seen[file_name] then
            return
        end
        seen[file_name] = true
        if sync_file_if_different(join_path(source, file_name), join_path(target, file_name)) then
            copied = true
        end
    end

    copy_theme("official-orange.css")
    copy_theme("ocean-cyan.css")
    copy_theme("graphite-lime.css")
    copy_theme("ruby-ember.css")
    copy_theme("pink-rose.css")

    if fs_ok and fs ~= nil and fs.list ~= nil then
        local ok, entries = pcall(fs.list, source)
        if ok and type(entries) == "table" then
            for _, entry in ipairs(entries) do
                copy_theme(tostring(entry):match("[^\\/]+$") or tostring(entry))
            end
        end
    end

    return copied or path_exists(target)
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
    local src_themes = join_path(public, "themes")
    local src_fa_solid = join_path(join_path(join_path(public, "fontawesome"), "webfonts"), "fa-solid-900.woff2")
    local js_webkit = copy_file(src_js, join_path(webkit_skytools, "skytools.js"))
    local css_webkit = copy_file(src_css, join_path(webkit_skytools, "skytools.css"))
    local ico_webkit = copy_file(src_ico, join_path(webkit_skytools, "skytools_logo.ico"))
    local png_webkit = copy_file(src_png, join_path(webkit_skytools, "skytools_logo.png"))
    local themes_webkit = sync_theme_directory(src_themes, join_path(webkit_skytools, "themes"))
    local fa_solid_webkit = copy_file(src_fa_solid, join_path(join_path(join_path(webkit_skytools, "fontawesome"), "webfonts"), "fa-solid-900.woff2"))
    local js_steamui_webkit = false
    local css_steamui_webkit = false
    local png_steamui_webkit = false
    local ico_steamui_webkit = false
    local fa_steamui_webkit = false
    local themes_steamui_webkit = false

    if steam_path ~= "" then
        local steamui = join_path(steam_path, "steamui")
        local legacy_webkit = join_path(steamui, "webkit")
        local steamui_webkit = join_path(legacy_webkit, "SkyTools")
        delete_file(join_path(steamui, "skytools.js"))
        delete_file(join_path(steamui, "skytools.css"))
        delete_file(join_path(steamui, "skytools_logo.ico"))
        delete_file(join_path(steamui, "skytools_logo.png"))
        delete_file(join_path(legacy_webkit, "skytools.js"))
        delete_file(join_path(legacy_webkit, "skytools.css"))
        delete_file(join_path(legacy_webkit, "skytools_logo.ico"))
        delete_file(join_path(legacy_webkit, "skytools_logo.png"))
        delete_directory(join_path(legacy_webkit, "fontawesome"))
        delete_file(join_path(steamui_webkit, "skytools.js"))
        delete_file(join_path(steamui_webkit, "skytools.css"))
        delete_file(join_path(steamui_webkit, "skytools_logo.ico"))
        delete_file(join_path(steamui_webkit, "skytools_logo.png"))
        delete_file(join_path(join_path(join_path(steamui_webkit, "fontawesome"), "webfonts"), "fa-solid-900.woff2"))
        js_steamui_webkit = sync_file_if_different(src_js, join_path(steamui_webkit, "skytools.js"))
        css_steamui_webkit = sync_file_if_different(src_css, join_path(steamui_webkit, "skytools.css"))
        ico_steamui_webkit = sync_file_if_different(src_ico, join_path(steamui_webkit, "skytools_logo.ico"))
        png_steamui_webkit = sync_file_if_different(src_png, join_path(steamui_webkit, "skytools_logo.png"))
        themes_steamui_webkit = sync_theme_directory(src_themes, join_path(steamui_webkit, "themes"))
        fa_steamui_webkit = sync_file_if_different(src_fa_solid, join_path(join_path(join_path(steamui_webkit, "fontawesome"), "webfonts"), "fa-solid-900.woff2"))
    end

    runtime.last_injection.copy = {
        success = js_webkit,
        jsWebkit = js_webkit,
        cssWebkit = css_webkit,
        icoWebkit = ico_webkit,
        pngWebkit = png_webkit,
        themesWebkit = themes_webkit,
        faSolidWebkit = fa_solid_webkit,
        jsSteamUiWebkit = js_steamui_webkit,
        cssSteamUiWebkit = css_steamui_webkit,
        icoSteamUiWebkit = ico_steamui_webkit,
        pngSteamUiWebkit = png_steamui_webkit,
        themesSteamUiWebkit = themes_steamui_webkit,
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

local function json_decode_fallback(text, depth)
    text = tostring(text or ""):gsub("^\239\187\191", "")
    depth = tonumber(depth) or 0
    if depth > 10 then
        return nil
    end
    if text:match("^%s*$") ~= nil or #text > 2097152 then
        return nil
    end

    local index = 1

    local function skip_ws()
        while index <= #text do
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

    local function parse_array(current_depth)
        if current_depth > 10 then
            error("max depth")
        end
        local result = {}
        index = index + 1
        skip_ws()
        if text:sub(index, index) == "]" then
            index = index + 1
            return result
        end
        while true do
            table.insert(result, parse_value(current_depth + 1))
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

    local function parse_object(current_depth)
        if current_depth > 10 then
            error("max depth")
        end
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
            result[key] = parse_value(current_depth + 1)
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

    function parse_value(current_depth)
        current_depth = current_depth or depth
        if current_depth > 10 then
            error("max depth")
        end
        skip_ws()
        local char = text:sub(index, index)
        if char == "" then error("unexpected end") end
        if char == '"' then return parse_string() end
        if char == "{" then return parse_object(current_depth + 1) end
        if char == "[" then return parse_array(current_depth + 1) end
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
        skip_ws()
        if index <= #text then
            return nil
        end
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
    local decoded = json_decode_fallback(text, 0)
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

local function canonical_api_id(id)
    local value = trim(id):lower()
    if value == "sushi" then
        return "ryzen"
    end
    return value
end

local function native_api_ids()
    return { skyapi = true, morrenus = true, ryzen = true }
end

local function payload_debug_keys(payload)
    if type(payload) ~= "table" then
        return type(payload)
    end
    local keys = {}
    for key, value in pairs(payload) do
        table.insert(keys, tostring(key) .. "=" .. type(value))
        if #keys >= 8 then
            break
        end
    end
    table.sort(keys)
    return table.concat(keys, ",")
end

local function canonical_preferred_api_id(id)
    local value = trim(id)
    if value == "" or value:lower() == "automatic" then
        return "Automatic"
    end
    local lower = canonical_api_id(value)
    if native_api_ids()[lower] == true then
        return lower
    end
    return value
end

local function canonical_language_id(id)
    local value = trim(id)
    local lower = value:lower()
    if value == "" or lower == "auto" or lower == "system" or lower == "windows" then
        return "auto"
    end
    if lower == "pt" or lower == "pt-br" or lower == "pt_br" then
        return "pt-BR"
    end
    if lower == "en" or lower:match("^en%-") ~= nil then
        return "en"
    end
    if lower == "es" or lower:match("^es%-") ~= nil then
        return "es"
    end
    if lower == "ru" or lower:match("^ru%-") ~= nil then
        return "ru"
    end
    return nil
end

local function hidden_console_queue_dir()
    return join_path(data_root(), "skytools-hidden-console-queue")
end

local function hidden_console_pending_dir()
    return join_path(hidden_console_queue_dir(), "pending")
end

local function hidden_console_running_dir()
    return join_path(hidden_console_queue_dir(), "running")
end

local function hidden_console_done_dir()
    return join_path(hidden_console_queue_dir(), "done")
end

local function hidden_console_state_path()
    return join_path(data_root(), "skytools-hidden-console-state.json")
end

local function hidden_console_stop_path()
    return join_path(data_root(), "skytools-hidden-console.stop")
end

local function auto_update_status_path()
    return join_path(data_root(), "skytools-auto-update-status.json")
end

local function hidden_console_worker_script()
    return [[
param([string]$Root)
$ErrorActionPreference = 'Continue'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
$Queue = Join-Path $Root 'skytools-hidden-console-queue'
$Pending = Join-Path $Queue 'pending'
$Running = Join-Path $Queue 'running'
$Done = Join-Path $Queue 'done'
$StatePath = Join-Path $Root 'skytools-hidden-console-state.json'
$StopPath = Join-Path $Root 'skytools-hidden-console.stop'
$LogPath = Join-Path $Root 'skytools-hidden-console.log'
$WorkerVersion = '2026-07-24-no-visible-process-1'

function Ensure-SkyToolsDirectory([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Get-SkyToolsUnixTime {
  return [DateTimeOffset]::Now.ToUnixTimeSeconds()
}

function Write-SkyToolsLog([string]$Message) {
  try {
    Add-Content -LiteralPath $LogPath -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $Message) -Encoding UTF8
  } catch {}
}

function Write-SkyToolsState([string]$Status, [string]$JobId) {
  try {
    $state = [ordered]@{
      pid = $PID
      status = $Status
      jobId = $JobId
      version = $WorkerVersion
      updatedAt = Get-SkyToolsUnixTime
    } | ConvertTo-Json -Compress
    Set-Content -LiteralPath $StatePath -Value $state -Encoding UTF8
  } catch {}
}

function Complete-SkyToolsJob($Job, [bool]$Success, [int]$ExitCode, [string]$ErrorMessage) {
  try {
    $donePath = Join-Path $Done ([string]$Job.id + '.json')
    $result = [ordered]@{
      id = [string]$Job.id
      kind = [string]$Job.kind
      success = $Success
      exitCode = $ExitCode
      error = $ErrorMessage
      finishedAt = Get-SkyToolsUnixTime
    } | ConvertTo-Json -Compress
    Set-Content -LiteralPath $donePath -Value $result -Encoding UTF8
  } catch {}
}

function Invoke-SkyToolsJob($Job) {
  $exitCode = 0
  switch ([string]$Job.kind) {
    'process' {
      $argv = @()
      if ($null -ne $Job.arguments) {
        foreach ($arg in @($Job.arguments)) { $argv += [string]$arg }
      }
      $escapedArgs = @()
      foreach ($arg in $argv) {
        $escapedArgs += ('"' + ([string]$arg).Replace('"', '\"') + '"')
      }
      $psi = New-Object System.Diagnostics.ProcessStartInfo
      $psi.FileName = [string]$Job.filePath
      $psi.Arguments = ($escapedArgs -join ' ')
      $psi.UseShellExecute = $false
      $psi.CreateNoWindow = $true
      $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
      $process = [System.Diagnostics.Process]::Start($psi)
      if ($null -ne $process) { $process.WaitForExit() }
      if ($null -ne $process) { $exitCode = [int]$process.ExitCode }
    }
    'powershell-file' {
      & ([string]$Job.scriptPath)
      if ($null -ne $LASTEXITCODE) { $exitCode = [int]$LASTEXITCODE }
    }
    'elevated-powershell-file' {
      $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', [string]$Job.scriptPath)
      Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs -WindowStyle Hidden
    }
    default {
      throw ('Tipo de job desconhecido: ' + [string]$Job.kind)
    }
  }
  return $exitCode
}

Ensure-SkyToolsDirectory $Root
Ensure-SkyToolsDirectory $Queue
Ensure-SkyToolsDirectory $Pending
Ensure-SkyToolsDirectory $Running
Ensure-SkyToolsDirectory $Done
Remove-Item -LiteralPath $StopPath -Force -ErrorAction SilentlyContinue
Write-SkyToolsLog 'Worker oculto iniciado.'

while (!(Test-Path -LiteralPath $StopPath)) {
  Write-SkyToolsState 'idle' ''
  $jobs = @(Get-ChildItem -LiteralPath $Pending -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc, Name)
  foreach ($file in $jobs) {
    if (Test-Path -LiteralPath $StopPath) { break }
    $runningPath = Join-Path $Running $file.Name
    try {
      Move-Item -LiteralPath $file.FullName -Destination $runningPath -Force
    } catch {
      continue
    }

    $job = $null
    $jobId = [IO.Path]::GetFileNameWithoutExtension($runningPath)
    try {
      $job = Get-Content -LiteralPath $runningPath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($job.id) { $jobId = [string]$job.id }
      Write-SkyToolsState 'busy' $jobId
      Write-SkyToolsLog ('Iniciando job ' + $jobId + ' (' + [string]$job.kind + ').')
      $code = Invoke-SkyToolsJob $job
      Complete-SkyToolsJob $job $true $code ''
      Write-SkyToolsLog ('Job ' + $jobId + ' finalizado com exitCode=' + $code + '.')
    } catch {
      $message = $_.Exception.Message
      if (!$message) { $message = [string]$_ }
      Write-SkyToolsLog ('Falha no job ' + $jobId + ': ' + $message)
      if ($null -ne $job) {
        Complete-SkyToolsJob $job $false 1 $message
      }
    } finally {
      Remove-Item -LiteralPath $runningPath -Force -ErrorAction SilentlyContinue
      Write-SkyToolsState 'idle' ''
    }
  }
  Start-Sleep -Milliseconds 250
}

Write-SkyToolsState 'stopped' ''
Write-SkyToolsLog 'Worker oculto encerrado.'
Remove-Item -LiteralPath $StopPath -Force -ErrorAction SilentlyContinue
]]
end

local function ensure_hidden_console_files()
    mkdirs(hidden_console_pending_dir())
    mkdirs(hidden_console_running_dir())
    mkdirs(hidden_console_done_dir())

    local worker_path = ensure_launcher("hidden-console-worker.ps1", hidden_console_worker_script())
    local launcher_path_value = ensure_launcher("start-hidden-console.vbs", table.concat({
        "Set shell = CreateObject(\"WScript.Shell\")",
        "worker = \"\"",
        "root = \"\"",
        "If WScript.Arguments.Count > 0 Then worker = WScript.Arguments.Item(0)",
        "If WScript.Arguments.Count > 1 Then root = WScript.Arguments.Item(1)",
        "If worker <> \"\" And root <> \"\" Then",
        "  command = \"powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \" & Chr(34) & worker & Chr(34) & \" -Root \" & Chr(34) & root & Chr(34)",
        "  shell.Run command, 0, False",
        "End If"
    }, "\r\n"))

    return worker_path, launcher_path_value
end

local function hidden_console_state_is_fresh(state)
    if type(state) ~= "table" then
        return false
    end

    local status = trim(get_prop(state, "status", "Status", ""))
    local updated_at = tonumber(get_prop(state, "updatedAt", "UpdatedAt", 0)) or 0
    local age = os.time() - updated_at
    if status == "busy" and age >= 0 and age < 7200 then
        return true
    end
    if status == "idle" and age >= 0 and age < 30 then
        return true
    end
    return false
end

local function hidden_console_is_active()
    local state = read_json(hidden_console_state_path(), nil)
    if not hidden_console_state_is_fresh(state) then
        return false
    end
    local version = trim(get_prop(state, "version", "Version", ""))
    return version == HIDDEN_CONSOLE_WORKER_VERSION
end

local function any_hidden_console_is_active()
    return hidden_console_state_is_fresh(read_json(hidden_console_state_path(), nil))
end

local function start_hidden_console_worker()
    local worker_path, launcher_path_value = ensure_hidden_console_files()
    if hidden_console_is_active() then
        return true
    end

    if any_hidden_console_is_active() then
        write_file(hidden_console_stop_path(), tostring(os.time()))
        local waited_stop = 0
        while waited_stop < 3000 and any_hidden_console_is_active() and not hidden_console_is_active() do
            sleep_ms(250)
            waited_stop = waited_stop + 250
        end
        if any_hidden_console_is_active() and not hidden_console_is_active() then
            log_info("Worker oculto antigo ainda ativo; aguardando reinicio completo para trocar a versao.")
            return true
        end
    end

    delete_file(hidden_console_stop_path())
    local ok = pcall(function()
        local command = "wscript.exe " .. quote_arg(launcher_path_value) .. " " .. quote_arg(worker_path) .. " " .. quote_arg(data_root())
        if utils ~= nil and utils.exec ~= nil then
            return utils.exec(command)
        end
        return os.execute(command)
    end)
    if not ok then
        log_error("Falha ao iniciar console oculto persistente.")
        return false
    end

    local waited = 0
    while waited < 5000 and not hidden_console_is_active() do
        sleep_ms(250)
        waited = waited + 250
    end
    return hidden_console_is_active()
end

local function stop_hidden_console_worker()
    write_file(hidden_console_stop_path(), tostring(os.time()))
end

local function next_hidden_console_job_id()
    runtime.hidden_console_job_id = (tonumber(runtime.hidden_console_job_id) or 0) + 1
    return tostring(os.time()) .. "-" .. tostring(runtime.hidden_console_job_id)
end

local function enqueue_hidden_console_job(job)
    if type(job) ~= "table" then
        return false
    end
    if not start_hidden_console_worker() then
        return false
    end

    local id = next_hidden_console_job_id()
    job.id = id
    job.createdAt = os.time()

    local path = join_path(hidden_console_pending_dir(), id .. ".json")
    local temp_path = path .. ".tmp"
    if not write_json(temp_path, job) then
        return false
    end
    pcall(function()
        os.remove(path)
    end)
    local ok, renamed = pcall(function()
        return os.rename(temp_path, path)
    end)
    if not ok or renamed ~= true then
        delete_file(temp_path)
        return false
    end
    return true
end

local function run_hidden_console_process(file_path, arguments)
    return enqueue_hidden_console_job({
        kind = "process",
        filePath = file_path,
        arguments = arguments or {}
    })
end

local function run_hidden_console_powershell_file(script_path, elevated)
    return enqueue_hidden_console_job({
        kind = elevated and "elevated-powershell-file" or "powershell-file",
        scriptPath = script_path
    })
end

local function plugin_version()
    local manifest = read_json(join_path(plugin_dir(), "plugin.json"), {})
    local version = trim(get_prop(manifest, "version", "Version", ""))
    if version ~= "" then
        return version
    end
    return "0.0.0"
end

local function auto_update_script()
    local current_version = plugin_version()
    return [=[
$ErrorActionPreference = 'Stop'
$Repo = 'skyflarefox/skytoolsPlugin'
$CurrentVersion = ']=] .. current_version:gsub("'", "''") .. [=['
$TargetPluginRoot = 'C:\Program Files (x86)\Steam\millennium\plugins\SkyTools.Plugin'
$PluginsRoot = Split-Path -Parent $TargetPluginRoot
$SteamUiCacheRoot = 'C:\Program Files (x86)\Steam\steamui\webkit\SkyTools'
$WorkRoot = Join-Path ([IO.Path]::GetTempPath()) ('skytools-auto-update-' + [Guid]::NewGuid().ToString('N'))
$StatusPath = Join-Path ']=] .. data_root():gsub("'", "''") .. [=[' 'skytools-auto-update-status.json'
$LogPath = Join-Path ']=] .. data_root():gsub("'", "''") .. [=[' 'skytools-auto-update.log'

function Write-SkyToolsUpdateLog([string]$Message) {
  try {
    $parent = Split-Path -Parent $LogPath
    if ($parent -and !(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Add-Content -LiteralPath $LogPath -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $Message) -Encoding UTF8
  } catch {}
}

function Write-SkyToolsUpdateStatus([string]$Status, [string]$Message, [string]$RemoteVersion) {
  try {
    $parent = Split-Path -Parent $StatusPath
    if ($parent -and !(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [ordered]@{
      success = $Status -ne 'error'
      status = $Status
      message = $Message
      currentVersion = $CurrentVersion
      remoteVersion = $RemoteVersion
      updatedAt = [DateTimeOffset]::Now.ToUnixTimeSeconds()
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath $StatusPath -Encoding UTF8
  } catch {}
}

function Get-SkyToolsVersionParts([string]$Value) {
  $clean = ([string]$Value).Trim()
  if ($clean.StartsWith('v', [StringComparison]::OrdinalIgnoreCase)) { $clean = $clean.Substring(1) }
  $match = [regex]::Match($clean, '\d+(?:\.\d+){0,3}')
  if (!$match.Success) { return @() }
  $parts = @()
  foreach ($part in $match.Value.Split('.')) { $parts += [int]$part }
  while ($parts.Count -lt 4) { $parts += 0 }
  return $parts
}

function Compare-SkyToolsVersion([string]$Left, [string]$Right) {
  $leftParts = Get-SkyToolsVersionParts $Left
  $rightParts = Get-SkyToolsVersionParts $Right
  if ($leftParts.Count -eq 0 -or $rightParts.Count -eq 0) {
    return [string]::Compare($Left, $Right, $true)
  }
  for ($i = 0; $i -lt 4; $i += 1) {
    if ($leftParts[$i] -gt $rightParts[$i]) { return 1 }
    if ($leftParts[$i] -lt $rightParts[$i]) { return -1 }
  }
  return 0
}

function Remove-SkyToolsTree([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path)) { return }
  for ($attempt = 1; $attempt -le 5; $attempt += 1) {
    try {
      Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
      return
    } catch {
      if ($attempt -eq 5) { throw }
      Start-Sleep -Milliseconds (350 * $attempt)
    }
  }
}

function Get-SkyToolsCandidateFolder([string]$ExtractRoot) {
  $folders = @(Get-ChildItem -LiteralPath $ExtractRoot -Directory -Recurse -ErrorAction SilentlyContinue)
  $preferred = @($folders | Where-Object { $_.Name -eq 'SkyTools.Plugin' } | Select-Object -First 1)
  if ($preferred.Count -gt 0) { return $preferred[0] }
  $fallback = @($folders | Where-Object { $_.Name -eq 'SkyTools' } | Select-Object -First 1)
  if ($fallback.Count -gt 0) { return $fallback[0] }
  $manifestFolder = @($folders | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'plugin.json') } | Select-Object -First 1)
  if ($manifestFolder.Count -gt 0) { return $manifestFolder[0] }
  return $null
}

try {
  Write-SkyToolsUpdateStatus 'checking' 'Verificando releases do GitHub.' ''
  Write-SkyToolsUpdateLog ('Verificando update. Versao atual=' + $CurrentVersion)

  $headers = @{
    'User-Agent' = 'SkyTools.Plugin'
    'Accept' = 'application/vnd.github+json'
  }
  $release = Invoke-RestMethod -Uri ('https://api.github.com/repos/' + $Repo + '/releases/latest') -Headers $headers -UseBasicParsing
  $remoteVersion = [string]$release.tag_name
  if ([string]::IsNullOrWhiteSpace($remoteVersion)) { throw 'Release sem tag.' }

  if ((Compare-SkyToolsVersion $remoteVersion $CurrentVersion) -le 0) {
    Write-SkyToolsUpdateStatus 'current' 'SkyTools ja esta atualizado.' $remoteVersion
    Write-SkyToolsUpdateLog ('Sem update. Remoto=' + $remoteVersion)
    return
  }

  Write-SkyToolsUpdateStatus 'downloading' ('Baixando SkyTools ' + $remoteVersion + '.') $remoteVersion
  New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null
  $zipPath = Join-Path $WorkRoot 'skytools-update.zip'
  $extractRoot = Join-Path $WorkRoot 'extract'
  $asset = @($release.assets | Where-Object { $_.browser_download_url -and $_.name -match '\.zip$' } | Select-Object -First 1)
  $downloadUrl = if ($asset.Count -gt 0) { [string]$asset[0].browser_download_url } else { [string]$release.zipball_url }
  if ([string]::IsNullOrWhiteSpace($downloadUrl)) { throw 'Release sem ZIP para baixar.' }

  Invoke-WebRequest -Uri $downloadUrl -Headers @{ 'User-Agent' = 'SkyTools.Plugin' } -OutFile $zipPath -UseBasicParsing
  if (!(Test-Path -LiteralPath $zipPath) -or (Get-Item -LiteralPath $zipPath).Length -le 0) { throw 'Download do update veio vazio.' }

  Write-SkyToolsUpdateStatus 'extracting' 'Extraindo pacote do update.' $remoteVersion
  New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
  Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
  $candidate = Get-SkyToolsCandidateFolder $extractRoot
  if ($null -eq $candidate) { throw 'O ZIP nao contem pasta SkyTools.Plugin nem SkyTools.' }

  Write-SkyToolsUpdateStatus 'installing' ('Instalando SkyTools ' + $remoteVersion + '.') $remoteVersion
  if (!(Test-Path -LiteralPath $PluginsRoot)) { New-Item -ItemType Directory -Path $PluginsRoot -Force | Out-Null }
  Remove-SkyToolsTree $TargetPluginRoot
  Remove-SkyToolsTree $SteamUiCacheRoot

  $targetByCandidateName = Join-Path $PluginsRoot $candidate.Name
  Remove-SkyToolsTree $targetByCandidateName
  Copy-Item -LiteralPath $candidate.FullName -Destination $PluginsRoot -Recurse -Force

  $installedRoot = Join-Path $PluginsRoot $candidate.Name
  $installedManifest = Join-Path $installedRoot 'plugin.json'
  if (!(Test-Path -LiteralPath $installedManifest)) { throw 'Update copiado, mas plugin.json nao foi encontrado na pasta instalada.' }

  Write-SkyToolsUpdateStatus 'updated' ('SkyTools atualizado para ' + $remoteVersion + '. Reinicie a Steam para carregar a nova versao.') $remoteVersion
  Write-SkyToolsUpdateLog ('Update instalado em ' + $installedRoot)

  if ($candidate.Name -eq 'SkyTools.Plugin') {
    $newData = Join-Path $installedRoot 'data'
    New-Item -ItemType Directory -Path $newData -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $newData 'skytools-hidden-console.stop') -Value 'updated' -Encoding ASCII
  }
} catch {
  $message = $_.Exception.Message
  if (!$message) { $message = [string]$_ }
  Write-SkyToolsUpdateStatus 'error' $message ''
  Write-SkyToolsUpdateLog ('ERRO ' + $message)
} finally {
  if ($WorkRoot -and (Test-Path -LiteralPath $WorkRoot)) {
    Remove-Item -LiteralPath $WorkRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
]=]
end

local function enqueue_auto_update_check()
    local script_path = ensure_launcher("auto-update.ps1", auto_update_script())
    return run_hidden_console_powershell_file(script_path, false)
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

    local arguments = {
        "//Nologo",
        helper,
        result_path
    }
    for _, steamapps in ipairs(libraries or {}) do
        if trim(steamapps) ~= "" then
            table.insert(arguments, steamapps)
        end
    end

    local ok = run_hidden_console_process("cscript.exe", arguments)
    if not ok then
        return nil
    end

    local waited = 0
    while waited < 15000 and not is_file(result_path) do
        sleep_ms(250)
        waited = waited + 250
    end

    if not is_file(result_path) then
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
    text = text:gsub("%-%-%[%[.-%]%]", "")
    text = text:gsub("%-%-[^\r\n]*", "")
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

local function scan_installed_with_helper(directories)
    local helper = installed_helper_path()
    if not is_file(helper) then
        return nil
    end

    local result_path = job_result_path("installed")
    delete_file(result_path)

    local arguments = {
        "//Nologo",
        helper,
        result_path
    }
    for _, directory in ipairs(directories or {}) do
        if trim(directory) ~= "" then
            table.insert(arguments, directory)
        end
    end

    local ok = run_hidden_console_process("cscript.exe", arguments)
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

local function is_placeholder_app_name(name, appid)
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

local function name_cache_map()
    local map = {}
    local cache = load_name_cache()
    for key, item in pairs(cache) do
        if type(item) == "string" then
            if not is_placeholder_app_name(item, key) then
                map[tostring(key)] = trim(item)
            end
        elseif type(item) == "table" then
            local appid = get_prop(item, "AppId", "appId", key)
            local name = get_prop(item, "Name", "name", "")
            if appid ~= nil and not is_placeholder_app_name(name, appid) then
                map[tostring(appid)] = trim(name)
            end
        end
    end
    return map
end

local function save_name_cache_map(map)
    local cache = {}
    for appid, name in pairs(map or {}) do
        if not is_placeholder_app_name(name, appid) then
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

    local arguments = {
        "//Nologo",
        helper,
        result_path
    }
    for _, appid in ipairs(missing) do
        table.insert(arguments, appid)
    end

    local ok = run_hidden_console_process("cscript.exe", arguments)
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
    return is_placeholder_app_name(name, appid)
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
    local cached = cache_get("installed", 45)
    if cached ~= nil then
        log_info("SkyToolsInstalled usando cache: " .. tostring(#cached))
        return cached
    end

    local now = os.time()
    if tonumber(runtime.installed_scan_until or 0) > now then
        local indexed = load_installed_index()
        if #indexed > 0 then
            log_info("SkyToolsInstalled usando indice durante scan ativo: " .. tostring(#indexed))
            return cache_set("installed", indexed, 20)
        end
    end

    runtime.installed_scan_until = now + 20

    local index_items = scan_installed_with_helper(script_directories()) or {}
    if #index_items > 0 then
        log_info("SkyToolsInstalled helper oculto retornou: " .. tostring(#index_items))
    else
        index_items = load_installed_index()
        log_info("SkyToolsInstalled usando indice persistido: " .. tostring(#index_items))
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

    local missing_appids = {}
    for _, script in ipairs(scripts) do
        local id = tostring(tonumber(script.appId or script.appid or 0) or 0)
        local metadata = steam_game_metadata(id)
        local manifest_name = metadata ~= nil and trim(metadata.gameName or metadata.name) or ""
        if manifest_name == "" and trim(names[id]) == "" and trim(record_names[id]) == "" then
            table.insert(missing_appids, id)
        end
    end
    names = resolve_missing_names(missing_appids, names)

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
        script.gameName = manifest_name ~= "" and manifest_name or names[id] or record_names[id] or "AppID " .. id
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
    runtime.installed_scan_until = 0
    return cache_set("installed", scripts, 45)
end

local function cached_installed_count()
    local cached = cache_get("installed", 45)
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

local function theme_display_name(id)
    id = trim(id)
    if id == "official-orange" then
        return "Oficial laranja"
    end
    if id == "ocean-cyan" then
        return "Oceano ciano"
    end
    if id == "graphite-lime" then
        return "Grafite lima"
    end
    if id == "ruby-ember" then
        return "Rubi brasa"
    end
    if id == "pink-rose" then
        return "Rosa Shock"
    end
    local name = id:gsub("[%-_]+", " ")
    return (name:gsub("^%l", string.upper))
end

local function list_theme_files()
    local themes_dir = join_path(join_path(plugin_dir(), "public"), "themes")
    local themes = {}
    local seen = {}
    local function add_theme(file_name)
        file_name = trim(file_name)
        if file_name:match("^[%w%._%- ]+%.css$") == nil then
            return
        end
        local id = file_name:gsub("%.css$", "")
        if seen[id] then
            return
        end
        seen[id] = true
        table.insert(themes, { id = id, name = theme_display_name(id), file = file_name })
    end

    add_theme("official-orange.css")
    add_theme("ocean-cyan.css")
    add_theme("graphite-lime.css")
    add_theme("ruby-ember.css")
    add_theme("pink-rose.css")
    if fs_ok and fs ~= nil and fs.list ~= nil then
        local ok, entries = pcall(fs.list, themes_dir)
        if ok and type(entries) == "table" then
            for _, entry in ipairs(entries) do
                add_theme(tostring(entry):match("[^\\/]+$") or tostring(entry))
            end
        end
    end

    table.sort(themes, function(left, right)
        if left.id == "official-orange" then
            return true
        end
        if right.id == "official-orange" then
            return false
        end
        return tostring(left.name) < tostring(right.name)
    end)
    return themes
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
        preferredApi = canonical_preferred_api_id(get_prop(settings, "PreferredDownloadApi", "preferredDownloadApi", "Automatic")),
        hasMorrenusKey = trim(get_prop(settings, "MorrenusApiKey", "morrenusApiKey", "")) ~= "",
        pluginId = get_prop(payload, "pluginId", "pluginId", PLUGIN_ID),
        injection = runtime.last_injection,
        browserJsId = runtime.browser_js_id,
        browserCssId = runtime.browser_css_id,
        themes = list_theme_files(),
        defaultTheme = "official-orange",
        selectedThemeId = trim(get_prop(settings, "SelectedThemeId", "selectedThemeId", "ThemeId", "themeId", "")),
        selectedLanguageId = canonical_language_id(get_prop(settings, "SelectedLanguage", "selectedLanguage", "Language", "language", "auto")) or "auto",
        fsAvailable = fs_ok and fs ~= nil,
        fsListAvailable = fs_ok and fs ~= nil and fs.list ~= nil,
        backendMode = "lua-hidden-console-worker",
        hiddenConsole = read_json(hidden_console_state_path(), {}),
        autoUpdate = read_json(auto_update_status_path(), {})
    }
end

local function save_theme_direct(payload)
    payload = normalize_payload(payload or {})
    local theme_id = trim(get_prop(payload, "themeId", "ThemeId", "id", "Id", "theme", "Theme", ""))
    if theme_id == "" or theme_id:match("^[%w%._%- ]+$") == nil then
        return { success = false, error = "Tema inválido." }
    end

    local exists = false
    for _, theme in ipairs(list_theme_files()) do
        if tostring(theme.id or "") == theme_id then
            exists = true
            break
        end
    end
    if not exists then
        return { success = false, error = "Tema não encontrado." }
    end

    local settings = load_settings()
    settings.SelectedThemeId = theme_id
    if not write_json(settings_path(), settings) then
        return { success = false, error = "Não foi possível salvar o tema." }
    end
    cache_clear()
    return { themeId = theme_id }
end

local function theme_direct(payload)
    payload = payload or {}
    local requested_id = trim(get_prop(payload, "id", "themeId", "ThemeId", "theme", "Theme", ""))
    local requested_file = trim(get_prop(payload, "file", "File", "filename", "Filename", ""))
    if requested_file == "" and requested_id ~= "" then
        requested_file = requested_id .. ".css"
    end
    if requested_file:match("^[%w%._%- ]+%.css$") == nil then
        return { success = false, error = "Tema inválido." }
    end

    local themes_dir = join_path(join_path(plugin_dir(), "public"), "themes")
    local css = read_file(join_path(themes_dir, requested_file))
    if css == nil or css == "" then
        return { success = false, error = "Tema não encontrado.", data = { fallbackTheme = "official-orange" } }
    end

    local id = requested_file:gsub("%.css$", "")
    return {
        id = id,
        name = theme_display_name(id),
        file = requested_file,
        css = css
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
        local override_name = trim(get_prop(override, "name", "Name", ""))
        if override_name == "" or (id == "ryzen" and override_name:lower() == "sushi") then
            override_name = name
        end
        return {
            id = id,
            name = override_name,
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
        preferred = canonical_preferred_api_id(get_prop(settings, "PreferredDownloadApi", "preferredDownloadApi", "Automatic")),
        morrenusApiKey = trim(get_prop(settings, "MorrenusApiKey", "morrenusApiKey", "")),
        apiOrder = clean_api_order(api_order, custom, nil),
        builtIn = {
            native_api("skyapi", "SkyAPI", false, "https://raw.githubusercontent.com/skyflarefox/Skyapi/main/<appid>.zip"),
            native_api("morrenus", "Morrenus", true, "https://hubcapmanifest.com/api/v1/manifest/<appid>?api_key=<moapikey>"),
            native_api("ryzen", "RyzenAPI", false, "https://raw.githubusercontent.com/MalucoPlayGamer/RyzenAPI/main/<appid>.zip")
        },
        custom = custom
    }
end

function clean_api_order(order, custom, include_id)
    local allowed = native_api_ids()
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
        local key = canonical_api_id(id)
        if key ~= id:lower() then
            id = key
        end
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
        return { success = false, error = "AppID inválido." }
    end

    local steam_path = detect_steam_path()
    if steam_path == "" then
        return { success = false, error = "Steam não encontrada." }
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
    payload = normalize_payload(payload)
    local settings = load_settings()
    local custom = get_prop(settings, "CustomManifestApis", "customManifestApis", {})
    if type(custom) ~= "table" or not is_array(custom) then
        custom = {}
    end
    local native_ids = native_api_ids()

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
    local lower_id = canonical_api_id(api.id)

    if api.name == "" then
        return { success = false, error = "Informe um nome para a API. Payload recebido: " .. payload_debug_keys(payload) }
    end
    if api.urlTemplate == "" or api.urlTemplate:find("<appid>", 1, true) == nil then
        return { success = false, error = "A URL da API precisa conter <appid>." }
    end
    if api.id == "" then
        api.id = "skytools-" .. tostring(os.time())
        lower_id = api.id:lower()
    end

    if native_ids[lower_id] == true then
        api.id = lower_id
        if lower_id == "ryzen" and api.name:lower() == "sushi" then
            api.name = "RyzenAPI"
        end
        local native_overrides = get_prop(settings, "NativeManifestApis", "nativeManifestApis", {})
        local disabled_api_ids = get_prop(settings, "DisabledApiIds", "disabledApiIds", {})
        if type(native_overrides) ~= "table" then
            native_overrides = {}
        end
        if type(disabled_api_ids) ~= "table" then
            disabled_api_ids = {}
        end

        native_overrides[lower_id] = api
        native_overrides.sushi = nil
        native_overrides.Sushi = nil
        settings.NativeManifestApis = native_overrides
        if lower_id == "morrenus" then
            settings.MorrenusApiKey = api.apiKey
        end

        local kept_disabled = {}
        for _, id in ipairs(disabled_api_ids) do
            local disabled_id = tostring(id):lower()
            if disabled_id ~= lower_id and disabled_id ~= "sushi" then
                table.insert(kept_disabled, id)
            end
        end
        if api.enabled == false then
            table.insert(kept_disabled, lower_id)
        end
        settings.DisabledApiIds = kept_disabled
        settings.ApiOrder = clean_api_order(get_prop(settings, "ApiOrder", "apiOrder", DEFAULT_API_ORDER), custom, lower_id)
        if not write_json(settings_path(), settings) then
            return { success = false, error = "Não foi possível gravar settings.json." }
        end
        cache_clear()
        return api
    end

    local replaced = false
    for index, item in ipairs(custom) do
        if type(item) == "table" and trim(get_prop(item, "id", "Id", "")):lower() == api.id:lower() then
            api.id = trim(get_prop(item, "id", "Id", api.id))
            custom[index] = api
            replaced = true
        end
    end
    if not replaced then
        table.insert(custom, api)
    end

    settings.CustomManifestApis = custom
    settings.ApiOrder = clean_api_order(get_prop(settings, "ApiOrder", "apiOrder", DEFAULT_API_ORDER), custom, api.id)
    if not write_json(settings_path(), settings) then
        return { success = false, error = "Não foi possível gravar settings.json." }
    end
    cache_clear()
    return api
end

local function save_api_settings_direct(payload)
    payload = normalize_payload(payload)
    local settings = load_settings()
    local preferred = trim(get_first_prop(payload, { "preferred", "preferredApi", "PreferredDownloadApi", "preferredDownloadApi" }, ""))
    local morrenus_key = trim(get_prop(payload, "morrenusApiKey", "MorrenusApiKey", ""))
    local api_order = get_first_prop(payload, { "apiOrder", "ApiOrder", "order", "Order", "apiOrderText", "ApiOrderText", "orderText" }, nil)
    local selected_theme = trim(get_first_prop(payload, { "selectedThemeId", "SelectedThemeId", "themeId", "ThemeId", "theme", "Theme" }, ""))
    local selected_language = trim(get_first_prop(payload, { "selectedLanguage", "SelectedLanguage", "language", "Language", "languageId", "LanguageId" }, ""))
    local changed_without_api_order = false
    if api_order == nil and type(payload) == "table" and is_array(payload) then
        api_order = payload
    end
    if preferred ~= "" then
        settings.PreferredDownloadApi = canonical_preferred_api_id(preferred)
        changed_without_api_order = true
    end
    if morrenus_key ~= "" then
        settings.MorrenusApiKey = morrenus_key
        changed_without_api_order = true
    end
    if selected_theme ~= "" then
        if selected_theme:match("^[%w%._%- ]+$") == nil then
            return { success = false, error = "Tema inválido." }
        end
        settings.SelectedThemeId = selected_theme
        changed_without_api_order = true
    end
    if selected_language ~= "" then
        local language_id = canonical_language_id(selected_language)
        if language_id == nil then
            return { success = false, error = "Idioma inválido." }
        end
        settings.SelectedLanguage = language_id
        changed_without_api_order = true
    end
    local custom = get_prop(settings, "CustomManifestApis", "customManifestApis", {})
    if type(custom) ~= "table" or not is_array(custom) then
        custom = {}
    end
    if type(api_order) == "table" or type(api_order) == "string" then
        settings.ApiOrder = clean_api_order(api_order, custom, nil)
    else
        if not changed_without_api_order then
            return { success = false, error = "Ordem das APIs não recebida pelo backend." }
        end
    end
    if not write_json(settings_path(), settings) then
        return { success = false, error = "Não foi possível gravar settings.json." }
    end
    local saved_settings = read_json(settings_path(), {})
    if type(api_order) == "table" or type(api_order) == "string" then
        local saved_order = clean_api_order(get_prop(saved_settings, "ApiOrder", "apiOrder", {}), custom, nil)
        if not same_string_array(saved_order, settings.ApiOrder) then
            return { success = false, error = "A ordem das APIs não foi persistida em settings.json." }
        end
    end
    if selected_theme ~= "" and trim(get_prop(saved_settings, "SelectedThemeId", "selectedThemeId", "")) ~= selected_theme then
        return { success = false, error = "O tema não foi persistido em settings.json." }
    end
    if selected_language ~= "" and (canonical_language_id(get_prop(saved_settings, "SelectedLanguage", "selectedLanguage", "auto")) or "auto") ~= (canonical_language_id(selected_language) or "") then
        return { success = false, error = "O idioma não foi persistido em settings.json." }
    end
    cache_clear()
    return apis_direct()
end

local function delete_api_direct(payload)
    payload = normalize_payload(payload)
    local id = trim(get_prop(payload, "id", "Id", "query", "name", "Name", ""))
    local settings = load_settings()
    local lower_id = canonical_api_id(id)
    if lower_id == "morrenus" or lower_id == "ryzen" or lower_id == "skyapi" then
        local disabled_api_ids = get_prop(settings, "DisabledApiIds", "disabledApiIds", {})
        local native_overrides = get_prop(settings, "NativeManifestApis", "nativeManifestApis", {})
        if type(disabled_api_ids) ~= "table" then
            disabled_api_ids = {}
        end
        if type(native_overrides) ~= "table" then
            native_overrides = {}
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
        native_overrides.sushi = nil
        native_overrides.Sushi = nil
        settings.NativeManifestApis = native_overrides
        settings.DisabledApiIds = disabled_api_ids
        settings.ApiOrder = clean_api_order(get_prop(settings, "ApiOrder", "apiOrder", DEFAULT_API_ORDER), get_prop(settings, "CustomManifestApis", "customManifestApis", {}), nil)
        if not write_json(settings_path(), settings) then
            return { success = false, error = "Não foi possível gravar settings.json." }
        end
        cache_clear()
        return { id = lower_id, disabled = true }
    end

    local custom = get_prop(settings, "CustomManifestApis", "customManifestApis", {})
    local kept = {}
    local removed_name = ""
    if type(custom) == "table" and is_array(custom) then
        for _, item in ipairs(custom) do
            if type(item) ~= "table" or trim(get_prop(item, "id", "Id", "")):lower() ~= id:lower() then
                table.insert(kept, item)
            else
                removed_name = trim(get_prop(item, "name", "Name", ""))
            end
        end
    end
    settings.CustomManifestApis = kept
    settings.ApiOrder = clean_api_order(get_prop(settings, "ApiOrder", "apiOrder", DEFAULT_API_ORDER), kept, nil)
    local preferred = trim(get_prop(settings, "PreferredDownloadApi", "preferredDownloadApi", "Automatic"))
    preferred = canonical_preferred_api_id(preferred)
    if preferred:lower() == id:lower() or (removed_name ~= "" and preferred:lower() == removed_name:lower()) then
        settings.PreferredDownloadApi = "Automatic"
    end
    if not write_json(settings_path(), settings) then
        return { success = false, error = "Não foi possível gravar settings.json." }
    end
    cache_clear()
    return { id = id, removed = true }
end

local app_operation_key
local run_wscript_installer

local function installer_result_path(appid)
    return job_result_path("add-" .. tostring(appid))
end

local function finalize_wscript_installer_result(appid, result_path)
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
        return { success = false, error = "Backup inválido." }
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
        return { success = false, error = "AppID inválido.", details = "Payload recebido: " .. json_encode(payload) }
    end

    local installer = installer_path()
    if not is_file(installer) then
        return { success = false, error = "Instalador interno não encontrado: " .. installer }
    end

    local steam_path = detect_steam_path()
    if steam_path == "" then
        return { success = false, error = "Steam não encontrada." }
    end

    local settings = load_settings()
    local root = data_root()

    local app_name = resolve_game_name_for_appid(appid, get_prop(payload, "name", "gameName", ""))
    if is_placeholder_game_name(app_name, appid) then
        local resolved = resolve_missing_names({ tostring(appid) }, name_cache_map())
        if type(resolved) == "table" and not is_placeholder_game_name(resolved[tostring(appid)], appid) then
            app_name = trim(resolved[tostring(appid)])
        end
    end

    local result_path = installer_result_path(appid)
    delete_file(result_path)

    local preferred = canonical_preferred_api_id(get_prop(settings, "PreferredDownloadApi", "preferredDownloadApi", "Automatic"))
    local morrenus_key = trim(get_prop(settings, "MorrenusApiKey", "morrenusApiKey", ""))
    local morrenus_arg = morrenus_key
    if morrenus_arg == "" then
        morrenus_arg = "-"
    end

    local arguments = {
        "//Nologo",
        installer,
        root,
        steam_path,
        active_script_directory(),
        tostring(appid),
        app_name,
        preferred,
        morrenus_arg,
        result_path
    }

    log_info("SkyTools installer iniciado para appid=" .. tostring(appid))
    local ok = run_hidden_console_process("cscript.exe", arguments)
    local exec_result = ""
    if not ok then
        return {
            success = false,
            error = "Não foi possível iniciar o instalador interno. Verifique se o Windows Script Host está habilitado."
        }
    end

    if payload.__async == true then
        return {
            pending = true,
            operation = "add-game",
            appId = tonumber(appid) or appid,
            message = "Instalação iniciada no console oculto."
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
            error = "O instalador interno não respondeu a tempo.",
            details = tostring(exec_result or "")
        }
    end

    return finalize_wscript_installer_result(appid, result_path)
end

local function add_game_result_direct(payload)
    payload = normalize_payload(payload)
    local appid = payload_appid(payload)
    if appid == nil or appid <= 0 then
        return { success = false, error = "AppID inválido." }
    end

    local result_path = installer_result_path(appid)
    if not is_file(result_path) then
        local active = runtime.operations[app_operation_key({ appid = appid })]
        if type(active) == "table" and tonumber(active.expiresAt or 0) <= os.time() then
            runtime.operations[app_operation_key({ appid = appid })] = nil
            return { success = false, error = "O instalador interno não respondeu a tempo." }
        end
        return {
            pending = true,
            operation = "add-game",
            appId = tonumber(appid) or appid,
            message = "Instalador ainda em execução."
        }
    end

    local result = finalize_wscript_installer_result(appid, result_path)
    delete_file(result_path)
    runtime.operations[app_operation_key({ appid = appid })] = nil
    return result
end

local function ps_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

local function repair_script_path(kind)
    return join_path(data_root(), "skytools-repair-" .. tostring(kind or "task") .. ".ps1")
end

local function launch_elevated_powershell(script_path)
    return run_hidden_console_powershell_file(script_path, true)
end

local function run_powershell_script(script_path)
    return run_hidden_console_powershell_file(script_path, false)
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
        message = "DNS Cloudflare iniciado. Confirme a permissão do Windows se aparecer."
    elseif repair == "error54" then
        if steam_path == "" then
            return { success = false, error = "Steam não encontrada." }
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
        message = "Instalador Visual C++ iniciado. Confirme a permissão do Windows se aparecer."
    else
        return { success = false, error = "Reparo desconhecido: " .. tostring(repair) }
    end

    local path = repair_script_path(repair)
    write_file(path, script)
    local ok = elevated and launch_elevated_powershell(path) or run_powershell_script(path)
    if not ok then
        return { success = false, error = "Não foi possível iniciar o reparo externo." }
    end
    return { success = true, data = { repair = repair, scriptPath = path, elevated = elevated, message = message }, error = "" }
end

local function find_fix_sources_direct(payload)
    payload = normalize_payload(payload)
    local appid = tostring(payload_appid(payload))
    local name = resolve_game_name_for_appid(appid, get_prop(payload, "name", "gameName", appid))
    local game_path = trim(get_prop(payload, "gamePath", "installPath", ""))
    local requested_kind = trim(get_prop(payload, "kind", "type", ""))
    if game_path == "" then
        game_path = steam_game_install_path(appid)
    end
    local sources = {}

    local helper = fixes_helper_path()
    if is_file(helper) then
        local result_path = job_result_path("fixes-" .. appid)
        delete_file(result_path)
        run_hidden_console_process("cscript.exe", {
            "//Nologo",
            helper,
            result_path,
            appid,
            name,
            requested_kind
        })
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
            source.provider = trim(get_prop(source, "provider", "Provider", "Sky"))
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
        return find_fix_sources_direct({ appid = appid, name = name, kind = "online" })
    end
    if kind == "denuvo" then
        return { gamePath = "", sources = {} }
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

local function sky_fix_file_name(appid, source, payload)
    local source_file = trim(get_first_prop(source, { "fileName", "filename", "FileName", "file", "File" }, ""))
    if archive_extension(source_file) ~= "" then
        return source_file
    end

    local payload_file = trim(get_first_prop(payload, { "fileName", "filename", "sourceFileName", "SourceFileName" }, ""))
    if archive_extension(payload_file) ~= "" then
        return payload_file
    end

    local source_name = trim(get_first_prop(source, { "name", "title" }, get_prop(payload, "sourceName", "")))
    if archive_extension(source_name) ~= "" then
        return source_name
    end

    local kind = trim(get_first_prop(source, { "kind", "type", "Type" }, get_prop(payload, "sourceKind", "sourceType", ""))):lower()
    local label = trim(get_first_prop(source, { "displayName", "DisplayName", "name", "title" }, get_first_prop(payload, { "displayName", "sourceName" }, ""))):lower()
    if kind == "" then
        kind = label
    end
    if kind:find("online", 1, true) ~= nil then
        return tostring(appid) .. "_online.zip"
    end
    if kind:find("generic", 1, true) ~= nil or kind:find("generica", 1, true) ~= nil or kind:find("genérica", 1, true) ~= nil then
        return tostring(appid) .. "_generic.zip"
    end

    return ""
end

local cleanup_fix_residuals

local function apply_fix_result_path(appid)
    return job_result_path("apply-fix-" .. tostring(appid))
end

local function apply_fix_meta_path(appid)
    return job_result_path("apply-fix-" .. tostring(appid) .. "-meta")
end

local function finalize_apply_fix_result(appid, apply_result, meta)
    meta = type(meta) == "table" and meta or {}
    local name = trim(get_prop(meta, "name", "Name", tostring(appid)))
    local source = get_prop(meta, "source", "Source", {})
    local url = trim(get_prop(meta, "url", "Url", ""))
    local source_type = trim(get_prop(meta, "type", "Type", "Fix"))
    local source_provider = trim(get_prop(meta, "provider", "Provider", "Sky"))
    local game_path = trim(get_prop(meta, "gamePath", "GamePath", ""))

    if type(apply_result) ~= "table" then
        cleanup_fix_residuals(appid)
        return { success = false, error = "Não foi possível ler o resultado da aplicação da correção." }
    end
    if apply_result.success ~= true then
        cleanup_fix_residuals(appid)
        return { success = false, error = trim(get_prop(apply_result, "error", "Error", "")) ~= "" and trim(get_prop(apply_result, "error", "Error", "")) or "Não foi possível aplicar a correção." }
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
        provider = source_provider,
        gamePath = game_path,
        createdAt = os.date("%Y-%m-%dT%H:%M:%S")
    })
    write_json(records_path, records)

    return {
        appId = tonumber(appid) or appid,
        name = name,
        url = url,
        type = source_type,
        provider = source_provider,
        gamePath = game_path,
        message = "Correção Sky Aplicada."
    }
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
            source.provider = trim(get_first_prop(source, { "provider" }, get_prop(payload, "provider", "Sky")))
            source.size = trim(get_first_prop(source, { "size" }, get_prop(payload, "size", "")))
        end
    end
    if url == "" then
        local requested_kind = ""
        local inferred_file = sky_fix_file_name(appid, source, payload)
        local inferred_lower = inferred_file:lower()
        if inferred_lower == appid .. "_online.zip" then
            requested_kind = "online"
        elseif inferred_lower == appid .. "_generic.zip" then
            requested_kind = "generic"
        end

        local lookup = find_fix_sources_direct({ appid = appid, name = name, kind = requested_kind })
        local found = type(lookup) == "table" and lookup.sources or nil
        if type(found) == "table" then
            for _, item in ipairs(found) do
                local candidate_url = trim(get_first_prop(item, { "downloadUrl", "DownloadUrl", "sourceUrl", "SourceUrl", "url", "Url", "href", "link" }, ""))
                if candidate_url ~= "" and archive_extension(candidate_url) ~= "" then
                    source = item
                    url = candidate_url
                    if game_path == "" then
                        game_path = trim(get_prop(item, "gamePath", "installPath", ""))
                    end
                    break
                end
            end
        end
    end
    if url == "" then
        return { success = false, error = "Fonte sem link para abrir. Nenhum pacote Sky encontrado para AppID " .. appid .. "." }
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
            error = "Aplicação automática suporta apenas pacotes .zip, .rar e .7z.",
            url = url
        }
    end
    if game_path == "" then
        return { success = false, error = "Pasta instalada do jogo não encontrada." }
    end

    local script_path = join_path(data_root(), "skytools-apply-fix-" .. appid .. ".ps1")
    local package_path = join_path(data_root(), "skytools-fix-" .. appid .. "." .. extension)
    local extract_path = join_path(data_root(), "skytools-fix-" .. appid .. "-extract")
    local result_path = apply_fix_result_path(appid)
    local meta_path = apply_fix_meta_path(appid)
    delete_file(script_path)
    delete_file(package_path)
    delete_file(result_path)
    delete_file(meta_path)
    local source_type = trim(get_prop(source, "type", "Type", "Fix"))
    local source_provider = trim(get_prop(source, "provider", "Provider", "Sky"))
    local script = table.concat({
        "$ErrorActionPreference = 'Stop'",
        "$downloadFinished = $false",
        "$antivirusMessage = 'Não foi possível concluir a operação com êxito porque o Antivírus deletou a correção.'",
        "function Write-SkyToolsResult([bool]$success, [string]$message, [int]$files) {",
        "  $result = [ordered]@{ success = $success; error = $message; files = $files } | ConvertTo-Json -Compress",
        "  Set-Content -LiteralPath " .. ps_quote(result_path) .. " -Value $result -Encoding UTF8",
        "}",
        "function Assert-PackageAvailable {",
        "  if (!(Test-Path -LiteralPath $package)) { throw $antivirusMessage }",
        "  $packageItem = Get-Item -LiteralPath $package -ErrorAction SilentlyContinue",
        "  if (!$packageItem -or $packageItem.Length -le 0) { throw 'Não foi possível concluir a operação com êxito porque o Antivírus deletou a correção.' }",
        "}",
        "try {",
        "  $url = " .. ps_quote(url),
        "  $gamePath = " .. ps_quote(game_path),
        "  $package = " .. ps_quote(package_path),
        "  $extract = " .. ps_quote(extract_path),
        "  $appliedCount = 0",
        "  if (!(Test-Path -LiteralPath $gamePath)) { throw 'Pasta do jogo não encontrada.' }",
        "  Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue",
        "  Remove-Item -LiteralPath $package -Force -ErrorAction SilentlyContinue",
        "  New-Item -ItemType Directory -Path (Split-Path -Parent $package) -Force | Out-Null",
        "  New-Item -ItemType Directory -Path $extract -Force | Out-Null",
        "  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12",
        "  Import-Module BitsTransfer -ErrorAction Stop",
        "  Start-BitsTransfer -Source $url -Destination $package -TransferType Download",
        "  $downloadFinished = $true",
        "  Assert-PackageAvailable",
        "  $ext = [IO.Path]::GetExtension($package).ToLowerInvariant()",
        "  function Expand-FixArchive {",
        "    Assert-PackageAvailable",
        "    if ($ext -eq '.zip') {",
        "      try { Expand-Archive -LiteralPath $package -DestinationPath $extract -Force; return } catch { throw }",
        "    }",
        "    $tar = (Get-Command tar.exe -ErrorAction SilentlyContinue).Source",
        "    if ($tar) {",
        "      Assert-PackageAvailable",
        "      & $tar -xf $package -C $extract",
        "      if ($LASTEXITCODE -eq 0) { return }",
        "    }",
        "    $candidates = @(",
        "      (Join-Path $env:ProgramFiles '7-Zip\\7z.exe'),",
        "      (Join-Path ${env:ProgramFiles(x86)} '7-Zip\\7z.exe'),",
        "      (Join-Path (Split-Path -Parent $package) '7z.exe')",
        "    )",
        "    $seven = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1",
        "    if (!$seven) { throw 'Não foi possível extrair o pacote. Instale o 7-Zip ou use Windows com tar.exe/libarchive.' }",
        "    & $seven x $package ('-o' + $extract) -y | Out-Null",
        "    if ($LASTEXITCODE -ne 0) { throw '7-Zip não conseguiu extrair o pacote.' }",
        "  }",
        "  Expand-FixArchive",
        "  $sourceRoot = $extract",
        "  $gameRoot = [IO.Path]::GetFullPath($gamePath).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar",
        "  $sourceRootFull = [IO.Path]::GetFullPath($sourceRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar",
        "  $files = Get-ChildItem -LiteralPath $sourceRoot -File -Recurse",
        "  if (!$files -or $files.Count -eq 0) { throw 'Pacote de correção vazio.' }",
        "  foreach ($file in $files) {",
        "    $fileFull = [IO.Path]::GetFullPath($file.FullName)",
        "    if (!$fileFull.StartsWith($sourceRootFull, [StringComparison]::OrdinalIgnoreCase)) { continue }",
        "    $relative = $fileFull.Substring($sourceRootFull.Length)",
        "    $dest = [IO.Path]::GetFullPath((Join-Path $gameRoot $relative))",
        "    if (!$dest.StartsWith($gameRoot, [StringComparison]::OrdinalIgnoreCase)) { continue }",
        "    New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null",
        "    Copy-Item -LiteralPath $file.FullName -Destination $dest -Force",
        "    $appliedCount += 1",
        "  }",
        "  Write-SkyToolsResult $true '' $appliedCount",
        "} catch {",
        "  $message = $_.Exception.Message",
        "  if ($downloadFinished -and !(Test-Path -LiteralPath $package)) { $message = $antivirusMessage }",
        "  if (!$message) { $message = [string]$_ }",
        "  Write-SkyToolsResult $false $message 0",
        "} finally {",
        "  Remove-Item -LiteralPath " .. ps_quote(extract_path) .. " -Recurse -Force -ErrorAction SilentlyContinue",
        "  Remove-Item -LiteralPath " .. ps_quote(package_path) .. " -Force -ErrorAction SilentlyContinue",
        "  if ($PSCommandPath) { Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue }",
        "}"
    }, "\r\n")
    write_file(script_path, script)
    local ok = run_powershell_script(script_path)
    if not ok then
        return { success = false, error = "Não foi possível iniciar a aplicação da correção." }
    end

    if payload.__async == true then
        write_json(meta_path, {
            appId = tonumber(appid) or appid,
            name = name,
            source = source,
            url = url,
            type = source_type,
            provider = source_provider,
            gamePath = game_path,
            createdAt = os.date("%Y-%m-%dT%H:%M:%S")
        })
        return {
            pending = true,
            operation = "apply-fix",
            appId = tonumber(appid) or appid,
            message = "Aplicação iniciada no console oculto."
        }
    end

    local waited = 0
    while waited < 900000 and not is_file(result_path) do
        sleep_ms(500)
        waited = waited + 500
    end
    if not is_file(result_path) then
        cleanup_fix_residuals(appid)
        return { success = false, error = "A aplicação da correção não respondeu a tempo." }
    end
    local apply_result = read_json(result_path, nil)
    delete_file(result_path)
    return finalize_apply_fix_result(appid, apply_result, {
        name = name,
        source = source,
        url = url,
        type = source_type,
        provider = source_provider,
        gamePath = game_path
    })
end

local function apply_fix_result_direct(payload)
    payload = normalize_payload(payload)
    local appid = payload_appid(payload)
    if appid == nil or appid <= 0 then
        return { success = false, error = "AppID inválido." }
    end

    local result_path = apply_fix_result_path(appid)
    if not is_file(result_path) then
        local active = runtime.operations[app_operation_key({ appid = appid })]
        if type(active) == "table" and tonumber(active.expiresAt or 0) <= os.time() then
            runtime.operations[app_operation_key({ appid = appid })] = nil
            cleanup_fix_residuals(appid)
            return { success = false, error = "A aplicação da correção não respondeu a tempo." }
        end
        return {
            pending = true,
            operation = "apply-fix",
            appId = tonumber(appid) or appid,
            message = "Aplicação ainda em execução."
        }
    end

    local apply_result = read_json(result_path, nil)
    local meta_path = apply_fix_meta_path(appid)
    local meta = read_json(meta_path, {})
    delete_file(result_path)
    delete_file(meta_path)
    runtime.operations[app_operation_key({ appid = appid })] = nil
    return finalize_apply_fix_result(appid, apply_result, meta)
end

function cleanup_fix_residuals(appid)
    local root = data_root()
    local id = tostring(appid or "")
    if id == "" then
        return
    end

    delete_file(join_path(root, "skytools-apply-fix-" .. id .. ".ps1"))
    delete_file(join_path(root, "skytools-fix-" .. id .. ".zip"))
    delete_file(join_path(root, "skytools-fix-" .. id .. ".rar"))
    delete_file(join_path(root, "skytools-fix-" .. id .. ".7z"))

    local extract_path = join_path(root, "skytools-fix-" .. id .. "-extract")
    local backup_path = join_path(root, "fix-backups\\" .. id)
    local cleanup_script = join_path(root, "skytools-cleanup-fix-" .. id .. ".ps1")
    write_file(cleanup_script, table.concat({
        "$ErrorActionPreference = 'SilentlyContinue'",
        "Remove-Item -LiteralPath " .. ps_quote(extract_path) .. " -Recurse -Force -ErrorAction SilentlyContinue",
        "Remove-Item -LiteralPath " .. ps_quote(backup_path) .. " -Recurse -Force -ErrorAction SilentlyContinue",
        "if ($PSCommandPath) { Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue }"
    }, "\r\n"))
    run_powershell_script(cleanup_script)
end

local function remove_fix_direct(payload)
    payload = normalize_payload(payload)
    local appid = tostring(payload_appid(payload))
    if appid == "" or appid == "0" then
        return { success = false, error = "AppID inválido para remover correção." }
    end

    cleanup_fix_residuals(appid)

    local records_path = join_path(data_root(), "fix-actions.json")
    local records = read_json(records_path, {})
    local kept = {}
    local removed = 0
    if type(records) == "table" then
        for _, record in ipairs(records) do
            if type(record) == "table" and tostring(get_prop(record, "appId", "appid", "AppId", "")) == appid then
                removed = removed + 1
            else
                table.insert(kept, record)
            end
        end
    end
    write_json(records_path, kept)

    return {
        appId = tonumber(appid) or appid,
        removed = removed,
        validateUrl = "steam://validate/" .. appid,
        message = "Registro da correção removido. Verificação da integridade iniciada pela Steam."
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

function app_operation_key(payload)
    local appid = payload_appid(payload)
    if appid == nil or appid <= 0 then
        return ""
    end
    return "appid:" .. tostring(appid)
end

local function with_app_operation_lock(payload, label, callback)
    local key = app_operation_key(payload)
    if key == "" then
        return callback()
    end

    local now = os.time()
    local active = runtime.operations[key]
    if type(active) == "table" and tonumber(active.expiresAt or 0) > now then
        return {
            success = false,
            error = "Já existe uma operação em andamento para este jogo. Aguarde terminar antes de tentar novamente."
        }
    end

    runtime.operations[key] = {
        label = tostring(label or "operação"),
        expiresAt = now + 900
    }
    local ok, result = pcall(callback)
    runtime.operations[key] = nil
    if ok then
        return result
    end
    return { success = false, error = tostring(result or "Falha durante a operação.") }
end

local function dispatch_inline(method, payload)
    payload = payload or {}
    if method == "status" then return response_from_result(status_direct(payload)) end
    if method == "save-theme" then return response_from_result(save_theme_direct(payload)) end
    if method == "theme" then return response_from_result(theme_direct(payload)) end
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
        local result = with_app_operation_lock(payload, "remove-game", function()
            return remove_game_direct(payload)
        end)
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
        local key = app_operation_key(payload)
        local now = os.time()
        local active = key ~= "" and runtime.operations[key] or nil
        if type(active) == "table" and tonumber(active.expiresAt or 0) > now then
            return response_from_result({ success = false, error = "Já existe uma operação em andamento para este jogo. Aguarde terminar antes de tentar novamente." })
        end
        if key ~= "" then
            runtime.operations[key] = { label = "apply-fix", expiresAt = now + 900 }
        end
        payload.__async = true
        local result = apply_fix_direct(payload)
        if not (type(result) == "table" and result.pending == true) and key ~= "" then
            runtime.operations[key] = nil
        end
        return response_from_result(result)
    end
    if method == "apply-fix-result" then return response_from_result(apply_fix_result_direct(payload)) end
    if method == "remove-fix" then
        local result = with_app_operation_lock(payload, "remove-fix", function()
            return remove_fix_direct(payload)
        end)
        return response_from_result(result)
    end
    if method == "integration" then return response_from_result(integration_direct(payload)) end
    if method == "add-game" then
        local key = app_operation_key(payload)
        local now = os.time()
        local active = key ~= "" and runtime.operations[key] or nil
        if type(active) == "table" and tonumber(active.expiresAt or 0) > now then
            return response_from_result({ success = false, error = "Já existe uma operação em andamento para este jogo. Aguarde terminar antes de tentar novamente." })
        end
        if key ~= "" then
            runtime.operations[key] = { label = "add-game", expiresAt = now + 180 }
        end
        payload.__async = true
        local result = run_wscript_installer(payload)
        if not (type(result) == "table" and result.pending == true) and key ~= "" then
            runtime.operations[key] = nil
        end
        return response_from_result(result)
    end
    if method == "add-game-result" then return response_from_result(add_game_result_direct(payload)) end
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

function SkyToolsTheme(payload)
    return worker_call("theme", payload or {}, 30)
end

function SkyToolsSaveTheme(payload)
    return worker_call("save-theme", payload or {}, 30)
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

function SkyToolsSaveApi(payload, name, url_template, api_key, enabled, use_proxy, proxy_url_template, success_code, unavailable_code)
    if name ~= nil or url_template ~= nil then
        payload = {
            id = payload,
            name = name,
            urlTemplate = url_template,
            apiKey = api_key,
            enabled = enabled,
            useProxy = use_proxy,
            proxyUrlTemplate = proxy_url_template,
            successCode = success_code,
            unavailableCode = unavailable_code
        }
    end
    return worker_call("save-api", payload or {}, 30)
end

function SkyToolsSaveApiSettings(payload)
    return worker_call("save-api-settings", payload or {}, 30)
end

function SkyToolsDeleteApi(payload)
    if type(payload) == "string" then
        payload = { id = payload }
    end
    return worker_call("delete-api", payload or {}, 30)
end

function SkyToolsAddGame(payload)
    return worker_call("add-game", payload or {}, 180)
end

function SkyToolsAddGameResult(payload)
    return worker_call("add-game-result", payload or {}, 30)
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
    return worker_call("apply-fix", payload or {}, 900)
end

function SkyToolsApplyFixResult(payload)
    return worker_call("apply-fix-result", payload or {}, 30)
end

function SkyToolsRemoveFix(payload)
    return worker_call("remove-fix", payload or {}, 60)
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
        backendMode = "lua-hidden-console-worker",
        hiddenConsole = read_json(hidden_console_state_path(), {}),
        autoUpdate = read_json(auto_update_status_path(), {}),
        browserJsId = runtime.browser_js_id,
        browserCssId = runtime.browser_css_id
    })
end

function skytools_status()
    return SkyToolsStatus()
end
_G["skytools_status"] = skytools_status

function skytools_theme(params)
    return SkyToolsTheme(params or {})
end
_G["skytools_theme"] = skytools_theme

function skytools_save_theme(params)
    return SkyToolsSaveTheme(params or {})
end
_G["skytools_save_theme"] = skytools_save_theme

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

function skytools_save_api(api, name, url_template, api_key, enabled, use_proxy, proxy_url_template, success_code, unavailable_code)
    return SkyToolsSaveApi(api or {}, name, url_template, api_key, enabled, use_proxy, proxy_url_template, success_code, unavailable_code)
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
    return SkyToolsDeleteApi(params)
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

function skytools_remove_fix(params, name)
    if type(params) == "table" then
        return SkyToolsRemoveFix(params)
    end
    return SkyToolsRemoveFix({ appid = params, name = name })
end
_G["skytools_remove_fix"] = skytools_remove_fix

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
        start_hidden_console_worker()
        enqueue_auto_update_check()
        millennium.ready()
    end)
    pcall(copy_public_assets)
    pcall(inject_browser_assets)
end

local function on_unload()
    pcall(stop_hidden_console_worker)
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
