-- remote_host.lua
-- Auto-updater, WPP wrapper, and dashboard for Warehost Remote Monitors

local VERSION = "GIT_HASH_PLACEHOLDER"

local args = {...}
local network = args[1] or "warehouse_net"

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

local function drawMetrics(events, tick)
    local x, y = term.getCursorPos()
    term.setCursorPos(1, 8)
    cprint(" Active Metrics:", colors.white)
    cprint("  - Serviced Requests : " .. events .. "    ", colors.lightGray)
    cprint("  - Uptime            : " .. tick .. "s    ", colors.lightGray)
    term.setCursorPos(x, y)
end

-- 1. Auto Updater
local function checkForUpdates()
    if http then
        local url = "https://raw.githubusercontent.com/KilianSen/cc-tweaked-refinedstorage-minecolonies-integration/main/remote_host.lua"
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
            if remote_code and #remote_code > 0 then
                local new_hash = "unknown"
                local api_req = http.get("https://api.github.com/repos/KilianSen/cc-tweaked-refinedstorage-minecolonies-integration/commits/main")
                if api_req then
                    local data = textutils.unserializeJSON(api_req.readAll())
                    api_req.close()
                    if data and data.sha then new_hash = data.sha:sub(1, 7) end
                end

                local pattern = 'local VER' .. 'SION = "[^"]+"'
                local clean_remote = remote_code:gsub(pattern, 'local VER' .. 'SION = "temp"')
                local clean_current = current_code:gsub(pattern, 'local VER' .. 'SION = "temp"')

                if clean_remote ~= clean_current then
                    local ph_pattern = 'local VER' .. 'SION = "GIT_HASH_PLACEHOLDER"'
                    remote_code = remote_code:gsub(ph_pattern, 'local VER' .. 'SION = "' .. new_hash .. '"')

                    local out = fs.open(program_path, "w")
                    if out then
                        out.write(remote_code)
                        out.close()
                    end
                    os.sleep(1)
                    os.reboot()
                end
            end
        end
    end
end

checkForUpdates()

-- 2. Make sure WPP is downloaded
if not fs.exists("wpp.lua") then
    cprint(" Downloading wpp.lua...", colors.yellow)
    if http then
        local req = http.get("https://raw.githubusercontent.com/jdf221/CC-WirelessPeripheral/main/wpp.lua")
        if req then
            local f = fs.open("wpp.lua", "w")
            if f then f.write(req.readAll()); f.close() end
            req.close()
        end
    end
end

local ok, wpp, err = false, nil, nil
ok, wpp = pcall(require, "wpp")
if not ok then
    err = wpp
    ok, wpp = pcall(dofile, shell.resolve("wpp.lua"))
    if not ok then err = wpp end
end

if not ok or type(wpp) ~= "table" or not wpp.wireless then
    error("Missing or invalid wpp.lua! Error: " .. tostring(err))
end

-- 3. Draw Dashboard
term.clear()
term.setCursorPos(1, 1)

cprint("==========================================", colors.cyan)
cprint("    Warehost Remote Monitor Server v" .. VERSION, colors.white)
cprint("==========================================", colors.cyan)
cprint(" Network ID : " .. network, colors.lightGray)
cprint(" Host ID    : " .. os.getComputerID(), colors.lightGray)

term.setCursorPos(1, 12)
cprint(" Attached Monitors:", colors.white)
local monitors = {}
for _, m in ipairs(peripheral.getNames()) do
    if peripheral.getType(m) == "monitor" then
        cprint("  - " .. m, colors.lightGray)
        table.insert(monitors, m)
    end
end
if #monitors == 0 then cprint("  None detected.", colors.lightGray) end

term.setCursorPos(1, 18)
cprint(" Press Ctrl+T to Terminate Server.", colors.red)

-- 4. Initialize Networking
wpp.wireless.connect(network)
rednet.host("wpp@" .. network, tostring(os.getComputerID()))

local eventsHandled = 0
local uptime = 0
local TIMER = os.startTimer(1)

drawMetrics(eventsHandled, uptime)

-- 5. Infinite Event Loop
while true do
    local e = {os.pullEvent()}

    if e[1] == "timer" and e[2] == TIMER then
        uptime = uptime + 1
        drawMetrics(eventsHandled, uptime)
        TIMER = os.startTimer(1)

        -- Auto update check every real world hour (3600 seconds)
        if uptime % 3600 == 0 then
            checkForUpdates()
        end
    elseif e[1] == "char" and (e[2] == "u" or e[2] == "U") then
        checkForUpdates()
    elseif e[1] == "rednet_message" and e[4] == "wpp@" .. network then
        eventsHandled = eventsHandled + 1
        drawMetrics(eventsHandled, uptime)
    end

    -- Pass payload to wpp handler
    wpp.wireless.localEventHandler(e)
end
