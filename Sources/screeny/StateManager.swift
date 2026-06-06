import Foundation

// MARK: - StateManager
// Reads and writes ~/.screeny/state.json to track last fired time and interval.

struct AppState: Codable {
    var lastFired: Date?
    var lastFiredUptime: Double?
    var intervalSeconds: Int
}

enum StateManager {
    static let screenyDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".screeny")
    static let stateFile = screenyDir.appendingPathComponent("state.json")

    static func load() -> AppState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: stateFile),
              var state = try? decoder.decode(AppState.self, from: data)
        else {
            return AppState(lastFired: nil, lastFiredUptime: nil, intervalSeconds: 2400)
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

            if hasRebooted || sleepDuration >= 60.0 {
                state.lastFired = currentDate
                state.lastFiredUptime = currentUptime
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
