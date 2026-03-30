-- install.lua
-- Auto-setup script for Warehost
local VERSION = "GIT_HASH_PLACEHOLDER"

local function getLatestHash()
    if not http then return "unknown" end
    local ok, req = pcall(http.get, "https://api.github.com/repos/KilianSen/cc-tweaked-refinedstorage-minecolonies-integration/commits/main")
    if ok and req then
        local data = textutils.unserializeJSON(req.readAll())
        req.close()
        if data and data.sha then return data.sha:sub(1, 7) end
    end
    return "unknown"
end

local actual_version = getLatestHash()
if VERSION == "GIT_HASH_PLACEHOLDER" then
    VERSION = actual_version
end

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

-- Clear screen and show banner
term.clear()
term.setCursorPos(1, 1)
cprint("==========================================", colors.cyan)
cprint("    Warehost Auto-Setup & Debugger v" .. VERSION, colors.yellow)
cprint("==========================================", colors.cyan)
print("")

local function prompt(msg, default_val)
    if term.isColor() then
        term.setTextColor(colors.white)
    end
    write(msg .. (default_val and (" [" .. default_val .. "]: ") or ": "))
    local input = read()
    if input == "" and default_val then
        return default_val
    end
    return input
end

cprint("Select Installation Mode:", colors.cyan)
cprint(" 1) Main Warehost Server (Coordinates RS & Minecolonies)", colors.lightGray)
cprint(" 2) Remote Monitor Client (Hosts Wireless Monitors)", colors.lightGray)
local mode = ""
while mode ~= "1" and mode ~= "2" do
    mode = prompt("Enter 1 or 2", "1")
end
print("")

if mode == "2" then
    cprint("--- Remote Monitor Setup ---", colors.cyan)
    local has_modem = false
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "modem" then
            local m = peripheral.wrap(name)
            if m.isWireless() then
                has_modem = true
                break
            end
        end
    end

    if not has_modem then
        cprint(" [X] No Wireless Modem found!", colors.red)
        cprint(" Please attach an Ender or Wireless Modem and run this again.", colors.orange)
        return
    end

    cprint(" Downloading remote_host.lua...", colors.yellow)
    if http then
        local ok_http, req = pcall(http.get, "https://raw.githubusercontent.com/KilianSen/cc-tweaked-refinedstorage-minecolonies-integration/main/remote_host.lua")
        if ok_http and req then
            local f = fs.open("remote_host.lua", "w")
            if f then
                local content = req.readAll()
                content = content:gsub('local VERSION = "GIT_HASH_PLACEHOLDER"', 'local VERSION = "' .. actual_version .. '"')
                f.write(content)
                f.close()
            end
            req.close()
            cprint(" [\251] Downloaded remote_host.lua!", colors.green)
        else
            cprint(" [X] Failed to download remote_host.lua. Cannot continue.", colors.red)
            return
        end
    else
        cprint(" [X] HTTP API is disabled! Cannot download remote_host.lua.", colors.red)
        return
    end
    print("")

    local player_name = prompt("What is your Player Name?", "Player")
    local default_network = player_name .. "_warehouse"
    local network_name = prompt("Enter a network name to broadcast on", default_network)
    print("")

    local sf = fs.open("startup.lua", "w")
    if sf then
        sf.write('shell.run("remote_host.lua", "' .. network_name .. '")\n')
        sf.close()
        cprint(" [\251] startup.lua created! (will auto-host on reboot)", colors.green)
    end
    print("")

    cprint("==========================================", colors.cyan)
    cprint(" Setup Complete! Starting Host Mode...", colors.green)
    cprint("==========================================", colors.cyan)
    os.sleep(1)

    shell.run("remote_host.lua", network_name)
    return
end

local periph = peripheral

cprint("--- 1. Wireless Networking ---", colors.cyan)
cprint("You can connect remote monitors & blocks using CC Wireless Modems.", colors.lightGray)
local wireless_ans = prompt("Enable Wireless Peripherals? (y/N)", "N")
local enable_wireless = wireless_ans:lower() == "y"
local wireless_network = "warehouse_net"

if enable_wireless then
    local player_name = prompt(" What is your Player Name?", "Player")
    local default_network = player_name .. "_warehouse"
    cprint(" Make sure your remote computer is broadcasting its peripherals.", colors.white)
    cprint(" (e.g. running 'wpp host " .. default_network .. "')", colors.lightGray)
    wireless_network = prompt(" Enter your wireless network name", default_network)
    
    cprint(" Downloading CC-WirelessPeripheral...", colors.yellow)
    if http then
        local ok_http, req = pcall(http.get, "https://raw.githubusercontent.com/jdf221/CC-WirelessPeripheral/main/wpp.lua")
        if ok_http and req then
            local f = fs.open("wpp.lua", "w")
            if f then
                f.write(req.readAll())
                f.close()
            end
            req.close()
        end
    end
    local ok, wpp, err = false, nil, nil
    ok, wpp = pcall(require, "wpp")
    if not ok then
        err = wpp
        ok, wpp = pcall(dofile, shell.resolve("wpp.lua"))
        if not ok then err = wpp end
    end
    if ok and type(wpp) == "table" and wpp.wireless then
        wpp.wireless.connect(wireless_network)
        periph = wpp.peripheral
        cprint(" [\251] Connected to wireless network!", colors.green)
    else
        cprint(" [X] Failed to setup wireless network. Falling back to local.", colors.red)
        if type(err) == "string" then cprint("     Error: " .. err, colors.orange) end
        enable_wireless = false
    end
end
print("")

local function waitForPeripheral(pType, friendlyName)
    local first = true
    while true do
        local p = periph.find(pType)
        if p then
            cprint(" [\251] " .. friendlyName .. " found!", colors.green)
            return p
        end
        if first then
            cprint(" [X] Missing " .. friendlyName .. " (" .. pType .. ")", colors.red)
            cprint("     Please connect it... (Waiting)", colors.orange)
            first = false
        end
        os.sleep(1) -- poll every second
    end
end

cprint("--- 2. Peripheral Check ---", colors.cyan)
cprint("Waiting for all required peripherals...", colors.lightGray)

local use_monitor = prompt("Are you using a Monitor? (Type 'n' for headless mode) (Y/n)", "Y")
if use_monitor:lower() == "y" then
    waitForPeripheral("monitor", "Monitor")
else
    cprint(" [!] Skipping monitor verification.", colors.orange)
end
waitForPeripheral("rsBridge", "RS Bridge")
waitForPeripheral("colonyIntegrator", "Colony Integrator")
print("")

cprint("--- 3. Storage Setup ---", colors.cyan)
cprint("Scanning for inventories (chests, entangled blocks, etc.)...", colors.lightGray)

local inventories = {}
-- pcall around periph.getNames() to avoid crash if some peripheral is broken
local ok, names = pcall(periph.getNames)
if ok and names then
    for _, side in ipairs(names) do
        local is_inv = false
        if type(periph.hasType) == "function" then
            pcall(function() is_inv = periph.hasType(side, "inventory") end)
        end
        if not is_inv then
            local tStr = periph.getType(side) or ""
            if tStr == "inventory" or tStr:find("chest") or tStr:find("barrel") or tStr:find("entangled") then
                is_inv = true
            else
                local mList = periph.getMethods(side)
                if mList then
                    local ml, ms = false, false
                    for _, m in ipairs(mList) do
                        if m == "list" then ml = true end
                        if m == "size" then ms = true end
                    end
                    is_inv = ml and ms
                end
            end
        end

        if is_inv then
            local types = {periph.getType(side)}
            local tStr = table.concat(types, ", ")
            table.insert(inventories, {side = side, type = tStr})
        end
    end
end

if #inventories == 0 then
    cprint(" [!] No inventories detected next to this computer or modems.", colors.orange)
    cprint("     Make sure your chest or Entangled block is connected.", colors.orange)
else
    cprint(" Detected inventories:", colors.white)
    for _, inv in ipairs(inventories) do
        local isEntangled = inv.type:find("entangled")
        local note = isEntangled and "  <- (Entangled Block)" or ""
        cprint("  - " .. inv.side .. " (" .. inv.type .. ")" .. note, colors.lightGray)
    end
end
print("")

local storage_side = ""
if #inventories == 1 then
    local default_side = inventories[1].side
    local ans = prompt("Use '" .. default_side .. "' as output storage side? (Y/n)", "Y")
    if ans:lower() == "y" then
        storage_side = default_side
    end
end

if storage_side == "" then
    while true do
        storage_side = prompt("Enter the side or network name of your output storage")
        if storage_side ~= "" then
            break
        end
    end
end
print("")

cprint("--- 4. Night Mode ---", colors.cyan)
local ignore_night_ans = prompt("Pause processing during night time? (Saves server ticks) (Y/n)", "Y")
local ignore_night = ignore_night_ans:lower() == "y"
print("")



cprint("--- Downloading Scripts ---", colors.cyan)
local url = "https://raw.githubusercontent.com/KilianSen/cc-tweaked-refinedstorage-minecolonies-integration/main/warehost.lua"
cprint("Downloading warehost.lua from GitHub...", colors.yellow)

if http then
    local ok, request = pcall(http.get, url)
    if ok and request then
        local content = request.readAll()
        request.close()
        
        content = content:gsub('local VERSION = "GIT_HASH_PLACEHOLDER"', 'local VERSION = "' .. actual_version .. '"')
        
        local f = fs.open("warehost.lua", "w")
        if f then
            f.write(content)
            f.close()
            cprint(" [\251] Downloaded warehost.lua safely.", colors.green)
        else
            cprint(" [X] Failed to save warehost.lua!", colors.red)
        end
    else
        cprint(" [X] Could not connect to GitHub or file not found.", colors.red)
    end
else
    cprint(" [X] http API is disabled. Please download warehost.lua manually.", colors.red)
end
print("")

cprint("--- Generating config.json ---", colors.cyan)
local config = {
    storage_side = storage_side,
    log_file = "RSWarehouse.log",
    ignore_night = ignore_night,
    time_between_runs = 30,
    max_craft_amount = 500,
    enable_equipment_delivery = false,
    enable_wireless = enable_wireless,
    wireless_network = wireless_network,
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
local f = fs.open("config.json", "w")
if f then
    f.write(textutils.serializeJSON(config))
    f.close()
    cprint(" [\251] config.json successfully created!", colors.green)
else
    cprint(" [X] Failed to create config.json!", colors.red)
end
print("")

cprint("--- Startup Config ---", colors.cyan)
local startup_ans = prompt("Do you want Warehost to run automatically on startup? (Y/n)", "Y")
if startup_ans:lower() == "y" then
    local sf = fs.open("startup.lua", "w")
    if sf then
        sf.write('shell.run("warehost.lua")\n')
        sf.close()
        cprint(" [\251] startup.lua created!", colors.green)
    end
end
print("")

cprint("==========================================", colors.cyan)
cprint(" Setup Complete! Starting Warehost...", colors.green)
cprint("==========================================", colors.cyan)
os.sleep(2)
shell.run("warehost.lua")
