import Foundation

// MARK: - StateManager
// Reads and writes ~/.screeny/state.json to track last fired time and interval.

struct AppState: Codable {
    var lastFired: Date?
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
              let state = try? decoder.decode(AppState.self, from: data)
        else {
            return AppState(lastFired: nil, intervalSeconds: 2400)
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
        state.intervalSeconds = intervalSeconds
        save(state)
    }
}
