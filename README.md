# Warehost: Minecolonies & Refined Storage Integration

Automaticaly fulfill your Minecolonies Warehouse requests using your Refined Storage system via CC:Tweaked and Advanced Peripherals!

**Warehost** is an automated script that monitors your Minecolonies open work requests and attempts to satisfy them using items stored in your Refined Storage network. If the required items are missing but a crafting pattern is available, the script will even schedule an auto-crafting job for you!

---

## 🚀 Quick Install (One-Line Setup)

Setting up the script is extremely easy using the interactive auto-installer. 
Drop a Computer (or Advanced Computer), attach the peripherals, and run this single command in the ComputerCraft terminal:

```shell
wget run https://raw.githubusercontent.com/KilianSen/cc-tweaked-refinedstorage-minecolonies-integration/main/install.lua
```

The installer will:
1. Detect and verify your connected peripherals.
2. Find the correct storage container (including modded variants like Entangled blocks).
3. Download the latest `warehost.lua` code.
4. Walk you through setting up your configuration.
5. Create a `startup.lua` file so the script runs automatically when you reboot the computer or chunk load.

---

## 📦 Requirements

### Mods
- **CC: Tweaked** (ComputerCraft)
- **Advanced Peripherals**
- **Refined Storage**
- **Minecolonies**

### In-Game Setup
To run the system, you must physically connect the following blocks to your computer (either adjacently or via Wired Modems):

1. **Computer** or **Advanced Computer**
2. **Colony Integrator** (from Advanced Peripherals, placed inside your colony boundaries).
3. **RS Bridge** (from Advanced Peripherals, connected to your Refined Storage network).
4. A **Storage Container** (e.g. Minecraft Chest, Entangled Block). This container should be connected to the Minecolonies Warehouse Hut block so builders can access delivered items.
5. *(Optional)* **Monitor(s)** (Advanced Monitors recommended; a 3x3 screen works excellently). You can run this completely monitor-less (Headless Mode) to save space, or use **Remote Monitors** (see below).

---

## 📡 Remote Monitor Setup (Wireless Networking)

If you'd like your monitors positioned far away from the main colony/storage area, Warehost seamlessly integrates with [CC-WirelessPeripheral](https://github.com/jdf221/CC-WirelessPeripheral) to control Remote Monitors anywhere in your world!

**How to set it up:**
1. Attach an **Ender Modem** or regular **Wireless Modem** to the main Warehost computer.
2. Build a new remote computer wherever you want your display, and attach your **Monitor(s)** and a **Wireless Modem** to it.
3. On this new remote computer, run the Remote Auto-Setup installer:
   ```shell
   wget run https://raw.githubusercontent.com/KilianSen/cc-tweaked-refinedstorage-minecolonies-integration/main/setup_remote.lua
   ```
4. Follow the prompt to name your network (default is `warehouse_net`). This will automatically download the necessary dependencies and set your monitors to broadcast on startup!
5. Finally, on your **main** Warehost computer, run the primary `install.lua` installer. When asked to "Enable Wireless Peripherals", type **y** and enter the same network name (`warehouse_net`). Warehost will automatically connect and render your dashboard remotely!

---

## ✨ Features

- **Smart Fulfillment**: Prioritizes existing RS stock. If missing, it schedules crafting jobs for exact quantities.
- **Categorized Dashboard**: Sorts unfulfilled requests into categorizes (Equipment/Tools, Builder Requests, and Other) cleanly onto attached Monitors.
- **Night-Mode Optimization**: Pauses scanning operations at night, preserving server TPS and ticks when Colonists are sleeping and inactive anyway.
- **Automated Fallbacks**: Selects the best alternative block options if a request lists multiple fulfilling items.
- **Auto Updater**: Built-in update system that checks for the latest script patches on launch to ensure stability. 

## 🛠️ Configuration
If you ever want to change settings later, the auto-installer creates a file called `config.json`. You can edit it manually via `edit config.json` to alter settings such as:
- Maximum items to craft per job.
- Blacklisted items to exclude from automatic export (like specific tiered tools, armors, or raw materials).
- Wait time (seconds) between automatic scans.
