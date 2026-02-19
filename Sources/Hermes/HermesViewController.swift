import AppKit

/// Stub view controller — full implementation in he-3ql
class HermesViewController: NSViewController {
    var onClose: (() -> Void)?
    var onExecute: ((String) -> Void)?
    var onLaunchApp: ((String) -> Void)?
    var onFocusWindow: ((Int) -> Void)?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: Theme.panelWidth, height: Theme.panelHeight))
    }

    func prepareForShow() {}
}
