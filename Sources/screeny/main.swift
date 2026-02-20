import Foundation

// MARK: - main.swift
// CLI entry point — routes subcommands to the appropriate handler.

let args = CommandLine.arguments.dropFirst() // drop binary name

func printHelp() {
    print("""
    screeny — walk notification manager

    USAGE:
      screeny status           Show current interval, last & next notification
      screeny set <minutes>    Change notification interval
      screeny start            Start (load) the launchd service
      screeny stop             Stop (unload) the launchd service
      screeny --overlay        (internal) Show the Walk overlay screen

    EXAMPLES:
      screeny status
      screeny set 30
    """)
}

let plistAgent = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/LaunchAgents/com.arjun.walknotifier.plist")

switch args.first {
case "status":
    StatusCommand.run()

case "set":
    guard let minutesStr = args.dropFirst().first, let minutes = Int(minutesStr) else {
        print("❌ Usage: screeny set <minutes>")
        exit(1)
    }
    SetCommand.run(minutes: minutes)

case "start":
    guard FileManager.default.fileExists(atPath: plistAgent.path) else {
        print("❌ Service not installed. Run install.sh first.")
        exit(1)
    }
    shell("launchctl load \"\(plistAgent.path)\"")
    print("✅ screeny started.")

case "stop":
    shell("launchctl unload \"\(plistAgent.path)\"")
    print("🛑 screeny stopped.")

case "--overlay":
    OverlayCommand.run()

case "help", "--help", "-h", nil:
    printHelp()

default:
    print("❌ Unknown command: \(args.first!)")
    printHelp()
    exit(1)
}
