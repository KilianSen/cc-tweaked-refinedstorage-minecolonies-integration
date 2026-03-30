-- setup_remote.lua
-- Auto-setup script for remote monitors

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

term.clear()
term.setCursorPos(1, 1)
cprint("==========================================", colors.cyan)
cprint("  Warehost Remote Monitor Auto-Setup", colors.yellow)
cprint("==========================================", colors.cyan)
print("")

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
        cprint(" [\251] Downloaded wpp.lua successfully!", colors.green)
    else
        cprint(" [X] Failed to download wpp.lua. Cannot continue.", colors.red)
        return
    end
else
    cprint(" [X] HTTP API is disabled! Cannot download wpp.lua.", colors.red)
    return
end
print("")

local old = term.getTextColor()
if term.isColor() then term.setTextColor(colors.white) end
write("Enter a network name to broadcast on [warehouse_net]: ")
local input = read()
if term.isColor() then term.setTextColor(old) end

local network_name = "warehouse_net"
if input ~= "" then
    network_name = input
end
print("")

local sf = fs.open("startup.lua", "w")
if sf then
    sf.write('shell.run("wpp", "host", "' .. network_name .. '")\n')
    sf.close()
    cprint(" [\251] startup.lua created! (will auto-host on reboot)", colors.green)
end
print("")

cprint("==========================================", colors.cyan)
cprint(" Setup Complete! Starting Host Mode...", colors.green)
cprint("==========================================", colors.cyan)
os.sleep(1)

shell.run("wpp", "host", network_name)
