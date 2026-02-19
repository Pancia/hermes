import AppKit

/// Color constants matching the original CSS theme
enum Theme {
    static let bg = NSColor(hex: 0x1a1a2e)
    static let bgItem = NSColor(hex: 0x16213e)
    static let bgHover = NSColor(hex: 0x0f3460)
    static let accent = NSColor(hex: 0x00d4ff)
    static let text = NSColor(white: 0.93, alpha: 1) // #eee
    static let textDim = NSColor(white: 0.53, alpha: 1) // #888
    static let textSubmenu = NSColor(hex: 0xe8b84a)

    static let panelWidth: CGFloat = 780
    static let panelHeight: CGFloat = 480
    static let cornerRadius: CGFloat = 12
    static let itemCornerRadius: CGFloat = 8
    static let itemPadding: CGFloat = 10
    static let gridColumns = 3
    static let appGridColumns = 6
    static let appIconSize: CGFloat = 48
    static let maxAppsVisible = 18
    static let maxSearchResults = 30

    static let bodyFont = NSFont.systemFont(ofSize: 14)
    static let titleFont = NSFont.systemFont(ofSize: 20, weight: .semibold)
    static let keyFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
    static let smallFont = NSFont.systemFont(ofSize: 11)
    static let breadcrumbFont = NSFont.systemFont(ofSize: 12)
    static let appNameFont = NSFont.systemFont(ofSize: 11)
    static let windowSpaceFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
}

extension NSColor {
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
