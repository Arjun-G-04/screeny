import AppKit
import Foundation

// MARK: - CircularProgressView
// Draws a custom premium system-orange circular progress indicator.

final class CircularProgressView: NSView {
    var progress: CGFloat = 1.0 {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2.0 - 6.0

        // Track path
        let trackPath = NSBezierPath()
        trackPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        trackPath.lineWidth = 4.0
        NSColor(white: 1.0, alpha: 0.1).setStroke()
        trackPath.stroke()

        // Progress path (clockwise countdown starting from the top)
        let progressPath = NSBezierPath()
        let startAngle: CGFloat = 90.0
        let endAngle: CGFloat = 90.0 - (progress * 360.0)
        progressPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        progressPath.lineWidth = 4.0
        progressPath.lineCapStyle = .round
        NSColor.systemOrange.setStroke()
        progressPath.stroke()
    }
}

// MARK: - OverlayViewController

final class OverlayViewController: NSViewController {
    private var clicksRemaining = 20
    private var timeRemaining = 90
    private var timer: Timer?
    
    private var progressContainer: CircularProgressView!
    private var timeLabel: NSTextField!
    private var skipButton: NSButton!
    
    var completionHandler: (() -> Void)?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startTimer()
    }

    private func setupUI() {
        // "Walk" title
        let titleLabel = NSTextField(labelWithString: "WALK")
        titleLabel.font = NSFont.systemFont(ofSize: 100, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Subtitle text
        let subtitleLabel = NSTextField(labelWithString: "Look away, stand up, stretch.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        subtitleLabel.textColor = NSColor(white: 1.0, alpha: 0.6)
        subtitleLabel.alignment = .center
        subtitleLabel.isBezeled = false
        subtitleLabel.drawsBackground = false
        subtitleLabel.isEditable = false
        subtitleLabel.isSelectable = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Progress view
        progressContainer = CircularProgressView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressContainer)

        // Time label centered inside the circular progress view
        timeLabel = NSTextField(labelWithString: "01:30")
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 32, weight: .semibold)
        timeLabel.textColor = .white
        timeLabel.alignment = .center
        timeLabel.isBezeled = false
        timeLabel.drawsBackground = false
        timeLabel.isEditable = false
        timeLabel.isSelectable = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.addSubview(timeLabel)

        // Skip button
        skipButton = NSButton(title: skipTitle(), target: self, action: #selector(skipTapped))
        skipButton.bezelStyle = .rounded
        skipButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        skipButton.isBordered = false
        skipButton.wantsLayer = true
        skipButton.layer?.backgroundColor = NSColor.clear.cgColor
        skipButton.layer?.cornerRadius = 24
        skipButton.layer?.borderWidth = 1.5
        skipButton.layer?.borderColor = NSColor(white: 1.0, alpha: 0.25).cgColor
        skipButton.contentTintColor = NSColor(white: 1.0, alpha: 0.60)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skipButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),

            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            progressContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            progressContainer.widthAnchor.constraint(equalToConstant: 160),
            progressContainer.heightAnchor.constraint(equalToConstant: 160),

            timeLabel.centerXAnchor.constraint(equalTo: progressContainer.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: progressContainer.centerYAnchor),

            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            skipButton.topAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: 40),
            skipButton.widthAnchor.constraint(equalToConstant: 220),
            skipButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    private func startTimer() {
        updateTimeLabel()
        updateProgress()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        timeRemaining -= 1
        if timeRemaining <= 0 {
            closeOverlay()
        } else {
            updateTimeLabel()
            updateProgress()
        }
    }

    private func updateTimeLabel() {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        timeLabel.stringValue = String(format: "%02d:%02d", minutes, seconds)
    }

    private func updateProgress() {
        let total = 90.0
        let current = Double(timeRemaining)
        progressContainer.progress = CGFloat(current / total)
    }

    private func skipTitle() -> String {
        clicksRemaining == 1 ? "Skip (last click)" : "Skip (\(clicksRemaining) clicks left)"
    }

    @objc private func skipTapped() {
        clicksRemaining -= 1
        if clicksRemaining <= 0 {
            closeOverlay()
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
                    self.skipButton.layer?.borderColor = NSColor(white: 1.0, alpha: 0.25).cgColor
                    self.skipButton.contentTintColor = NSColor(white: 1.0, alpha: 0.60)
                }
            }
        }
    }

    private func closeOverlay() {
        timer?.invalidate()
        completionHandler?()
    }
}
