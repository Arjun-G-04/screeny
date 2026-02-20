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

macOS **launchd** triggers `screeny --overlay` every N seconds (configured via `StartInterval` in the plist). The overlay is a borderless black window covering your screen fully — click **Skip** 20 times to dismiss it.

## File Locations

| File | Location |
|------|----------|
| Binary | `/usr/local/bin/screeny` |
| Launch agent | `~/Library/LaunchAgents/com.arjun.walknotifier.plist` |
| State (last fired, interval) | `~/.screeny/state.json` |
