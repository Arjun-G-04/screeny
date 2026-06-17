# Screeny — Menu Bar Walk Reminder

A native macOS background menu bar application that periodically interrupts you with a fullscreen **"Walk"** overlay. Dismiss it only by clicking **Skip** 20 times.

Built with Swift + AppKit. Runs continuously in the background, managed via macOS `launchd`.

---

## Features

* **Native Menu Bar Interface**: Features a clean walking figure (`figure.walk`) system status icon showing a live countdown, instant break trigger, pause controls, and interval presets.
* **Vibrant Circular Progress Indicator**: Visualizes the 90-second timeout using a custom-drawn, system-orange countdown progress ring.
* **Advanced Battery & CPU Optimization**:
  - **Dynamic Timer Scaling**: Ticks every **10 seconds** normally, boosting to **1 second** only when you open the menu bar item to display a smooth, real-time countdown.
  - **Sleep Observability**: Completely pauses all timers when screens sleep (such as walking away or closing the lid), ensuring **0% CPU usage** when idle.
  - **Zero Disk I/O**: Keeps state in memory to preserve SSD health and minimize energy consumption, saving to disk only when configurations or break state changes.
* **Smart Sleep Reset**: Automatically recalculates breaks if you've been away (computer slept or locked) for **60 seconds or more**, counting it as a completed walk.

---

## Installation & Uninstallation

### To Install:

```bash
chmod +x install.sh
./install.sh
```

This compiles the Swift binary in release mode, installs it to `/usr/local/bin/screeny`, configures the launch agent plist in `~/Library/LaunchAgents/`, and loads the background service immediately. You will be prompted for your password once to authorize copying the binary.

### To Uninstall:

```bash
chmod +x uninstall.sh
./uninstall.sh
```

This unloads the background service, terminates any running Screeny instances, deletes the plist and binary files, and cleans up the persistent state folder (`~/.screeny`).

---

## Usage

Simply look at your macOS menu bar! Left-clicking the walking figure icon reveals the following controls:
* **Countdown Status**: Displays the exact minutes and seconds remaining until the next break.
* **Take Break Now**: Manually start the break overlay immediately.
* **Change Interval**: Choose from presets (20, 30, 40, or 60 minutes) or input a custom interval using the input dialog.
* **Pause / Resume**: Temporarily suspend the breaks (persisted across app restarts).
* **Quit Screeny**: Completely close the application.

---

## File Locations

| File | Location |
|------|----------|
| Binary | `/usr/local/bin/screeny` |
| Launch agent | `~/Library/LaunchAgents/com.arjun.walknotifier.plist` |
| State (last fired, interval, pause state) | `~/.screeny/state.json` |
| Logs | `/tmp/walknotifier.out` & `/tmp/walknotifier.err` |
