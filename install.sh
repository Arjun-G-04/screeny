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
echo ""
echo "Try it:"
echo "  screeny status"
echo "  screeny set 40"
echo "  screeny stop"
echo "  screeny start"
