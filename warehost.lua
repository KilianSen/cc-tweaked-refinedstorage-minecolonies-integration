-- RSWarehouse.lua
--
-- This program monitors work requests for the Minecolonies Warehouse and
-- tries to fulfill requests from the Refined Storage network. If the
-- RS network doesn't have enough items and a crafting pattern exists, a
-- crafting job is scheduled to restock the items in order to fulfill the
-- work request.  The script will continuously loop, monitoring for new
-- requests and checking on crafting jobs to fulfill previous requests.

-- The following is required for setup:
--   * 1 ComputerCraft Computer
--   * 1 or more ComputerCraft Monitors (recommend 3x3 monitors)
--   * 1 Advanced Peripheral Colony Integrator
--   * 1 Advanced Peripheral RS Bridge
--   * 1 Chest or other storage container
-- Attach an RS Cable from the RS network to the RS Bridge. Connect the
-- storage container to the Minecolonies Warehouse Hut block. One idea is
-- to set up a second RS network attached to the Warehouse Hut using an
-- External Storage connector and then attach an Importer for that network
-- to the storage container.

-- THINGS YOU CAN CUSTOMIZE IN THIS PROGRAM:
-- storage: Specify the side the storage container is at.
-- logFile: Name of log file for storing JSON data of all open requests.
-- skip_patterns / skip_exact: Items that should be manually provided.
-- time_between_runs: Time in seconds between work order scans.

----------------------------------------------------------------------------
-- CONFIGURATION
----------------------------------------------------------------------------

local default_config = {
    storage_side = "left",
    log_file = "RSWarehouse.log",
    ignore_night = true,
    time_between_runs = 30,
    max_craft_amount = 500,
    enable_equipment_delivery = false,
    enable_wireless = false,
    wireless_network = "warehouse_net",
    enable_auto_update = true,
    skip_patterns = {
        "Tool of class", "Hoe", "Shovel", "Axe", "Pickaxe", "Bow",
        "Sword", "Shield", "Helmet", "Leather Cap", "Chestplate",
        "Tunic", "Pants", "Leggings", "Boots"
    },
    skip_exact = {
        ["Rallying Banner"] = true, ["Crafter"] = true,
        ["Compostable"] = true, ["Fertilizer"] = true,
        ["Flowers"] = true, ["Food"] = true, ["Fuel"] = true,
        ["Smeltable Ore"] = true, ["Stack List"] = true
    }
}

local config = {}
for k, v in pairs(default_config) do
    if type(v) == "table" then
        config[k] = {}
        for ik, iv in pairs(v) do config[k][ik] = iv end
    else
        config[k] = v
    end
end

if fs.exists("config.json") then
    local f = fs.open("config.json", "r")
    if f then
        local data = f.readAll()
        f.close()
        local parsed = textutils.unserializeJSON(data)
        if parsed then
            for k, v in pairs(parsed) do config[k] = v end
        end
        print("Config loaded from config.json")
    end
else
    local f = fs.open("config.json", "w")
    if f then
        f.write(textutils.serializeJSON(config))
        f.close()
        print("Created default config.json")
    end
end

----------------------------------------------------------------------------
-- AUTO UPDATER
----------------------------------------------------------------------------

local function checkForUpdates()
    print("Checking for updates...")
    if http then
        local url = "https://raw.githubusercontent.com/KilianSen/cc-tweaked-refinedstorage-minecolonies-integration/main/warehost.lua"
        local request = http.get(url)
        if request then
            local remote_code = request.readAll()
            request.close()
            
            local current_code = ""
            local program_path = shell.getRunningProgram()
            local local_file = fs.open(program_path, "r")
            if local_file then
                current_code = local_file.readAll()
                local_file.close()
            end
            
            if remote_code and #remote_code > 0 and remote_code ~= current_code then
                print("Update found! Applying update...")
                local out_file = fs.open(program_path, "w")
                if out_file then
                    out_file.write(remote_code)
                    out_file.close()
                    print("Update complete! Restarting script...")
                    os.sleep(1)
                    shell.run(program_path)
                    os.exit()
                end
            else
                print("Script is up to date.")
            end
        else
            print("WARNING: Could not reach GitHub for updates.")
        end
    else
        print("WARNING: http API is disabled. Auto-updater cannot run.")
    end
end

if config.enable_auto_update then
    checkForUpdates()
end

----------------------------------------------------------------------------
-- WIRELESS PERIPHERAL SETUP
----------------------------------------------------------------------------

local periph = peripheral
if config.enable_wireless then
    print("Setting up Wireless Peripherals...")
    local ok, wpp, err = false, nil, nil
    ok, wpp = pcall(require, "wpp")
    if not ok then
        ok, wpp = pcall(dofile, shell.resolve("wpp.lua"))
        if not ok then err = wpp end
    end

    if not ok then
        print("Downloading CC-WirelessPeripheral (wpp.lua)...")
        if http then
            local request = http.get("https://raw.githubusercontent.com/jdf221/CC-WirelessPeripheral/main/wpp.lua")
            if request then
                local file = fs.open("wpp.lua", "w")
                if file then
                    file.write(request.readAll())
                    file.close()
                end
                request.close()
                ok, wpp = pcall(require, "wpp")
                if not ok then
                    err = wpp
                    ok, wpp = pcall(dofile, shell.resolve("wpp.lua"))
                    if not ok then err = wpp end
                end
            else
                print("ERROR: http request failed.")
            end
        else
            print("ERROR: http API is disabled in ComputerCraft config.")
        end
    end

    if ok and type(wpp) == "table" and wpp.wireless then
        wpp.wireless.connect(config.wireless_network)
        periph = wpp.peripheral
        print("Connected to wireless network: " .. config.wireless_network)
    else
        print("WARNING: Failed to load wireless API. Falling back to wired.")
        if type(err) == "string" then print("Error: " .. err) end
    end
end

----------------------------------------------------------------------------
-- INITIALIZATION
----------------------------------------------------------------------------

-- Initialize Monitor(s)
-- Multiple monitors are supported to separate the lists logically.
local monitors = { periph.find("monitor") }
if #monitors == 0 then 
    print("No monitors found. Running in headless mode.") 
else
    for _, mon in ipairs(monitors) do
        mon.setTextScale(0.5)
        mon.clear()
        mon.setCursorPos(1, 1)
        mon.setCursorBlink(false)
    end
    print(#monitors .. " Monitor(s) initialized.")
end

-- Initialize RS Bridge
local bridge = periph.find("rsBridge")
if not bridge then error("RS Bridge not found.") end
print("RS Bridge initialized.")

-- Initialize Colony Integrator
local colony = periph.find("colonyIntegrator")
if not colony then error("Colony Integrator not found.") end
if not colony.isInColony() then error("Colony Integrator is not in a colony.") end
print("Colony Integrator initialized.")

print("Storage initialized.")

----------------------------------------------------------------------------
-- FUNCTIONS
----------------------------------------------------------------------------

-- Prints strings left, centered, or right justified at a specific row and
-- specific foreground/background color.
function mPrintRowJustified(mon, y, pos, text, ...)
    local arg = {...}
    local w, h = mon.getSize()
    if y > h then return end

    local fg = mon.getTextColor()
    local bg = mon.getBackgroundColor()

    local x = 1
    if pos == "center" then x = math.floor((w - #text) / 2) + 1 end
    if pos == "right" then x = w - #text + 1 end
    if x < 1 then x = 1 end

    if #arg > 0 then mon.setTextColor(arg[1]) end
    if #arg > 1 then mon.setBackgroundColor(arg[2]) end
    mon.setCursorPos(x, y)
    mon.write(text)
    mon.setTextColor(fg)
    mon.setBackgroundColor(bg)
end


-- Utility function that displays current time and remaining time on timer.
-- For time of day, yellow is day, orange is sunset/sunrise, and red is night.
-- The countdown timer is orange over 15s, yellow under 15s, and red under 5s.
-- At night, the countdown timer is red and shows PAUSED insted of a time.
function displayTimer(monitors, t)
    local now = os.time()

    local cycle = "day"
    local cycle_color = colors.orange
    if now >= 5 and now < 6 then
        cycle = "sunrise"
        cycle_color = colors.orange
    elseif now >= 6 and now < 18 then
        cycle = "day"
        cycle_color = colors.yellow
    elseif now >= 18 and now < 19.5 then
        cycle = "sunset"
        cycle_color = colors.orange
    elseif now >= 19.5 or now < 5 then
        cycle = "night"
        cycle_color = colors.red
    end

    local timer_color = colors.orange
    if t < 15 then timer_color = colors.yellow end
    if t < 5 then timer_color = colors.red end

    for _, mon in ipairs(monitors) do
        local w, h = mon.getSize()
        mon.setCursorPos(1, 1)
        mon.setBackgroundColor(colors.gray)
        mon.write(string.rep(" ", w))

        local time_str = string.format(" Time: %s [%-7s]", textutils.formatTime(now, false), cycle)
        mPrintRowJustified(mon, 1, "left", time_str, cycle_color, colors.gray)

        mPrintRowJustified(mon, 1, "center", "[Update]", colors.lightBlue, colors.gray)

        local rem_str = "Paused "
        if not config.ignore_night or cycle ~= "night" then 
            rem_str = string.format("Next Scan: %ds ", t) 
        end
        mPrintRowJustified(mon, 1, "right", rem_str, timer_color, colors.gray)
        mon.setBackgroundColor(colors.black)
    end
end

-- Scan all open work requests from the Warehouse and attempt to satisfy those
-- requests.  Display all activity on the monitor, including time of day and the
-- countdown timer before next scan.  This function is not called at night to
-- save on some ticks, as the colonists are in bed anyways.  Items in red mean
-- work order can't be satisfied by Refined Storage (lack of pattern or lack of
-- required crafting ingredients).  Yellow means order partially filled and a
-- crafting job was scheduled for the rest.  Green means order fully filled.
-- Blue means the Player needs to manually fill the work order.  This includes
-- equipment (Tools of Class), NBT items like armor, weapons and tools, as well
-- as generic requests ike Compostables, Fuel, Food, Flowers, etc.
function scanWorkRequests(monitors, rs, chest)
    -- Before we do anything, prep the log file for this scan.
    -- The log file is truncated each time this function is called.
    local file = fs.open(config.log_file, "w")
    if file then
        file.write("--- Scan at " .. textutils.formatTime(os.time(), false) .. " ---\n")
    end
    print("\nScan starting at", textutils.formatTime(os.time(), false) .. " (" .. os.time() ..").")

    -- We want to keep three different lists so that they can be
    -- displayed on the monitor in a more intelligent way.  The first
    -- list is for the Builder requests.  The second list is for the
    -- non-Builder requests.  The third list is for any armor, tools
    -- and weapons requested by the colonists.
    local builder_list = {}
    local nonbuilder_list = {}
    local equipment_list = {}
    local missing_patterns_list = {}
    local chest_full = false

    -- Helpers to save immense server overhead and prevent redundant API calls
    local item_array = {}
    local function get_rs_stock(name)
        if item_array[name] == nil then
            local ok, item = pcall(rs.getItem, {name = name})
            if ok and type(item) == "table" and not item.nbt then
                item_array[name] = item.amount
            else
                item_array[name] = 0
            end
        end
        return item_array[name]
    end

    local craftable_cache = {}
    local function check_craftable(name)
        if craftable_cache[name] == nil then
            local ok, res = pcall(rs.isItemCraftable, {name = name})
            craftable_cache[name] = ok and res
        end
        return craftable_cache[name]
    end

    local crafting_cache = {}
    local function check_crafting(name)
        if crafting_cache[name] == nil then
            local ok, res = pcall(rs.isItemCrafting, {name = name})
            crafting_cache[name] = ok and res
        end
        return crafting_cache[name]
    end

    -- Scan the Warehouse for all open work requests. For each item, try to
    -- provide as much as possible from RS, then craft whatever is needed
    -- after that. Green means item was provided entirely. Yellow means item
    -- is being crafted. Red means item is missing crafting recipe.
    local ok, workRequests = pcall(colony.getRequests)
    if not ok or type(workRequests) ~= "table" then
        print("[Error] Failed to get work requests.")
        if file then
            file.write("Failed to get work requests.\n")
            file.close()
        end
        return
    end
    if file then
        pcall(function() file.write(textutils.serialize(workRequests, { allow_repetitions = true })) end)
    end
    for w, request in ipairs(workRequests) do
        local name = request.name or "Unknown"
        local desc = request.desc or ""
        local target = request.target or ""
        local needed = request.count or 1
        local provided = 0

        -- Guard against requests with no items
        if type(request.items) ~= "table" or not request.items[1] then
            print("[Skipped] No item data for:", name)
            goto continue
        end
        
        -- Pick the best alternative item (highest stock in RS), fallback to first
        local item = request.items[1].name
        local best_stock = get_rs_stock(item)
        local craftable_status = nil

        for i = 2, #request.items do
            local cname = request.items[i].name
            local cstock = get_rs_stock(cname)
            
            local current_sufficient = best_stock >= needed
            local candidate_sufficient = cstock >= needed

            if candidate_sufficient and not current_sufficient then
                item = cname
                best_stock = cstock
                craftable_status = nil
            elseif not current_sufficient and not candidate_sufficient then
                if craftable_status == nil then
                    craftable_status = check_craftable(item)
                end
                local c_craftable = check_craftable(cname)
                
                if c_craftable and not craftable_status then
                    item = cname
                    best_stock = cstock
                    craftable_status = true
                elseif (c_craftable == craftable_status) and (cstock > best_stock) then
                    item = cname
                    best_stock = cstock
                    craftable_status = c_craftable
                end
            elseif candidate_sufficient and current_sufficient then
                if cstock > best_stock then
                    item = cname
                    best_stock = cstock
                    craftable_status = nil
                end
            end
        end

        local target_words = {}
        local target_length = 0
        for word in target:gmatch("%S+") do
            table.insert(target_words, word)
            target_length = target_length + 1
        end

        local target_name
        if target_length >= 3 then target_name = target_words[target_length-1] .. " " .. target_words[target_length]
        else target_name = target end

        local target_type = ""
        if target_length >= 3 then
            for i = 1, target_length - 2 do
                if target_type ~= "" then target_type = target_type .. " " end
                target_type = target_type .. target_words[i]
            end
        end

        local useRS = true
        -- Items that should be manually provided (equipment, generic requests)
        if config.skip_exact[name] then useRS = false end
        for _, pat in ipairs(config.skip_patterns) do
            if string.find(name, pat, 1, true) or string.find(desc, pat, 1, true) then
                useRS = false
                break
            end
        end
        if config.enable_equipment_delivery and string.find(desc, "of class", 1, true) then
            useRS = true
        end

        local color = colors.blue
        if useRS then
            local stock_available = get_rs_stock(item)
            
            if chest_full then
                -- Skip API calls if the chest is undeniably full
                provided = 0
            elseif stock_available > 0 then
                local ok_export, result = pcall(rs.exportItemToPeripheral, {name=item, count=needed}, chest)
                if ok_export and type(result) == "number" then provided = result end
                item_array[item] = stock_available - provided
            end

            color = colors.green
            if provided < needed then
                local missing_to_craft = math.max(0, needed - provided - get_rs_stock(item))

                if missing_to_craft > 0 then
                    local is_crafting = check_crafting(item)
                    if is_crafting then
                        color = colors.yellow
                        print("[Crafting]", item)
                    else
                        local craft_amount = math.min(missing_to_craft, config.max_craft_amount)
                        local ok_craft, craft_ok = pcall(rs.craftItem, {name = item, count = craft_amount})
                        if ok_craft and craft_ok then
                            crafting_cache[item] = true
                            color = colors.yellow
                            print("[Scheduled]", craft_amount, "x", item)
                        else
                            color = colors.red
                            print("[Failed Craft/Pattern]", item)
                            missing_patterns_list[item] = true
                        end
                    end
                else
                    color = colors.red
                    chest_full = true
                    print("[Export Failed]", needed - provided, "x", item, "(Chest Full)")
                end
            end
        else
            local nameString = name .. " [" .. target .. "]"
            print("[Skipped]", nameString)
        end

        if string.find(desc, "of class", 1, true) then
            local level = "Any Level"
            local level_map = { "Leather", "Gold", "Chain", "Wood or Gold", "Stone", "Iron", "Diamond" }
            for _, lvl in ipairs(level_map) do
                if string.find(desc, "with maximal level:" .. lvl, 1, true) then
                    level = lvl
                    break
                end
            end
            local new_name = level .. " " .. name
            if level == "Any Level" then new_name = name .. " of any level" end
            local new_target = target_length < 3 and target or target_type .. " " .. target_name
            local equipment = { name=new_name, target=new_target, needed=needed, provided=provided, color=color}
            table.insert(equipment_list, equipment)
        elseif string.find(target, "Builder", 1, true) then
            local builder = { name=name, item=item, target=target_name, needed=needed, provided=provided, color=color }
            table.insert(builder_list, builder)
        else
            local new_target = target_length < 3 and target or target_type .. " " .. target_name
            local nonbuilder = { name=name, target=new_target, needed=needed, provided=provided, color=color }
            table.insert(nonbuilder_list, nonbuilder)
        end
        ::continue::
    end

    -- Show the various lists on the attached monitor(s).
    for _, mon in ipairs(monitors) do
        mon.clear()
    end

    local function drawCategory(mon, title, list, start_row)
        local row = start_row
        local mon_width, mon_height = mon.getSize()
        
        local function drawBanner(text)
            if row > 3 then row = row + 1 end
            if row > mon_height then return end
            mon.setCursorPos(1, row)
            mon.setBackgroundColor(colors.gray)
            mon.write(string.rep(" ", mon_width))
            mPrintRowJustified(mon, row, "center", text, colors.white, colors.gray)
            mon.setBackgroundColor(colors.black)
            row = row + 1
        end

        local function truncate(name, max_len)
            if #name <= max_len then return name end
            if max_len > 2 then return string.sub(name, 1, max_len - 2) .. ".." end
            return string.sub(name, 1, math.max(0, max_len))
        end

        local header_shown = false
        for _, item in ipairs(list) do
            if row > mon_height then break end
            if not header_shown then
                drawBanner(title)
                header_shown = true
            end
            if row > mon_height then break end
            local prefix = ""
            if title == "Equipment" then
                prefix = string.format("%d ", item.needed)
            else
                prefix = string.format("%d/%d ", item.provided, item.needed)
            end
            local max_name = math.max(1, mon_width - #prefix - (#item.target + 1))
            local name = truncate(item.name, max_name)
            mPrintRowJustified(mon, row, "left", prefix .. name, item.color)
            mPrintRowJustified(mon, row, "right", " " .. item.target, item.color)
            row = row + 1
        end
        return row
    end

    local m_idx = 1
    local row = 3

    if #monitors > 0 then
        if #equipment_list > 0 then
            row = drawCategory(monitors[m_idx], "Equipment", equipment_list, row)
        end

        if #builder_list > 0 then
            if #monitors > 1 then
                m_idx = 2
                row = 3
            end
            row = drawCategory(monitors[m_idx], "Builder Requests", builder_list, row)
        end

        if #nonbuilder_list > 0 then
            if #monitors > 2 then
                m_idx = 3
                row = 3
            elseif #monitors == 2 and #builder_list == 0 then
                m_idx = 2
                row = 3
            end
            row = drawCategory(monitors[m_idx], "Nonbuilder Requests", nonbuilder_list, row)
        end
    end

    for _, mon in ipairs(monitors) do
        local w, h = mon.getSize()
        mon.setCursorPos(1, 2)
        if chest_full then
            mon.setBackgroundColor(colors.red)
            mon.write(string.rep(" ", w))
            mPrintRowJustified(mon, 2, "center", "WARNING: OUTPUT CHEST FULL", colors.white, colors.red)
        else
            mon.setBackgroundColor(colors.gray)
            mon.write(string.rep(" ", w))
            local title = string.format("Eq: %d | Bld: %d | Oth: %d", #equipment_list, #builder_list, #nonbuilder_list)
            mPrintRowJustified(mon, 2, "center", title, colors.white, colors.gray)
        end
        mon.setBackgroundColor(colors.black)
    end

    if #monitors > 0 and #equipment_list == 0 and #builder_list == 0 and #nonbuilder_list == 0 then
        local mon = monitors[1]
        local mon_width, mon_height = mon.getSize()
        local r = chest_full and 4 or 3
        mon.setCursorPos(1, r)
        mon.setBackgroundColor(colors.gray)
        mon.write(string.rep(" ", mon_width))
        mPrintRowJustified(mon, r, "center", "No Open Requests", colors.white, colors.gray)
        mon.setBackgroundColor(colors.black)
    end

    -- Write missing patterns to file for easy reference
    local mp_file = fs.open("missing_patterns.txt", "w")
    if mp_file then
        for p, _ in pairs(missing_patterns_list) do
            mp_file.write(p .. "\n")
        end
        mp_file.close()
    end

    print("Scan completed at", textutils.formatTime(os.time(), false) .. " (" .. os.time() ..").")
    if file then file.close() end
end

----------------------------------------------------------------------------
-- MAIN
----------------------------------------------------------------------------

-- Scan for requests periodically. This will catch any updates that were
-- triggered from the previous scan. Right-clicking on the monitor will
-- trigger an immediate scan and reset the timer. Unfortunately, there is
-- no way to capture left-clicks on the monitor.
local current_run = config.time_between_runs
scanWorkRequests(monitors, bridge, config.storage_side)
displayTimer(monitors, current_run)
local TIMER = os.startTimer(1)

while true do
    local e = {os.pullEvent()}
    if e[1] == "timer" and e[2] == TIMER then
        local now = os.time()
        if not config.ignore_night or (now >= 5 and now < 19.5) then
            current_run = current_run - 1
            if current_run <= 0 then
                scanWorkRequests(monitors, bridge, config.storage_side)
                current_run = config.time_between_runs
            end
        end
        displayTimer(monitors, current_run)
        TIMER = os.startTimer(1)
    elseif e[1] == "char" then
        if e[2] == "u" or e[2] == "U" then
            checkForUpdates()
        end
    elseif e[1] == "monitor_touch" then
        local side = e[2]
        local x = e[3]
        local y = e[4]
        
        local is_update_click = false
        if y == 1 then
            local mon = peripheral.wrap(side)
            if mon then
                local w = mon.getSize()
                local center_x = math.floor((w - #"[Update]") / 2) + 1
                if x >= center_x and x < center_x + #"[Update]" then
                    is_update_click = true
                end
            end
        end

        if is_update_click then
            checkForUpdates()
        else
            os.cancelTimer(TIMER)
            scanWorkRequests(monitors, bridge, config.storage_side)
            current_run = config.time_between_runs
            displayTimer(monitors, current_run)
            TIMER = os.startTimer(1)
        end
    end
end