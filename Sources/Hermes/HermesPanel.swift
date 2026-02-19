import AppKit

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
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        becomesKeyOnlyIfNeeded = false

        // Rounded corners via content view
        let visual = NSVisualEffectView(frame: rect)
        visual.material = .hudWindow
        visual.state = .active
        visual.appearance = NSAppearance(named: .darkAqua)
        visual.wantsLayer = true
        visual.layer?.cornerRadius = 12
        visual.layer?.masksToBounds = true
        visual.layer?.backgroundColor = Theme.bg.cgColor
        contentView = visual
    }

    // Allow the panel to become key (so it receives keyboard events)
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
