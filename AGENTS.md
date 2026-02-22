# Screeny Developer & AI Agent Guide (AGENTS.md)

Welcome to the **Screeny** codebase! This document is the ultimate reference guide for AI agents and human developers working on this project. It contains everything you need to know about the architecture, components, and how different parts of the system interact.

## 🎯 What is Screeny?

Screeny is a native macOS background CLI tool that periodically interrupts the user with a fullscreen **"Walk"** overlay. The goal is to enforce breaks by requiring the user to click a "Skip" button 20 times to dismiss the screen.

It is built using **Swift**, **AppKit**, and scheduled via macOS **launchd**.

---

## 🏗️ Architecture Overview

The system consists of two primary parts:
1. **The CLI Manager:** Handles user commands (`set`, `status`, `start`, `stop`) to configure and control the service.
2. **The Overlay UI (`--overlay`):** The actual break screen triggered by `launchd` in the background.

Unlike typical macOS Apps, Screeny does **not** have an `.app` bundle. It creates an AppKit window directly from a command-line binary by overriding standard NSApplication activation sequences.

---

## 📂 File Structure & Components

All source code is located in `Sources/screeny/`.

| Component | Description |
|-----------|-------------|
| **`main.swift`** | The entry point. Parses CLI arguments and routes them to the correct command handler (`status`, `set`, `start`, `stop`, `--overlay`). |
| **`OverlayWindow.swift`** | Contains `OverlayViewController` and `OverlayCommand`. It programmatically builds a borderless, full-screen AppKit window and handles the 20-click dismissal logic. **Crucial:** It calls `NSApp.activate` *before* `NSApp.run()` to display the UI from a CLI context without a bundle. |
| **`SetCommand.swift`** | Handles `screeny set <minutes>`. It modifies the `StartInterval` in the active `launchd` plist (`~/Library/LaunchAgents/com.arjun.walknotifier.plist`), updates `~/.screeny/state.json`, and reloads the service via `launchctl`. |
| **`StatusCommand.swift`** | Handles `screeny status`. It reads interval data from the plist and `state.json` to calculate when the next overlay will appear, and checks if the `launchd` service is currently running. |
| **`StateManager.swift`** | Manages persistent state stored in `~/.screeny/state.json`. Tracks the `lastFired` Date and the `intervalSeconds` so the `status` command can accurately project the next scheduled run. |
| **`Shell.swift`** | A simple wrapper around `Process` for executing shell commands (used for `launchctl` and `plutil`). |
| **`install.sh`** | The installation script. It compiles the Swift binary using `swift build -c release`, copies it to `/usr/local/bin`, places the `launchd` plist in `~/Library/LaunchAgents`, and loads the service. |
| **`com.arjun.walknotifier.plist`** | The `launchd` configuration template. It tells macOS to run `/usr/local/bin/screeny --overlay` every `StartInterval` seconds. |

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
Screeny relies on macOS `launchd` to handle scheduling. There is no long-running daemon written in Swift. Instead, `launchd` spawns a fresh `screeny --overlay` process every N seconds.
- **To change the interval:** You must edit the plist file (typically using `plutil`) and then `unload` and `re-load` the plist with `launchctl`. See `SetCommand.swift` for the implementation.
- **To start/stop:** You `load` or `unload` the plist with `launchctl`.

### 2. AppKit from the CLI
Because there is no Info.plist or `.app` bundle:
- Standard `applicationDidFinishLaunching` hooks can be unreliable.
- Windows must be created, configured, and ordered front *before* starting the event loop (`NSApp.run()`).
- You must call `NSApp.setActivationPolicy(.regular)` and `NSApp.activate(ignoringOtherApps: true)` to force the window into the foreground and steal focus from other apps.

### 3. The `state.json` Synchronization
The time of the next interval is inherently known only to `launchd`. To allow the `status` command to show "Time remaining", `OverlayCommand` writes its current execution time (`lastFired`) to `~/.screeny/state.json` immediately before showing the window.

### 4. Updating the Plist
If you change the interval logic, make sure to update **both** `state.json` and the active plist. `SetCommand.swift` uses `plutil -replace StartInterval -integer <seconds> <plist_path>` to ensure the formatting matches what Apple expects.

---

## 🚀 How to Test Changes

Since Screeny interacts directly with system directories (`/usr/local/bin` and `~/Library/LaunchAgents`), manual testing requires re-running the installation script.

1. **Build and Install:**
   ```bash
   ./install.sh
   ```
   *Note: `install.sh` uses `sudo` to copy the binary to `/usr/local/bin`. Be prepared to handle authentication prompts if running manually.*

2. **Trigger the Overlay Manually:**
   Instead of waiting for `launchd`, you can test UI changes immediately by running:
   ```bash
   .build/release/screeny --overlay
   ```
   *(Or just `screeny --overlay` if installed).* This directly invokes `OverlayWindow.swift`.

3. **Check Status Logic:**
   ```bash
   swift run screeny status
   ```

Happy coding! Let this document guide you to make safe, architecturally-sound changes to Screeny.
