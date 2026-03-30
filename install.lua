-- install.lua
-- Auto-setup script for Warehost

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
cprint("    Warehost Auto-Setup & Debugger", colors.yellow)
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

local function waitForPeripheral(pType, friendlyName)
    local first = true
    while true do
        local p = peripheral.find(pType)
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

cprint("--- 1. Peripheral Check ---", colors.cyan)
cprint("Waiting for all required peripherals...", colors.lightGray)

local use_monitor = prompt("Are you using a directly connected Monitor? (Type 'n' for headless or remote monitors) (Y/n)", "Y")
if use_monitor:lower() == "y" then
    waitForPeripheral("monitor", "Monitor")
else
    cprint(" [!] Skipping monitor verification.", colors.orange)
end
waitForPeripheral("rsBridge", "RS Bridge")
waitForPeripheral("colonyIntegrator", "Colony Integrator")
print("")

cprint("--- 2. Storage Setup ---", colors.cyan)
cprint("Scanning for inventories (chests, entangled blocks, etc.)...", colors.lightGray)

local inventories = {}
-- pcall around peripheral.getNames() to avoid crash if some peripheral is broken
local ok, names = pcall(peripheral.getNames)
if ok and names then
    for _, side in ipairs(names) do
        if peripheral.hasType(side, "inventory") then
            local types = {peripheral.getType(side)}
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

cprint("--- 3. Night Mode ---", colors.cyan)
local ignore_night_ans = prompt("Pause processing during night time? (Saves server ticks) (Y/n)", "Y")
local ignore_night = ignore_night_ans:lower() == "y"
print("")

cprint("--- 4. Wireless Setting ---", colors.cyan)
local wireless_ans = prompt("Are you using Advanced Peripherals Wireless functionality? (y/N)", "N")
local enable_wireless = wireless_ans:lower() == "y"
local wireless_network = "warehouse_net"
if enable_wireless then
    wireless_network = prompt("Enter your wireless network name", "warehouse_net")
end
print("")

cprint("--- Downloading Scripts ---", colors.cyan)
local url = "https://raw.githubusercontent.com/KilianSen/cc-tweaked-refinedstorage-minecolonies-integration/main/warehost.lua"
cprint("Downloading warehost.lua from GitHub...", colors.yellow)

if http then
    local ok, request = pcall(http.get, url)
    if ok and request then
        local content = request.readAll()
        request.close()
        
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
