#!/bin/bash
set -e

echo "🔄 Unloading launch agent service..."
launchctl unload ~/Library/LaunchAgents/com.arjun.walknotifier.plist 2>/dev/null || true

echo "🛑 Stopping any running instances of screeny..."
killall screeny 2>/dev/null || true

echo "🗑️ Removing launch agent plist..."
rm -f ~/Library/LaunchAgents/com.arjun.walknotifier.plist

echo "🗑️ Removing binary from /usr/local/bin..."
sudo rm -f /usr/local/bin/screeny

echo "🗑️ Cleaning up state directory..."
rm -rf ~/.screeny

echo ""
echo "✅ screeny has been uninstalled successfully!"
