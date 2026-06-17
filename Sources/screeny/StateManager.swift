import Foundation

// MARK: - StateManager
// Reads and writes ~/.screeny/state.json to track last fired time, interval, and pause state.

struct AppState: Codable {
    var lastFired: Date?
    var lastFiredUptime: Double?
    var intervalSeconds: Int
    var isPaused: Bool?
}

enum StateManager {
    static let screenyDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".screeny")
    static let stateFile = screenyDir.appendingPathComponent("state.json")

    private static func getSystemTimeVal(name: String) -> Date? {
        var size = MemoryLayout<timeval>.size
        var tv = timeval(tv_sec: 0, tv_usec: 0)
        let result = sysctlbyname(name, &tv, &size, nil, 0)
        if result == 0 {
            return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000.0)
        }
        return nil
    }

    static func load() -> AppState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: stateFile),
              var state = try? decoder.decode(AppState.self, from: data)
        else {
            return AppState(lastFired: nil, lastFiredUptime: nil, intervalSeconds: 2400, isPaused: false)
        }

        if state.isPaused == nil {
            state.isPaused = false
        }

        let currentDate = Date()
        let currentUptime = ProcessInfo.processInfo.systemUptime

        if let lastFired = state.lastFired {
            let isMigrating = state.lastFiredUptime == nil
            let lastFiredUptime = state.lastFiredUptime ?? {
                return max(0, currentUptime - currentDate.timeIntervalSince(lastFired))
            }()

            let hasRebooted = currentUptime < lastFiredUptime
            let wallClockElapsed = currentDate.timeIntervalSince(lastFired)
            let activeElapsed = currentUptime - lastFiredUptime
            let sleepDuration = wallClockElapsed - activeElapsed

            if hasRebooted {
                let bootDate = getSystemTimeVal(name: "kern.boottime") ?? currentDate
                state.lastFired = bootDate
                state.lastFiredUptime = 0.0
                save(state)
            } else if sleepDuration >= 60.0 {
                if let wakeDate = getSystemTimeVal(name: "kern.waketime"), wakeDate > lastFired {
                    let effectiveWakeDate = min(currentDate, wakeDate)
                    let elapsedSinceWake = currentDate.timeIntervalSince(effectiveWakeDate)
                    state.lastFired = effectiveWakeDate
                    state.lastFiredUptime = max(0.0, currentUptime - elapsedSinceWake)
                } else {
                    state.lastFired = currentDate
                    state.lastFiredUptime = currentUptime
                }
                save(state)
            } else if isMigrating {
                state.lastFiredUptime = lastFiredUptime
                save(state)
            }
        }

        return state
    }

    static func save(_ state: AppState) {
        try? FileManager.default.createDirectory(at: screenyDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(state) {
            try? data.write(to: stateFile)
        }
    }

    static func recordFired(intervalSeconds: Int) {
        var state = load()
        state.lastFired = Date()
        state.lastFiredUptime = ProcessInfo.processInfo.systemUptime
        state.intervalSeconds = intervalSeconds
        save(state)
    }
}
