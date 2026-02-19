import AppKit
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: HermesPanel!
    var viewController: HermesViewController!
    var hotKeyRef: EventHotKeyRef?
    var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPanel()
        registerHotKey()
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Hermes")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    @objc private func statusItemClicked() {
        togglePanel()
    }

    // MARK: - Panel

    private func setupPanel() {
        viewController = HermesViewController()
        viewController.onClose = { [weak self] in
            self?.hidePanel()
        }
        viewController.onExecute = { [weak self] command in
            self?.hidePanel()
            ShellExecutor.execute(command)
        }
        viewController.onLaunchApp = { [weak self] appName in
            self?.hidePanel()
            ShellExecutor.launchApp(appName)
        }
        viewController.onFocusWindow = { [weak self] windowId in
            self?.hidePanel()
            WindowManager.focusWindow(id: windowId)
        }

        panel = HermesPanel()
        panel.contentViewController = viewController
    }

    func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = screenFrame.origin.x + (screenFrame.width - panel.frame.width) / 2
            let y = screenFrame.origin.y + (screenFrame.height - panel.frame.height) / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        viewController.prepareForShow()
        panel.makeKeyAndOrderFront(nil)

        // Click outside to dismiss
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self, self.panel.isVisible else { return }
            let loc = event.locationInWindow
            let screenPoint = NSEvent.mouseLocation
            if !self.panel.frame.contains(screenPoint) {
                self.hidePanel()
            }
        }
    }

    func hidePanel() {
        panel.orderOut(nil)
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    // MARK: - Global Hotkey (Carbon)

    private func registerHotKey() {
        // Cmd+Space
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x48524D53) // "HRMS"
        hotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                delegate.togglePanel()
            }
            return noErr
        }, 1, &eventType, selfPtr, nil)

        // kVK_Space = 0x31, cmdKey = 0x0100
        RegisterEventHotKey(UInt32(kVK_Space), UInt32(cmdKey), hotKeyID,
                           GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
