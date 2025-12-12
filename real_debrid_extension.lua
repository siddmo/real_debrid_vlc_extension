
-- Real-Debrid File Selector for VLC (Mac V9 - Clipboard Auto-Run)
-- Save as: real_debrid_player.lua

function descriptor()
    return {
        title = "Real-Debrid Selector",
        version = "9.0",
        author = "User",
        url = "https://real-debrid.com/",
        shortdesc = "Stream from Real-Debrid",
        description = "Auto-reads Clipboard on startup for instant loading.",
        capabilities = {"input-listener"}
    }
end

-- ===========================
-- GLOBAL VARS
-- ===========================
local dlg = nil
local token_input = nil
local magnet_input = nil
local file_dropdown = nil
local status_label = nil

-- Data
local current_torrent_id = nil
local file_map = {} 
local api_token = ""

function activate()
    api_token = load_config()
    create_dialog()
    
    -- NEW: Auto-check clipboard 0.5 seconds after UI loads
    -- We can't use a timer easily in basic Lua, so we just run it directly
    check_clipboard_and_run()
end

function deactivate()
    if dlg then dlg:delete() end
end

function close()
    vlc.deactivate()
end

function create_dialog()
    dlg = vlc.dialog("Real-Debrid Player")
    
    -- Smart Focus Logic
    if api_token and api_token ~= "" then
        dlg:add_label("Magnet:", 1, 2, 1, 1)
        magnet_input = dlg:add_text_input("", 2, 2, 3, 1)
        dlg:add_label("API Token:", 1, 1, 1, 1)
        token_input = dlg:add_text_input(api_token, 2, 1, 3, 1)
    else
        dlg:add_label("API Token:", 1, 1, 1, 1)
        token_input = dlg:add_text_input(api_token, 2, 1, 3, 1)
        dlg:add_label("Magnet:", 1, 2, 1, 1)
        magnet_input = dlg:add_text_input("", 2, 2, 3, 1)
    end
    
    dlg:add_button("Load Files", click_load, 5, 2, 1, 1)
    dlg:add_label("File:", 1, 3, 1, 1)
    file_dropdown = dlg:add_dropdown(2, 3, 3, 1)
    dlg:add_button("Start & Play", click_play, 5, 3, 1, 1)
    status_label = dlg:add_label("Ready.", 1, 4, 5, 1)
    
    dlg:show()
end

-- ===========================
-- CLIPBOARD LOGIC (NEW)
-- ===========================

function check_clipboard_and_run()
    -- Read Mac Clipboard using pbpaste
    local handle = io.popen("pbpaste")
    local clipboard = handle:read("*a")
    handle:close()
    
    if clipboard and string.match(clipboard, "^magnet:%?") then
        if magnet_input then
            magnet_input:set_text(clipboard)
            update_status("Magnet detected in clipboard! Auto-loading...")
            -- Trigger load logic immediately
            click_load()
        end
    end
end

-- ===========================
-- CONFIG PERSISTENCE
-- ===========================

function get_config_path()
    local config_dir = vlc.config.configdir()
    return config_dir .. "/rd_token.conf"
end

function load_config()
    local path = get_config_path()
    local f = io.open(path, "r")
    if f then
        local content = f:read("*all")
        f:close()
        return content:gsub("^%s*(.-)%s*$", "%1")
    end
    return ""
end

function save_config(token)
    local path = get_config_path()
    local f = io.open(path, "w")
    if f then
        f:write(token)
        f:close()
    end
end

-- ===========================
-- BUTTON LOGIC
-- ===========================

function click_load()
    local token_val = token_input:get_text()
    if token_val == "" then
        update_status("Error: Please enter API Token.")
        return
    end
    api_token = token_val
    save_config(api_token)

    local magnet = magnet_input:get_text()
    if magnet == "" then 
        update_status("Error: No magnet link.")
        return 
    end

    file_map = {} 
    file_dropdown:clear() 
    current_torrent_id = nil

    local hash = string.match(magnet, "btih:([a-zA-Z0-9]+)")
    if hash then
        update_status("Checking active torrents...")
        local existing_id = find_existing_torrent(hash)
        if existing_id then
            update_status("Resuming existing torrent...")
            current_torrent_id = existing_id
            fetch_file_list(existing_id)
            return 
        end
    end

    update_status("Adding new torrent...")
    local encoded_magnet = vlc.strings.encode_uri_component(magnet)
    encoded_magnet = string.gsub(encoded_magnet, "'", "%%27")

    local add_url = "https://api.real-debrid.com/rest/1.0/torrents/addMagnet"
    local response = post_req(add_url, "magnet=" .. encoded_magnet)
    
    local torrent_id = string.match(response, '"id"%s*:%s*"(.-)"')
    if not torrent_id then
        local rd_error = string.match(response, '"error"%s*:%s*"(.-)"') or "Unknown"
        update_status("API Error: " .. rd_error)
        return
    end
    
    current_torrent_id = torrent_id
    fetch_file_list(torrent_id)
end

function fetch_file_list(torrent_id)
    update_status("Fetching file list...")
    local info_url = "https://api.real-debrid.com/rest/1.0/torrents/info/" .. torrent_id
    local info_resp = get_req(info_url)
    
    if not info_resp then
        update_status("Error fetching info.")
        return
    end
    
    parse_and_fill_dropdown(info_resp)
    update_status("Select file and click 'Start & Play'.")
end

function click_play()
    if not current_torrent_id then
        update_status("Error: Please load files first.")
        return
    end

    local selected_idx = file_dropdown:get_value()
    if not selected_idx or not file_map[selected_idx] then
        update_status("Error: No file selected.")
        return
    end
    
    local selected_file_id = file_map[selected_idx]
    
    update_status("Starting Torrent (ID: " .. selected_file_id .. ")...")

    local select_url = "https://api.real-debrid.com/rest/1.0/torrents/selectFiles/" .. current_torrent_id
    post_req(select_url, "files=" .. selected_file_id)

    local info_url = "https://api.real-debrid.com/rest/1.0/torrents/info/" .. current_torrent_id
    local final_link = nil
    
    for i=1, 10 do
        local resp = get_req(info_url)
        local status = string.match(resp, '"status"%s*:%s*"(.-)"')
        
        if status == "downloaded" then
            final_link = string.match(resp, '"links"%s*:%s*%[%s*"(.-)"')
            break
        elseif status == "downloading" then
             update_status("Buffering... ("..i.."/10)")
        end
        local t = os.time()
        while os.time() < t + 1 do end
    end

    if not final_link then
        update_status("Error: Torrent not Cached. Cannot stream.")
        return
    end

    update_status("Unrestricting link...")
    final_link = string.gsub(final_link, "\\/", "/")
    
    local unrestrict_url = "https://api.real-debrid.com/rest/1.0/unrestrict/link"
    local unrestrict_resp = post_req(unrestrict_url, "link=" .. final_link)
    
    local download_url = string.match(unrestrict_resp, '"download"%s*:%s*"(.-)"')
    
    if download_url then
        download_url = string.gsub(download_url, "\\/", "/")
        local item = { path = download_url, name = "Real-Debrid Stream" }
        vlc.playlist.add({item})
        vlc.playlist.play()
        dlg:delete()
        dlg = nil
    else
        update_status("Error: Unrestrict failed.")
    end
end

-- ===========================
-- HELPER LOGIC
-- ===========================

function find_existing_torrent(magnet_hash)
    local magnet_hash = string.lower(magnet_hash)
    local list_url = "https://api.real-debrid.com/rest/1.0/torrents?limit=50"
    local json = get_req(list_url)
    if not json then return nil end
    for id, hash in string.gmatch(json, '"id"%s*:%s*"(.-)".-"hash"%s*:%s*"(.-)"') do
        if string.lower(hash) == magnet_hash then return id end
    end
    return nil
end

function parse_and_fill_dropdown(json)
    local index = 1
    local largest_idx = 1
    local max_size = 0
    
    for id, path, bytes in string.gmatch(json, '"id"%s*:%s*(%d+).-"path"%s*:%s*"(.-)".-"bytes"%s*:%s*(%d+)') do
        if string.sub(path, 1, 1) == "/" then path = string.sub(path, 2) end
        
        local display_name = path
        if string.len(display_name) > 55 then
             display_name = string.sub(display_name, 1, 52) .. "..."
        end
        
        local size_str = format_size(bytes)
        local display_text = string.format("%s (%s)", display_name, size_str)
        file_dropdown:add_value(display_text, index)
        file_map[index] = id
        
        local b = tonumber(bytes)
        if b and b > max_size then
            max_size = b
            largest_idx = index
        end
        index = index + 1
    end
end

function format_size(bytes)
    bytes = tonumber(bytes)
    if not bytes then return "0B" end
    local units = {"B", "KB", "MB", "GB", "TB"}
    local i = 1
    while bytes > 1024 and i < 5 do
        bytes = bytes / 1024
        i = i + 1
    end
    return string.format("%.2f %s", bytes, units[i])
end

function update_status(msg)
    if status_label then status_label:set_text(msg) end
    vlc.msg.info("RD-Ext: " .. msg)
end

function get_req(url)
    local cmd = string.format("/usr/bin/curl -k -s -X GET -H 'Authorization: Bearer %s' '%s'", api_token, url)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end

function post_req(url, body)
    local cmd = string.format("/usr/bin/curl -k -s -X POST -H 'Authorization: Bearer %s' -d '%s' '%s'", api_token, body, url)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end
