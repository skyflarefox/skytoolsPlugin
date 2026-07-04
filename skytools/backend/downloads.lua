local m_utils = require("utils")
local fs = require("fs")
local http_client = require("http_client")
local config = require("config")
local logger = require("plugin_logger")
local paths = require("paths")
local steam_utils = require("steam_utils")
local utils = require("plugin_utils")
local api_manifest = require("api_manifest")
local settings_manager = require("settings.manager")
local cjson = require("json")

local downloads = {}
local DOWNLOAD_STATE = {}

-- Estados que indicam que um processo já está ativo
local ACTIVE_STATES = {
    ["downloading"] = true,
    ["queued"] = true,
    ["checking"] = true,
    ["extracting"] = true,
    ["processing"] = true
}

local function _set_download_state(appid, update)
    if type(appid) == "string" then appid = tonumber(appid) end
    if not DOWNLOAD_STATE[appid] then DOWNLOAD_STATE[appid] = {} end
    for k, v in pairs(update) do
        DOWNLOAD_STATE[appid][k] = v
    end
end

local function _get_download_state(appid)
    if type(appid) == "string" then appid = tonumber(appid) end
    local state = DOWNLOAD_STATE[appid] or {}
    local copy = {}
    for k, v in pairs(state) do copy[k] = v end
    return copy
end

function downloads.get_add_status(appid)
    if type(appid) == "string" then appid = tonumber(appid) end
    
    local dest_root = utils.ensure_temp_download_dir()
    local state_file = fs.join(dest_root, tostring(appid) .. "_state.json")
    
    -- Sincroniza estado do arquivo JSON com a memória
    if fs.exists(state_file) then
        local read_ok, content = pcall(m_utils.read_file, state_file)
        
        if read_ok and content and content ~= "" then
            local success, data = pcall(cjson.decode, content)
            if success and type(data) == "table" and data.status then
                _set_download_state(appid, { 
                    status = data.status, 
                    error = data.error,
                    bytesRead = data.bytesRead or 0,
                    totalBytes = data.totalBytes or 0
                })
                
                -- Se finalizou no arquivo, processa a instalação
                if data.status == "extracted" then
                    local dest_path = fs.join(dest_root, tostring(appid) .. ".zip")
                    local extract_dir = fs.join(dest_root, "extracted_" .. tostring(appid))
                    local apiName = _get_download_state(appid).currentApi or "Unknown"
                    
                    -- Verifica se já está em processamento para evitar dupla execução
                    local current_st = _get_download_state(appid)
                    if current_st.status ~= "processing" and current_st.status ~= "done" then
                        local ok, res = pcall(downloads._finalize_install_lua, appid, extract_dir, dest_path, apiName)
                        if not ok then
                            _set_download_state(appid, { status = "failed", error = tostring(res) })
                            pcall(m_utils.write_file, state_file, cjson.encode({ status = "failed", error = tostring(res) }))
                        else
                             -- Limpeza após sucesso
                            pcall(fs.remove, state_file)
                            pcall(fs.remove, fs.join(dest_root, tostring(appid) .. "_dl.ps1"))
                        end
                    end
                elseif data.status == "failed" then
                    DOWNLOAD_STATE[appid] = { status = "failed", error = data.error }
                end
            end
        end
    end

    return { success = true, state = _get_download_state(appid) }
end

function downloads._finalize_install_lua(appid, extract_dir, dest_path, api_name)
    _set_download_state(appid, { status = "processing" })
    local base_path = steam_utils.detect_steam_install_path()
    if not base_path then
        error("Steam path not detected")
    end

    local target_dir = fs.join(base_path, "config", "stplug-in")
    if not fs.exists(target_dir) then 
        local ok, err = pcall(fs.create_directories, target_dir)
        if not ok then error("Failed to create target dir: " .. tostring(err)) end
    end
    
    local depot_cache = fs.join(base_path, "depotcache")
    if not fs.exists(depot_cache) then 
        pcall(fs.create_directories, depot_cache) 
    end
    
    local target_lua = fs.join(target_dir, tostring(appid) .. ".lua")
    local extracted_lua_path = nil
    
    local success_list, files = pcall(fs.list_recursive, extract_dir)
    if success_list and files then
        for _, entry in ipairs(files) do
            if entry.is_directory then goto continue end
            if entry.name:match("%.manifest$") then
                local dest_man = fs.join(depot_cache, entry.name)
                local content = m_utils.read_file(entry.path)
                if content then pcall(m_utils.write_file, dest_man, content) end
            end
            if entry.name == tostring(appid) .. ".lua" then
                extracted_lua_path = entry.path
            elseif not extracted_lua_path and entry.name:match("^%d+%.lua$") then
                extracted_lua_path = entry.path
            end
            ::continue::
        end
    end
    
    if not extracted_lua_path then
        error("No Lua file found in extraction directory")
    end

    if not fs.exists(extracted_lua_path) then
        error("Extracted Lua file does not exist: " .. extracted_lua_path)
    end

    local read_ok, text = pcall(m_utils.read_file, extracted_lua_path)
    if not read_ok or not text then
        error("Failed to read extracted Lua file")
    end

    local new_lines = {}
    for line in text:gmatch("([^\n]*)\n?") do
        if line:match("^%s*setManifestid%(") then
            line = line:gsub("^(%s*)(setManifestid)", "%1-- %2")
        end
        table.insert(new_lines, line)
    end
    
    if #new_lines > 0 and new_lines[#new_lines] == "" then table.remove(new_lines) end
    local processed_text = table.concat(new_lines, "\n")
    
    local write_ok, write_err = pcall(m_utils.write_file, target_lua, processed_text)
    if not write_ok then
        error("Failed to write target Lua: " .. tostring(write_err))
    end

    _set_download_state(appid, { installedPath = target_lua })
    
    -- Limpeza segura
    pcall(fs.remove_all, extract_dir)
    pcall(fs.remove, dest_path)
    
    _set_download_state(appid, { status = "done", success = true, api = api_name })
end

local function _launch_async_download(appid, url, dest_path, extract_dir)
    local success, err = pcall(function()
        local is_windows = m_utils.getenv("OS") == "Windows_NT"
        local dest_root = utils.ensure_temp_download_dir()
        local state_file = fs.join(dest_root, tostring(appid) .. "_state.json")
        
        -- === CORREÇÃO MONSTRO: MATAR PROCESSOS TRAVADOS NO WINDOWS ===
        if is_windows then
            pcall(m_utils.exec, 'taskkill /f /im powershell.exe /fi "WINDOWTITLE eq Windows PowerShell"')
            os.execute("timeout /t 1 /nobreak > nul")
        end

        -- Limpeza preventiva
        if fs.exists(state_file) then pcall(fs.remove, state_file) end
        if fs.exists(dest_path) then pcall(fs.remove, dest_path) end
        if fs.exists(extract_dir) then pcall(fs.remove_all, extract_dir) end

        fs.create_directories(extract_dir)
        
        -- Estado inicial
        pcall(m_utils.write_file, state_file, '{"status": "downloading", "bytesRead": 0, "totalBytes": 0}')
        
        local cmd
        if is_windows then
            local ps1_path = fs.join(paths.get_plugin_dir(), "backend", "scripts", "downloader.ps1")
            cmd = string.format(
                'powershell -WindowStyle normal -Command "Start-Process -FilePath powershell -WindowStyle Minimized -ArgumentList \'-ExecutionPolicy Bypass -File \\"%s\\" -Url \\"%s\\" -DestPath \\"%s\\" -ExtractDir \\"%s\\" -StateFile \\"%s\\"\'"',
                ps1_path, url, dest_path, extract_dir, state_file
            ) 
            pcall(m_utils.exec, cmd)
        else
            local sh_path = fs.join(paths.get_plugin_dir(), "backend", "scripts", "downloader.sh")
            pcall(m_utils.exec, 'chmod +x "' .. sh_path .. '"')
            cmd = string.format(
                'nohup bash "%s" "%s" "%s" "%s" "%s" > /dev/null 2>&1 &',
                sh_path, url, dest_path, extract_dir, state_file
            )
            pcall(m_utils.exec, cmd)
        end
    end)

    if not success then
        local dest_root = utils.ensure_temp_download_dir()
        local state_file = fs.join(dest_root, tostring(appid) .. "_state.json")
        pcall(m_utils.write_file, state_file, '{"status": "error", "bytesRead": 0, "totalBytes": 0, "error": "Launch failed"}')
        logger.log("Erro ao iniciar download assíncrono: " .. tostring(err))
    end

    return success
end

function downloads.start_add_via_luatools_from_url(appid, url, apiName)
    if type(appid) == "string" then appid = tonumber(appid) end
    if not appid then return { success = false, error = "Invalid appid" } end

    local current_state = _get_download_state(appid)
    if current_state.status and ACTIVE_STATES[current_state.status] then
        logger.log("LuaTools: Download already active for AppID " .. tostring(appid) .. " (Status: " .. current_state.status .. ")")
        return { success = false, error = "Download already in progress: " .. current_state.status }
    end

    logger.log("LuaTools: StartAddViaLuaToolsFromUrl appid=" .. tostring(appid) .. " api=" .. tostring(apiName))
    _set_download_state(appid, { status = "downloading", currentApi = apiName, bytesRead = 0, totalBytes = 0 })

    local ok, res = pcall(function()
        if not url or url == "" then error("Invalid URL provided") end
        local dest_root = utils.ensure_temp_download_dir()
        local dest_path = fs.join(dest_root, tostring(appid) .. ".zip")
        local extract_dir = fs.join(dest_root, "extracted_" .. tostring(appid))
        _launch_async_download(appid, url, dest_path, extract_dir)
    end)

    if not ok then
        logger.warn("LuaTools: Async Download crashed - " .. tostring(res))
        _set_download_state(appid, { status = "failed", error = tostring(res) })
        return { success = false, error = tostring(res) }
    end

    return { success = true }
end

function downloads.start_add_via_luatools(appid)
    if type(appid) == "string" then appid = tonumber(appid) end
    if not appid then return { success = false, error = "Invalid appid" } end

    local current_state = _get_download_state(appid)
    if current_state.status and ACTIVE_STATES[current_state.status] then
        logger.log("LuaTools: Download already active for AppID " .. tostring(appid) .. " (Status: " .. current_state.status .. ")")
        return { success = false, error = "Download already in progress: " .. current_state.status }
    end

    logger.log("LuaTools: StartAddViaLuaTools appid=" .. tostring(appid))
    _set_download_state(appid, { status = "checking", bytesRead = 0, totalBytes = 0 })

    local apis = api_manifest.load_api_manifest()
    if not apis or #apis == 0 then
        _set_download_state(appid, { status = "failed", error = "No APIs available" })
        return { success = false, error = "No APIs available" }
    end

    local dest_root = utils.ensure_temp_download_dir()
    local dest_path = fs.join(dest_root, tostring(appid) .. ".zip")
    local extract_dir = fs.join(dest_root, "extracted_" .. tostring(appid))
    local morrenus_api_key = settings_manager.get_morrenus_api_key()

    local ok, res = pcall(function()
        local target_url = nil
        local target_name = nil
        
        for _, api in ipairs(apis) do
            local name = api.name or "Unknown"
            local template = api.url or ""
            local success_code = tonumber(api.success_code) or 200

            if string.find(template, "<moapikey>") then
                if not morrenus_api_key or morrenus_api_key == "" then goto continue end
                template = template:gsub("<moapikey>", morrenus_api_key)
            end
            if string.find(template, "<apikey>") then
                if not api.api_key or api.api_key == "" then goto continue end
                template = template:gsub("<apikey>", api.api_key)
            end
            
            local url = template:gsub("<appid>", tostring(appid))
            
            local success = false
            if string.lower(name) == "morrenus" then
                local status_url = "https://hubcapmanifest.com/api/v1/status/" .. tostring(appid) .. "?api_key=" .. tostring(morrenus_api_key)
                local s_resp = http_client.get(status_url, { headers = { ["User-Agent"] = config.USER_AGENT }, timeout = 5 })
                if s_resp and s_resp.status == success_code then
                    success = true
                end
            else
                local resp = http_client.head(url, { headers = { ["User-Agent"] = config.USER_AGENT }, timeout = 5 })
                if resp and resp.status == success_code then
                    success = true
                end
            end
            
            if success then
                target_url = url
                target_name = name
                break
            end
            ::continue::
        end
        
        if not target_url then 
            _set_download_state(appid, { status = "failed", error = "Not available on any API" })
            error("Not available on any API") 
        end
        
        _set_download_state(appid, { status = "downloading", currentApi = target_name, bytesRead = 0, totalBytes = 0 })
        _launch_async_download(appid, target_url, dest_path, extract_dir)
    end)

    if not ok then
        logger.warn("LuaTools: start_add_via_luatools crashed - " .. tostring(res))
        local st = _get_download_state(appid)
        if st.status ~= "downloading" then
            _set_download_state(appid, { status = "failed", error = tostring(res) })
        end
        return { success = false, error = tostring(res) }
    end

    return { success = true }
end

function downloads.check_apis_for_app(appid)
    if type(appid) == "string" then appid = tonumber(appid) end
    if not appid then return { success = false, error = "Invalid appid" } end

    local apis = api_manifest.load_api_manifest()
    if not apis or #apis == 0 then
        return { success = true, results = {} }
    end

    local results = {}
    local morrenus_api_key = settings_manager.get_morrenus_api_key()

    for _, api in ipairs(apis) do
        local name = api.name or "Unknown"
        local template = api.url or ""
        local success_code = tonumber(api.success_code) or 200

        if string.find(template, "<moapikey>") then
            if not morrenus_api_key or morrenus_api_key == "" then goto continue end
            template = template:gsub("<moapikey>", morrenus_api_key)
        end
        if string.find(template, "<apikey>") then
            if not api.api_key or api.api_key == "" then goto continue end
            template = template:gsub("<apikey>", api.api_key)
        end

        local url = template:gsub("<appid>", tostring(appid))
        local available = false

        if string.lower(name) == "morrenus" then
            local status_url = "https://hubcapmanifest.com/api/v1/status/" .. tostring(appid) .. "?api_key=" .. tostring(morrenus_api_key)
            local resp = http_client.get(status_url, { headers = { ["User-Agent"] = config.USER_AGENT }, timeout = 5 })
            if resp and resp.status == success_code then available = true end
        else
            local resp = http_client.head(url, { headers = { ["User-Agent"] = config.USER_AGENT }, timeout = 5 })
            if resp and resp.status == success_code then available = true end
        end

        table.insert(results, {
            name = name,
            available = available,
            url = available and url or nil
        })
        
        ::continue::
    end

    return { success = true, results = results }
end

return downloads
