# Screeny — Walk Notification CLI

A native macOS background service that interrupts you with a fullscreen **"Walk"** screen every N minutes. Dismiss it only by clicking **Skip** 20 times.

Built with Swift + AppKit. Scheduled via macOS `launchd`.

## Install

```bash
chmod +x install.sh
./install.sh
```

Builds the Swift binary, installs it to `/usr/local/bin/screeny`, and starts the launchd service. You'll be prompted for your password once (for the `/usr/local/bin` copy only).

## Usage

```bash
screeny status           # view interval, last/next notification, service state
screeny set <minutes>    # change notification interval
screeny start            # start the service
screeny stop             # stop the service
```

## How It Works

* **High-Precision Scheduling**: Scheduled via macOS `launchd` using `StartInterval`. It runs as an `Interactive` process with `LegacyTimers` enabled, opting out of macOS's energy-saving timer coalescing to ensure the overlay triggers right on time.
* **Smart Sleep Reset**: The timer is automatically reset when the computer sleeps or is locked for **60 seconds or more** (counting as a valid break). Short interruptions under 60 seconds (like locking the screen to grab water) are ignored, preserving your accumulated active time.
* **Scheduling Tolerance**: Built with a 60-second timing buffer to account for minor macOS scheduling fluctuations and clock drift, preventing the service from exiting early if triggered a fraction of a second before the target uptime.

## File Locations

| File | Location |
|------|----------|
| Binary | `/usr/local/bin/screeny` |
| Launch agent | `~/Library/LaunchAgents/com.arjun.walknotifier.plist` |
| State (last fired, interval) | `~/.screeny/state.json` |
| Logs | `/tmp/walknotifier.out` & `/tmp/walknotifier.err` |
