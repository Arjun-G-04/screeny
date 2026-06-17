# Screeny Developer & AI Agent Guide (AGENTS.md)

Welcome to the **Screeny** codebase! This document is the ultimate reference guide for AI agents and human developers working on this project. It contains everything you need to know about the architecture, components, and how different parts of the system interact.

## 🎯 What is Screeny?

Screeny is a native macOS background menu bar application that periodically interrupts the user with a fullscreen **"Walk"** overlay. The goal is to enforce breaks by requiring the user to click a "Skip" button 20 times to dismiss the screen.

It is built using **Swift**, **AppKit**, and loaded as a persistent background process via macOS **launchd**.

---

## 🏗️ Architecture Overview

The system consists of:
1. **The Menu Bar Item (`NSStatusItem`):** Displays in the system menu bar using the `figure.walk` SF symbol. Left-clicking it reveals an interactive menu showing a live countdown, manual break trigger, interval settings (presets + custom input dialog), pause controls, and application termination.
2. **The Overlay UI:** When a break is due, the application transitions to a regular activation policy (`.regular`), displays a borderless fullscreen window on the main screen, and takes active focus. When completed, it transitions back to the background (`.accessory`) policy and resets the timer.

Unlike typical macOS Apps, Screeny does **not** have an `.app` bundle. It creates AppKit windows directly from a command-line compiled binary.

---

## 📂 File Structure & Components

All source code is located in `Sources/screeny/`.

| Component | Description |
|-----------|-------------|
| **`main.swift`** | The entry point. Handles single-instance validation and hosts the `MenuBarApp` delegate, which manages status items, system menu hooks, dynamic timers, and power-saving observers. |
| **`OverlayWindow.swift`** | Contains `OverlayViewController` and a custom `CircularProgressView` drawing a system-orange progress ring. Programmatically builds the borderless fullscreen window, tracks clicks, and reports back via a callback closure (`completionHandler`) upon dismissal. |
| **`StateManager.swift`** | Manages persistent state stored in `~/.screeny/state.json`. Tracks the `lastFired` Date, the `lastFiredUptime`, the `intervalSeconds`, and the `isPaused` flag to preserve state across application restarts and system reboots. |
| **`install.sh`** | The installation script. Compiles the Swift binary in release mode (`swift build -c release`), copies it to `/usr/local/bin`, installs the launch agent plist to `~/Library/LaunchAgents`, and loads it via `launchctl`. |
| **`uninstall.sh`** | The uninstallation script. Unloads the service, kills running processes, removes plist/binary files, and cleans up the state directory. |
| **`com.arjun.walknotifier.plist`** | The `launchd` configuration template. Configures macOS to execute `/usr/local/bin/screeny` once at login (`RunAtLoad = true`) and keep it running continuously in the background. |

---

## 🛠️ State & Configuration Locations

When manipulating or debugging the installed program, you must interact with the user's filesystem:

- **Installed Binary:** `/usr/local/bin/screeny`
- **Launch Agent Plist:** `~/Library/LaunchAgents/com.arjun.walknotifier.plist`
- **Application State:** `~/.screeny/state.json`
- **Logs:** Standard output and errors are routed by the plist to `/tmp/walknotifier.out` and `/tmp/walknotifier.err`.

---

## 🧠 Key Development Paradigms for Agents

### 1. The `launchd` Lifecycle
Instead of spawning a short-lived process periodically, `launchd` runs `/usr/local/bin/screeny` exactly once at load (login) and allows it to execute continuously as a background accessory app.

### 2. AppKit from the CLI
Because there is no Info.plist or `.app` bundle:
- Standard `applicationDidFinishLaunching` hooks can be unreliable.
- Windows must be created, configured, and ordered front *before* starting the event loop (`NSApp.run()`) or explicitly during runtime.
- We start with `NSApp.setActivationPolicy(.accessory)` to hide the Dock icon, and dynamically transition to `NSApp.setActivationPolicy(.regular)` + `NSApp.activate(ignoringOtherApps: true)` when presenting the overlay to grab focus. Once dismissed, we transition back to `.accessory`.

### 3. Battery & Performance Optimizations
To preserve battery life and keep CPU consumption at near 0%, Screeny implements three key optimizations:
* **Dynamic Timer Frequency**: When the menu dropdown is closed, checking occurs once every **10 seconds** (reducing CPU wakeups). When the menu is clicked open (`menuWillOpen`), the timer speed increases to **1 second** to display a smooth, ticking countdown, returning to 10 seconds on close (`menuDidClose`).
* **Screen State Observers**: Listens to `screensDidSleepNotification` and `screensDidWakeNotification` on `NSWorkspace`. Timers are completely invalidated when screens are off and resume only when screens wake back up.
* **Zero Periodic I/O**: The app caches configuration and uptime values in memory, only reading/writing `state.json` during setup, manual changes, break completions, or application exit.

### 4. Timer Scheduling under Tracking Mode
During menu tracking (i.e., when a menu bar item's dropdown is open), Cocoa run loops enter event tracking mode. Standard timers scheduled via `Timer.scheduledTimer` stop firing. To ensure the countdown updates in real time while open, all timers are manually added to `RunLoop.current` using the `.common` run loop mode:
```swift
let timer = Timer(timeInterval: interval, repeats: true) { ... }
RunLoop.current.add(timer, forMode: .common)
```

---

## 🚀 How to Test Changes

Since Screeny interacts directly with system directories (`/usr/local/bin` and `~/Library/LaunchAgents`), manual testing requires re-running the installation script.

1. **Build and Install:**
   ```bash
   ./install.sh
   ```

2. **Trigger the Overlay Manually:**
   Click **Take Break Now** from the system menu bar menu.

3. **Check Logs:**
   ```bash
   tail -f /tmp/walknotifier.out
   tail -f /tmp/walknotifier.err
   ```

Happy coding! Let this document guide you to make safe, architecturally-sound changes to Screeny.
