import Foundation

// MARK: - SetCommand
// Updates StartInterval in both the live and source plist, then reloads the service.

enum SetCommand {
    static func run(minutes: Int) {
        guard minutes > 0 else {
            print("❌ Interval must be greater than 0 minutes.")
            exit(1)
        }
        let seconds = minutes * 60

        let agentPlist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.arjun.walknotifier.plist")

        guard FileManager.default.fileExists(atPath: agentPlist.path) else {
            print("❌ Service not installed. Run install.sh first.")
            exit(1)
        }

        // Update live plist
        shell("plutil -replace StartInterval -integer \(seconds) \"\(agentPlist.path)\"")

        // Update state file to sync interval
        var state = StateManager.load()
        state.intervalSeconds = seconds
        StateManager.save(state)

        // Reload the launchd service
        print("🔄 Reloading service...")
        shell("launchctl unload \"\(agentPlist.path)\"")
        shell("launchctl load \"\(agentPlist.path)\"")

        print("✅ Interval updated to \(minutes) minute\(minutes == 1 ? "" : "s").")
    }
}
