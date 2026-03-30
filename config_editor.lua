-- config_editor.lua
-- Interactive config editor for Warehost (CC:Tweaked)

local VERSION = "GIT_HASH_PLACEHOLDER"

local function cprint(text, color)
    if term.isColor() then
        local old = term.getTextColor()
        term.setTextColor(color or colors.white)
        print(text)
        term.setTextColor(old)
    else
        print(text)
    end
end

local function loadConfig()
    if fs.exists("config.json") then
        local f = fs.open("config.json", "r")
        if f then
            local data = f.readAll()
            f.close()
            local parsed = textutils.unserializeJSON(data)
            if parsed then return parsed end
        end
    end
    return nil
end

local function saveConfig(cfg)
    local f = fs.open("config.json", "w")
    if f then
        f.write(textutils.serializeJSON(cfg))
        f.close()
        return true
    end
    return false
end

-- Flatten config into an ordered list of editable entries
local function buildEntries(cfg)
    local entries = {}
    local key_order = {
        "storage_side", "log_file", "ignore_night", "time_between_runs",
        "max_craft_amount", "enable_equipment_delivery", "enable_wireless",
        "wireless_network", "enable_auto_update", "skip_patterns", "skip_exact"
    }
    for _, k in ipairs(key_order) do
        if cfg[k] ~= nil then
            table.insert(entries, {key = k, value = cfg[k]})
        end
    end
    -- catch any keys not in the predefined order
    for k, v in pairs(cfg) do
        local found = false
        for _, ok in ipairs(key_order) do
            if ok == k then found = true; break end
        end
        if not found then
            table.insert(entries, {key = k, value = v})
        end
    end
    return entries
end

local function typeLabel(v)
    local t = type(v)
    if t == "boolean" then return "bool"
    elseif t == "number" then return "num"
    elseif t == "string" then return "str"
    elseif t == "table" then
        -- check if array or map
        if #v > 0 or next(v) == nil then return "list" end
        return "map"
    end
    return t
end

local function valuePreview(v, max_w)
    max_w = max_w or 30
    local t = type(v)
    if t == "boolean" then
        return v and "true" or "false"
    elseif t == "number" then
        return tostring(v)
    elseif t == "string" then
        if #v > max_w then return v:sub(1, max_w - 2) .. ".." end
        return v
    elseif t == "table" then
        if #v > 0 then
            return "[" .. #v .. " items]"
        else
            local count = 0
            for _ in pairs(v) do count = count + 1 end
            return "{" .. count .. " keys}"
        end
    end
    return tostring(v)
end

-- Draw the main config list
local function drawMain(entries, selected, scroll, dirty)
    term.clear()
    term.setCursorPos(1, 1)

    local w, h = term.getSize()

    -- Header
    if term.isColor() then term.setBackgroundColor(colors.gray) end
    term.setCursorPos(1, 1)
    term.write(string.rep(" ", w))
    term.setCursorPos(1, 1)
    local title = " Warehost Config Editor"
    if VERSION ~= "GIT_HASH_PLACEHOLDER" then
        title = title .. " v" .. VERSION
    end
    if term.isColor() then term.setTextColor(colors.cyan) end
    term.write(title)

    if dirty then
        local save_label = " [UNSAVED] "
        term.setCursorPos(w - #save_label + 1, 1)
        if term.isColor() then term.setTextColor(colors.red) end
        term.write(save_label)
    end
    if term.isColor() then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
    end

    -- Footer
    term.setCursorPos(1, h)
    if term.isColor() then term.setBackgroundColor(colors.gray) end
    term.write(string.rep(" ", w))
    term.setCursorPos(1, h)
    if term.isColor() then term.setTextColor(colors.lightGray) end
    local footer = " Up/Dn:Nav  Enter:Edit  S:Save  Q:Quit"
    term.write(footer)
    if term.isColor() then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
    end

    -- List area
    local list_top = 3
    local list_bot = h - 2
    local visible = list_bot - list_top + 1

    for i = 1, visible do
        local idx = scroll + i
        local y = list_top + i - 1
        term.setCursorPos(1, y)

        if idx > #entries then
            term.write(string.rep(" ", w))
        else
            local entry = entries[idx]
            local is_sel = (idx == selected)

            if is_sel and term.isColor() then
                term.setBackgroundColor(colors.blue)
                term.setTextColor(colors.white)
            end
            term.write(string.rep(" ", w))
            term.setCursorPos(1, y)

            local tl = typeLabel(entry.value)
            local key_str = " " .. entry.key
            local val_str = valuePreview(entry.value, w - #key_str - #tl - 6)
            local line = key_str .. " "
            term.write(line)

            if term.isColor() then
                term.setTextColor(is_sel and colors.lightGray or colors.gray)
            end
            term.write("(" .. tl .. ") ")

            if term.isColor() then
                if type(entry.value) == "boolean" then
                    term.setTextColor(entry.value and colors.green or colors.red)
                elseif type(entry.value) == "number" then
                    term.setTextColor(colors.yellow)
                elseif type(entry.value) == "string" then
                    term.setTextColor(colors.orange)
                else
                    term.setTextColor(colors.lightBlue)
                end
            end
            term.write(val_str)

            if term.isColor() then
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.white)
            end
        end
    end
end

-- Edit a list (array of strings)
local function editList(key, list)
    local selected = 1
    local scroll = 0
    local changed = false

    while true do
        term.clear()
        local w, h = term.getSize()

        term.setCursorPos(1, 1)
        if term.isColor() then
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.cyan)
        end
        term.write(string.rep(" ", w))
        term.setCursorPos(1, 1)
        term.write(" Edit List: " .. key)
        if term.isColor() then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
        end

        term.setCursorPos(1, h)
        if term.isColor() then
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.lightGray)
        end
        term.write(string.rep(" ", w))
        term.setCursorPos(1, h)
        term.write(" A:Add  Del:Remove  Esc:Back")
        if term.isColor() then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
        end

        local list_top = 3
        local list_bot = h - 2
        local visible = list_bot - list_top + 1

        if #list == 0 then
            term.setCursorPos(2, list_top)
            if term.isColor() then term.setTextColor(colors.gray) end
            term.write("(empty list)")
            if term.isColor() then term.setTextColor(colors.white) end
        end

        for i = 1, visible do
            local idx = scroll + i
            local y = list_top + i - 1
            term.setCursorPos(1, y)
            if idx <= #list then
                local is_sel = (idx == selected)
                if is_sel and term.isColor() then
                    term.setBackgroundColor(colors.blue)
                    term.setTextColor(colors.white)
                end
                term.write(string.rep(" ", w))
                term.setCursorPos(1, y)
                term.write(" " .. list[idx])
                if term.isColor() then
                    term.setBackgroundColor(colors.black)
                    term.setTextColor(colors.white)
                end
            end
        end

        local evt, key_pressed = os.pullEvent("key")
        if key_pressed == keys.up then
            if selected > 1 then selected = selected - 1 end
            if selected <= scroll then scroll = selected - 1 end
        elseif key_pressed == keys.down then
            if selected < #list then selected = selected + 1 end
            if selected > scroll + visible then scroll = selected - visible end
        elseif key_pressed == keys.a then
            term.setCursorPos(1, h - 1)
            term.clearLine()
            if term.isColor() then term.setTextColor(colors.yellow) end
            write(" New entry: ")
            if term.isColor() then term.setTextColor(colors.white) end
            local val = read()
            if val and val ~= "" then
                table.insert(list, val)
                changed = true
            end
        elseif key_pressed == keys.delete or key_pressed == keys.backspace then
            if #list > 0 and selected <= #list then
                table.remove(list, selected)
                if selected > #list and selected > 1 then selected = selected - 1 end
                changed = true
            end
        elseif key_pressed == keys.escape or key_pressed == keys.q then
            break
        end
    end
    return list, changed
end

-- Edit a map (table of string keys -> boolean true)
local function editMap(key, map)
    local changed = false
    local selected = 1
    local scroll = 0

    while true do
        -- rebuild keys list each frame
        local keys_list = {}
        for k, _ in pairs(map) do table.insert(keys_list, k) end
        table.sort(keys_list)

        term.clear()
        local w, h = term.getSize()

        term.setCursorPos(1, 1)
        if term.isColor() then
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.cyan)
        end
        term.write(string.rep(" ", w))
        term.setCursorPos(1, 1)
        term.write(" Edit Map: " .. key)
        if term.isColor() then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
        end

        term.setCursorPos(1, h)
        if term.isColor() then
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.lightGray)
        end
        term.write(string.rep(" ", w))
        term.setCursorPos(1, h)
        term.write(" A:Add  Del:Remove  Esc:Back")
        if term.isColor() then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
        end

        local list_top = 3
        local list_bot = h - 2
        local visible = list_bot - list_top + 1

        if #keys_list == 0 then
            term.setCursorPos(2, list_top)
            if term.isColor() then term.setTextColor(colors.gray) end
            term.write("(empty map)")
            if term.isColor() then term.setTextColor(colors.white) end
        end

        for i = 1, visible do
            local idx = scroll + i
            local y = list_top + i - 1
            term.setCursorPos(1, y)
            if idx <= #keys_list then
                local is_sel = (idx == selected)
                if is_sel and term.isColor() then
                    term.setBackgroundColor(colors.blue)
                    term.setTextColor(colors.white)
                end
                term.write(string.rep(" ", w))
                term.setCursorPos(1, y)
                term.write(" " .. keys_list[idx] .. " = " .. tostring(map[keys_list[idx]]))
                if term.isColor() then
                    term.setBackgroundColor(colors.black)
                    term.setTextColor(colors.white)
                end
            end
        end

        local evt, key_pressed = os.pullEvent("key")
        if key_pressed == keys.up then
            if selected > 1 then selected = selected - 1 end
            if selected <= scroll then scroll = selected - 1 end
        elseif key_pressed == keys.down then
            if selected < #keys_list then selected = selected + 1 end
            if selected > scroll + visible then scroll = selected - visible end
        elseif key_pressed == keys.a then
            term.setCursorPos(1, h - 1)
            term.clearLine()
            if term.isColor() then term.setTextColor(colors.yellow) end
            write(" New key: ")
            if term.isColor() then term.setTextColor(colors.white) end
            local val = read()
            if val and val ~= "" then
                map[val] = true
                changed = true
            end
        elseif key_pressed == keys.delete or key_pressed == keys.backspace then
            if #keys_list > 0 and selected <= #keys_list then
                map[keys_list[selected]] = nil
                if selected > #keys_list - 1 and selected > 1 then selected = selected - 1 end
                changed = true
            end
        elseif key_pressed == keys.escape or key_pressed == keys.q then
            break
        end
    end
    return map, changed
end

-- Prompt for a new scalar value
local function editScalar(key, current_val)
    local w, h = term.getSize()
    term.setCursorPos(1, h - 1)
    term.clearLine()

    local t = type(current_val)
    if t == "boolean" then
        return not current_val, true
    end

    if term.isColor() then term.setTextColor(colors.yellow) end
    write(" " .. key .. " = ")
    if term.isColor() then term.setTextColor(colors.white) end
    local input = read(nil, nil, nil, tostring(current_val))

    if input == nil or input == "" then
        return current_val, false
    end

    if t == "number" then
        local num = tonumber(input)
        if num then return num, true end
        return current_val, false
    end

    return input, true
end

-- Main loop
local function main()
    local cfg = loadConfig()
    if not cfg then
        cprint("ERROR: Could not load config.json!", colors.red)
        cprint("Run install.lua first or create a config.json.", colors.orange)
        return
    end

    local entries = buildEntries(cfg)
    local selected = 1
    local scroll = 0
    local dirty = false

    while true do
        local w, h = term.getSize()
        local list_top = 3
        local list_bot = h - 2
        local visible = list_bot - list_top + 1

        drawMain(entries, selected, scroll, dirty)

        local evt, key_pressed = os.pullEvent("key")

        if key_pressed == keys.up then
            if selected > 1 then selected = selected - 1 end
            if selected <= scroll then scroll = selected - 1 end
        elseif key_pressed == keys.down then
            if selected < #entries then selected = selected + 1 end
            if selected > scroll + visible then scroll = selected - visible end
        elseif key_pressed == keys.enter or key_pressed == keys.numPadEnter then
            local entry = entries[selected]
            local t = type(entry.value)
            if t == "table" then
                local tl = typeLabel(entry.value)
                if tl == "list" then
                    local new_list, changed = editList(entry.key, entry.value)
                    if changed then
                        entry.value = new_list
                        cfg[entry.key] = new_list
                        dirty = true
                    end
                else
                    local new_map, changed = editMap(entry.key, entry.value)
                    if changed then
                        entry.value = new_map
                        cfg[entry.key] = new_map
                        dirty = true
                    end
                end
            else
                local new_val, changed = editScalar(entry.key, entry.value)
                if changed then
                    entry.value = new_val
                    cfg[entry.key] = new_val
                    dirty = true
                end
            end
        elseif key_pressed == keys.s then
            if dirty then
                local ok = saveConfig(cfg)
                if ok then
                    dirty = false
                    term.setCursorPos(1, h - 1)
                    term.clearLine()
                    if term.isColor() then term.setTextColor(colors.green) end
                    write(" Config saved!")
                    if term.isColor() then term.setTextColor(colors.white) end
                    os.sleep(1)
                else
                    term.setCursorPos(1, h - 1)
                    term.clearLine()
                    if term.isColor() then term.setTextColor(colors.red) end
                    write(" Failed to save!")
                    if term.isColor() then term.setTextColor(colors.white) end
                    os.sleep(1)
                end
            end
        elseif key_pressed == keys.q or key_pressed == keys.escape then
            if dirty then
                term.setCursorPos(1, h - 1)
                term.clearLine()
                if term.isColor() then term.setTextColor(colors.yellow) end
                write(" Unsaved changes! Press Q again to quit, S to save: ")
                if term.isColor() then term.setTextColor(colors.white) end
                local _, confirm = os.pullEvent("key")
                if confirm == keys.q then
                    break
                elseif confirm == keys.s then
                    saveConfig(cfg)
                    break
                end
            else
                break
            end
        end
    end

    term.clear()
    term.setCursorPos(1, 1)
end

main()
