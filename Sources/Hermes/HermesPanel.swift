import AppKit

/// NSView subclass that accepts first responder for keyboard events
class KeyableBackingView: NSView {
    override var acceptsFirstResponder: Bool { true }
}

class HermesPanel: NSPanel {
    init() {
        let width: CGFloat = 780
        let height: CGFloat = 480
        let rect = NSRect(x: 0, y: 0, width: width, height: height)

        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        // isOpaque=false + clear bg needed for rounded corners to not show square edges
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        becomesKeyOnlyIfNeeded = false

        // Opaque rounded content view
        let container = KeyableBackingView(frame: rect)
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = Theme.bg.cgColor
        container.layer?.isOpaque = true
        contentView = container
    }

    // Allow the panel to become key (so it receives keyboard events)
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
