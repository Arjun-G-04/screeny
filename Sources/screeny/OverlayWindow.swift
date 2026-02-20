import AppKit
import Foundation

// MARK: - OverlayViewController

final class OverlayViewController: NSViewController {
    private var clicksRemaining = 20
    private var skipButton: NSButton!

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        // "Walk" title
        let titleLabel = NSTextField(labelWithString: "WALK.")
        titleLabel.font = NSFont.systemFont(ofSize: 120, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Skip button
        skipButton = NSButton(title: skipTitle(), target: self, action: #selector(skipTapped))
        skipButton.bezelStyle = .rounded
        skipButton.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        skipButton.isBordered = false
        skipButton.wantsLayer = true
        skipButton.layer?.backgroundColor = NSColor.clear.cgColor
        skipButton.layer?.cornerRadius = 4
        skipButton.layer?.borderWidth = 1
        skipButton.layer?.borderColor = NSColor(white: 1.0, alpha: 0.30).cgColor
        skipButton.contentTintColor = NSColor(white: 1.0, alpha: 0.50)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skipButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),

            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            skipButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            skipButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            skipButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func skipTitle() -> String {
        clicksRemaining == 1 ? "Skip (last click)" : "Skip (\(clicksRemaining) clicks left)"
    }

    @objc private func skipTapped() {
        clicksRemaining -= 1
        if clicksRemaining <= 0 {
            view.window?.close()
            NSApp.terminate(nil)
        } else {
            skipButton.title = skipTitle()
            // Flash: brighten border briefly
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.05
                self.skipButton.layer?.borderColor = NSColor(white: 1.0, alpha: 0.8).cgColor
                self.skipButton.contentTintColor = NSColor(white: 1.0, alpha: 0.9)
            } completionHandler: {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.25
                    self.skipButton.layer?.borderColor = NSColor(white: 1.0, alpha: 0.30).cgColor
                    self.skipButton.contentTintColor = NSColor(white: 1.0, alpha: 0.50)
                }
            }
        }
    }
}

// MARK: - OverlayCommand
// Key insight: for a CLI (non-bundle) binary, create the window and call
// NSApp.activate BEFORE NSApp.run(). Doing it inside applicationDidFinishLaunching
// is unreliable without a proper app bundle.

enum OverlayCommand {
    static func run() {
        let state = StateManager.load()

        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        // Build window before running the event loop
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
        window.contentViewController = vc
        // Re-enforce the frame — contentViewController assignment can resize the window
        window.setFrame(frame, display: false)

        window.contentView?.wantsLayer = true

        // Record as late as possible — right when the window appears,
        // so Last/Next times reflect actual display time, not startup time
        StateManager.recordFired(intervalSeconds: state.intervalSeconds)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        app.run()
    }
}
