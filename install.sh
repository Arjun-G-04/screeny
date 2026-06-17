#!/bin/bash
set -e

echo "🔨 Building screeny..."
swift build -c release

echo "📦 Installing binary to /usr/local/bin/screeny..."
sudo cp .build/release/screeny /usr/local/bin/screeny

echo "📋 Installing launch agent..."
mkdir -p ~/.screeny
cp ./com.arjun.walknotifier.plist ~/Library/LaunchAgents/

echo "🔄 Loading service..."
launchctl unload ~/Library/LaunchAgents/com.arjun.walknotifier.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.arjun.walknotifier.plist

echo ""
echo "✅ screeny installed successfully!"
echo "The Screeny menu bar app is now running!"
echo "Look for the walking figure icon (🚶) in your macOS menu bar."
echo "You can adjust the interval, pause, or trigger manual breaks directly from the menu bar UI."
