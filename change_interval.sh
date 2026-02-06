#!/bin/bash

# Check if an argument is provided
if [ -z "$1" ]; then
    echo "Usage: ./change_interval.sh <minutes>"
    exit 1
fi

MINUTES=$1
MINUTES=$1
# Use awk for floating point multiplication, then printf "%.0f" to round to nearest integer
SECONDS=$(echo "$MINUTES 60" | awk '{printf "%.0f", $1 * $2}')

PLIST_DEST="$HOME/Library/LaunchAgents/com.arjun.walknotifier.plist"

echo "Setting interval to $MINUTES minutes ($SECONDS seconds)..."

# Check if plist exists
if [ ! -f "$PLIST_DEST" ]; then
    echo "Error: Service config not found at $PLIST_DEST"
    exit 1
fi

# Update the active agent plist
plutil -replace StartInterval -integer $SECONDS "$PLIST_DEST"

# Also update local source file if present
PLIST_SOURCE="./com.arjun.walknotifier.plist"
if [ -f "$PLIST_SOURCE" ]; then
    plutil -replace StartInterval -integer $SECONDS "$PLIST_SOURCE"
    echo "Updated local source file: $PLIST_SOURCE"
fi

# Reload the service
echo "Reloading service..."
launchctl unload "$PLIST_DEST"
launchctl load "$PLIST_DEST"

echo "✅ Success! Walk notification interval updated to $MINUTES minutes."
