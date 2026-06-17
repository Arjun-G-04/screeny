import AppKit
import Foundation
import Darwin

// MARK: - Single Instance Verification
// Prevent multiple instances of screeny from running concurrently.
let runningApps = NSWorkspace.shared.runningApplications
let otherInstances = runningApps.filter { app in
    app.executableURL?.lastPathComponent == "screeny" &&
    app.processIdentifier != ProcessInfo.processInfo.processIdentifier
}
if !otherInstances.isEmpty {
    print("screeny is already running.")
    exit(0)
}

// MARK: - MenuBarApp Delegate
final class MenuBarApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    
    private var backgroundTimer: Timer?
    private var activeMenuTimer: Timer?
    private var isScreenSleeping = false
    
    private var statusMenuItem: NSMenuItem!
    private var pauseMenuItem: NSMenuItem!
    
    private var state: AppState = AppState(lastFired: nil, lastFiredUptime: nil, intervalSeconds: 2400, isPaused: false)
    private var isPaused = false
    private var isOverlayShowing = false
    private var overlayWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load initial state
        state = StateManager.load()
        isPaused = state.isPaused ?? false
        
        if state.lastFired == nil {
            state.lastFired = Date()
            state.lastFiredUptime = ProcessInfo.processInfo.systemUptime
            StateManager.save(state)
        }

        // Setup status item (menu bar button)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "Screeny")
            button.image?.isTemplate = true
        }

        // Setup menu
        setupMenu()

        // Setup power and screen observers for battery optimization
        let wsCenter = NSWorkspace.shared.notificationCenter
        wsCenter.addObserver(self, selector: #selector(screensDidSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        wsCenter.addObserver(self, selector: #selector(screensDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        wsCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)

        // Start background checking timer (10 seconds)
        startTimer(interval: 10.0)

        // Perform initial tick check
        tick()
    }

    private func setupMenu() {
        menu = NSMenu()
        menu.delegate = self

        // Header Title
        let titleItem = NSMenuItem(title: "Screeny", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        // Live Countdown Status
        statusMenuItem = NSMenuItem(title: "Next break: Calculating...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Take Break Now Action
        let breakNowItem = NSMenuItem(title: "Take Break Now", action: #selector(takeBreakNow), keyEquivalent: "b")
        breakNowItem.target = self
        menu.addItem(breakNowItem)

        // Change Interval Submenu
        let intervalMenu = NSMenu()
        let presets = [20, 30, 40, 60]
        for mins in presets {
            let item = NSMenuItem(title: "\(mins) Minutes", action: #selector(changePresetInterval(_:)), keyEquivalent: "")
            item.tag = mins
            item.target = self
            intervalMenu.addItem(item)
        }
        intervalMenu.addItem(NSMenuItem.separator())
        let customItem = NSMenuItem(title: "Custom...", action: #selector(changeCustomInterval), keyEquivalent: "")
        customItem.target = self
        intervalMenu.addItem(customItem)

        let intervalSubmenuItem = NSMenuItem(title: "Change Interval", action: nil, keyEquivalent: "")
        intervalSubmenuItem.submenu = intervalMenu
        menu.addItem(intervalSubmenuItem)

        menu.addItem(NSMenuItem.separator())

        // Pause/Resume Option
        pauseMenuItem = NSMenuItem(title: isPaused ? "Resume Break Timer" : "Pause Break Timer", action: #selector(togglePause), keyEquivalent: "p")
        pauseMenuItem.target = self
        menu.addItem(pauseMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Quit Option
        let quitItem = NSMenuItem(title: "Quit Screeny", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        updateIntervalMenuState()
    }

    private func updateIntervalMenuState() {
        guard let intervalSubmenu = menu.item(withTitle: "Change Interval")?.submenu else { return }
        let currentMins = state.intervalSeconds / 60
        var matchedPreset = false
        for item in intervalSubmenu.items {
            if item.tag > 0 {
                if item.tag == currentMins {
                    item.state = .on
                    matchedPreset = true
                } else {
                    item.state = .off
                }
            }
        }
        if let customItem = intervalSubmenu.items.last {
            customItem.state = matchedPreset ? .off : .on
        }
    }

    @objc private func changePresetInterval(_ sender: NSMenuItem) {
        setInterval(sender.tag)
    }

    @objc private func changeCustomInterval() {
        let alert = NSAlert()
        alert.messageText = "Set Custom Interval"
        alert.informativeText = "Enter the break interval in minutes:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "e.g., 45"
        alert.accessoryView = input

        alert.layout()
        alert.window.initialFirstResponder = input

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let mins = Int(text), mins > 0 {
                setInterval(mins)
            }
        }
    }

    private func setInterval(_ mins: Int) {
        state.intervalSeconds = mins * 60
        StateManager.save(state)
        updateIntervalMenuState()
        updateStatusText()
    }

    @objc private func togglePause() {
        isPaused.toggle()
        state.isPaused = isPaused
        StateManager.save(state)

        pauseMenuItem.title = isPaused ? "Resume Break Timer" : "Pause Break Timer"
        updateStatusText()
    }

    @objc private func takeBreakNow() {
        triggerOverlay()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Timer Orchestration & Battery Optimization
    private func startTimer(interval: TimeInterval) {
        stopTimer()
        if isScreenSleeping { return }

        let targetTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(targetTimer, forMode: .common)

        if interval == 1.0 {
            activeMenuTimer = targetTimer
        } else {
            backgroundTimer = targetTimer
        }
    }

    private func stopTimer() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        activeMenuTimer?.invalidate()
        activeMenuTimer = nil
    }

    // NSMenuDelegate: Switch to 1-second timer when menu opens for real-time countdown.
    func menuWillOpen(_ menu: NSMenu) {
        tick() // Update status text instantly before rendering the menu
        startTimer(interval: 1.0)
    }

    // NSMenuDelegate: Drop back to 10-second timer when menu closes to conserve battery.
    func menuDidClose(_ menu: NSMenu) {
        startTimer(interval: 10.0)
    }

    @objc private func screensDidSleep() {
        isScreenSleeping = true
        stopTimer()
    }

    @objc private func screensDidWake() {
        isScreenSleeping = false
        tick()
        startTimer(interval: 10.0)
    }

    @objc private func systemDidWake() {
        state = StateManager.load()
        tick()
    }

    private func tick() {
        if isPaused || isOverlayShowing { return }

        let currentDate = Date()
        let currentUptime = ProcessInfo.processInfo.systemUptime
        let lastUptime = state.lastFiredUptime ?? 0

        // Detect reboot
        if currentUptime < lastUptime {
            state.lastFired = currentDate
            state.lastFiredUptime = currentUptime
            StateManager.save(state)
            updateStatusText()
            return
        }

        // Detect sleep
        let wallClockElapsed = currentDate.timeIntervalSince(state.lastFired ?? currentDate)
        let activeElapsed = currentUptime - lastUptime
        let sleepDuration = wallClockElapsed - activeElapsed

        if sleepDuration >= 60.0 {
            let wakeDate = getSystemWakeTime() ?? currentDate
            let effectiveWakeDate = min(currentDate, wakeDate)
            let elapsedSinceWake = currentDate.timeIntervalSince(effectiveWakeDate)
            state.lastFired = effectiveWakeDate
            state.lastFiredUptime = max(0.0, currentUptime - elapsedSinceWake)
            StateManager.save(state)
            updateStatusText()
            return
        }

        let remainingActive = Double(state.intervalSeconds) - activeElapsed
        if remainingActive <= 0 {
            triggerOverlay()
        } else {
            updateStatusText()
        }
    }

    private func updateStatusText() {
        if isPaused {
            statusMenuItem.title = "Next break: Paused"
            return
        }
        if isOverlayShowing {
            statusMenuItem.title = "Next break: Active Now"
            return
        }

        let currentUptime = ProcessInfo.processInfo.systemUptime
        let lastUptime = state.lastFiredUptime ?? 0
        let activeElapsed = currentUptime - lastUptime
        let remainingActive = max(0.0, Double(state.intervalSeconds) - activeElapsed)

        let remMinutes = Int(remainingActive) / 60
        let remSeconds = Int(remainingActive) % 60
        statusMenuItem.title = String(format: "Next break: %02dm %02ds", remMinutes, remSeconds)
    }

    private func getSystemWakeTime() -> Date? {
        var size = MemoryLayout<timeval>.size
        var tv = timeval(tv_sec: 0, tv_usec: 0)
        let result = sysctlbyname("kern.waketime", &tv, &size, nil, 0)
        if result == 0 {
            return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000.0)
        }
        return nil
    }

    private func triggerOverlay() {
        guard !isOverlayShowing else { return }
        isOverlayShowing = true
        updateStatusText()

        // Disable standard actions while overlay is active
        menu.item(withTitle: "Take Break Now")?.isEnabled = false
        menu.item(withTitle: "Change Interval")?.isEnabled = false
        menu.item(withTitle: "Pause Break Timer")?.isEnabled = false

        // Transition to regular app level to steal focus and display window
        NSApp.setActivationPolicy(.regular)

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = screen.frame

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.backgroundColor = .black
        window.isOpaque = true
        window.isReleasedWhenClosed = false

        let vc = OverlayViewController()
        vc.completionHandler = { [weak self] in
            self?.overlayFinished()
        }
        window.contentViewController = vc
        window.setFrame(frame, display: false)
        window.contentView?.wantsLayer = true

        self.overlayWindow = window

        StateManager.recordFired(intervalSeconds: state.intervalSeconds)
        state = StateManager.load()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func overlayFinished() {
        overlayWindow?.close()
        overlayWindow = nil
        isOverlayShowing = false

        // Re-enable actions
        menu.item(withTitle: "Take Break Now")?.isEnabled = true
        menu.item(withTitle: "Change Interval")?.isEnabled = true
        menu.item(withTitle: "Pause Break Timer")?.isEnabled = true

        // Transition back to background accessory level
        NSApp.setActivationPolicy(.accessory)

        state = StateManager.load()
        updateStatusText()
    }
}

// MARK: - Main Application Entry Point
let app = NSApplication.shared
let delegate = MenuBarApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
