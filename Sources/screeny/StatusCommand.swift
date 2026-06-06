import Foundation

// MARK: - StatusCommand
// Reads the plist and state.json to print current status.

enum StatusCommand {
    // Returns the visual terminal width of a string (emoji = 2 columns)
    private static func visualWidth(_ s: String) -> Int {
        s.unicodeScalars.reduce(0) { count, scalar in
            count + (scalar.properties.isEmojiPresentation ? 2 : 1)
        }
    }

    // Pads a string to a fixed *visual* width for the status box
    private static func col(_ s: String, _ width: Int = 23) -> String {
        let extra = visualWidth(s) - s.count  // visual columns consumed beyond Swift char count
        let targetLen = max(s.count, width - extra)
        return s.padding(toLength: targetLen, withPad: " ", startingAt: 0)
    }

    static func run() {
        let state = StateManager.load()
        let intervalSeconds = plistInterval() ?? state.intervalSeconds
        let intervalMinutes = intervalSeconds / 60

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let serviceStatus = isServiceRunning() ? "running ✅" : "stopped ❌"

        print("╭─────────────────────────────────────╮")
        print("│           screeny status            │")
        print("├─────────────────────────────────────┤")
        print("│  Interval:   \(col("\(intervalMinutes) minutes"))│")

        let currentUptime = ProcessInfo.processInfo.systemUptime
        let lastUptime = state.lastFiredUptime ?? 0
        
        let effectiveLastUptime = currentUptime < lastUptime ? 0 : lastUptime
        let activeElapsed = currentUptime - effectiveLastUptime
        let remainingActive = Double(intervalSeconds) - activeElapsed

        if let last = state.lastFired {
            let lastStr = formatter.string(from: last)
            print("│  Last:       \(col(lastStr))│")

            let nextDate = Date().addingTimeInterval(max(0, remainingActive))
            let nextStr = formatter.string(from: nextDate)
            
            let inStr: String
            if remainingActive > 0 {
                let remMinutes = Int(remainingActive) / 60
                let remSeconds = Int(remainingActive) % 60
                inStr = "~\(remMinutes)m \(remSeconds)s (active)"
            } else {
                inStr = "overdue"
            }
            print("│  Next:       \(col(nextStr))│")
            print("│  In:         \(col(inStr))│")
        } else {
            print("│  Last:       never                  │")
            print("│  Next:       unknown                │")
            print("│  In:         unknown                │")
        }

        print("│  Service:    \(col(serviceStatus))│")
        print("╰─────────────────────────────────────╯")
    }

    // Read StartInterval from the installed plist
    static func plistInterval() -> Int? {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.arjun.walknotifier.plist")
        guard let dict = NSDictionary(contentsOf: plistPath),
              let interval = dict["StartInterval"] as? Int
        else { return nil }
        return interval
    }

    static func isServiceRunning() -> Bool {
        let result = shell("launchctl list | grep com.arjun.walknotifier")
        return !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
