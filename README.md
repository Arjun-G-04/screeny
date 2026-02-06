# Screeny Walk Notification System

A simple, lightweight background service for macOS that notifies you to take a walk every 50 minutes (or any interval you choose).

## 🚀 How It Works

This system uses macOS native **launchd** to schedule a shell script execution.

- **Notifier Script**: `~/.screeny/walk_notifier.sh` - Sends the actual notification.
- **Service Config**: `~/Library/LaunchAgents/com.arjun.walknotifier.plist` - Tells macOS when to run the script.

## � First Time Setup

If you are setting this up from scratch (e.g., on a new machine), follow these steps:

1.  **Create the script directory**:
    ```bash
    mkdir -p ~/.screeny
    ```
2.  **Move the notification script**:
    ```bash
    cp ./walk_notifier.sh ~/.screeny/
    chmod +x ~/.screeny/walk_notifier.sh
    ```
3.  **Install the Launch Agent**:
    ```bash
    cp ./com.arjun.walknotifier.plist ~/Library/LaunchAgents/
    ```
4.  **Start the Service**:
    ```bash
    launchctl load ~/Library/LaunchAgents/com.arjun.walknotifier.plist
    ```

## �🛠 Usage

### Change the Notification Interval

Use the provided helper script to change how often you get notified.

```bash
./change_interval.sh <minutes>
```

**Example:** To set it to every 30 minutes:
```bash
./change_interval.sh 30
```

### Stop the Service

To disable notifications completely:

```bash
launchctl unload ~/Library/LaunchAgents/com.arjun.walknotifier.plist
```

### Start the Service

To enable notifications again:

```bash
launchctl load ~/Library/LaunchAgents/com.arjun.walknotifier.plist
```

## 📂 File Locations

| File | Location | Description |
|------|----------|-------------|
| **Script** | `~/.screeny/walk_notifier.sh` | The code that runs when the timer hits. |
| **Config** | `~/Library/LaunchAgents/com.arjun.walknotifier.plist` | The active schedule configuration. |
| **Source Config** | `./com.arjun.walknotifier.plist` | A local copy of the config. The helper script updates this too. |
| **Helper** | `./change_interval.sh` | Script to change the timer interval. |
