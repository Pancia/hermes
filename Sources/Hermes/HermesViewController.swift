import AppKit

/// Modes the view controller can be in
enum HermesMode {
    case command
    case search
    case app
    case window
}

/// Root NSViewController managing mode switching and keyboard dispatch
class HermesViewController: NSViewController {

    // MARK: - Callbacks

    var onClose: (() -> Void)?
    var onExecute: ((String) -> Void)?
    var onLaunchApp: ((String) -> Void)?
    var onFocusWindow: ((Int) -> Void)?

    // MARK: - State

    private var mode: HermesMode = .command
    private var rootCommands: [String: CommandEntry] = [:]
    private var currentMenu: [String: CommandEntry] = [:]
    private var menuStack: [(name: String, items: [String: CommandEntry])] = []
    private var flatCommands: [FlatCommand] = []

    // MARK: - Views

    private let breadcrumbLabel = NSTextField(labelWithString: "")
    private let commandMenuView = CommandMenuView()
    private let commandSearchView = CommandSearchView()
    private let appGridView = AppGridView()
    private let searchField = NSTextField()
    private let footerLabel = NSTextField(labelWithString: "")
    private var appSearchQuery = ""

    // Window mode views
    private let windowListView = WindowListView()
    private let windowSearchField = NSTextField()

    // MARK: - Lifecycle

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0,
                                              width: Theme.panelWidth,
                                              height: Theme.panelHeight))
        container.wantsLayer = true
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        loadCommands()
    }

    func prepareForShow() {
        mode = .command
        menuStack.removeAll()
        currentMenu = rootCommands
        appSearchQuery = ""
        searchField.isHidden = true
        breadcrumbLabel.isHidden = false
        breadcrumbLabel.stringValue = "Hermes"
        commandMenuView.isHidden = false
        commandMenuView.clearSelection()
        commandMenuView.setItems(currentMenu)
        commandSearchView.isHidden = true
        windowListView.isHidden = true
        windowSearchField.isHidden = true
        appGridView.isHidden = true
        footerLabel.stringValue = "ESC close  |  DEL back  |  : search"
    }

    // MARK: - Setup

    private func setupViews() {
        let padding: CGFloat = 16

        // Breadcrumb bar — top
        breadcrumbLabel.font = Theme.breadcrumbFont
        breadcrumbLabel.textColor = Theme.textDim
        breadcrumbLabel.stringValue = "Hermes"
        breadcrumbLabel.isBezeled = false
        breadcrumbLabel.drawsBackground = false
        breadcrumbLabel.isEditable = false
        breadcrumbLabel.isSelectable = false
        breadcrumbLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(breadcrumbLabel)

        // Search field (used for app mode filtering, hidden by default)
        searchField.font = Theme.bodyFont
        searchField.textColor = Theme.text
        searchField.backgroundColor = Theme.bgItem
        searchField.isBezeled = false
        searchField.focusRingType = .none
        searchField.placeholderString = "Search apps..."
        searchField.isHidden = true
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchField)

        // Command menu grid — center area
        commandMenuView.translatesAutoresizingMaskIntoConstraints = false
        commandMenuView.onSelect = { [weak self] key, entry in
            self?.handleMenuSelection(key: key, entry: entry)
        }
        view.addSubview(commandMenuView)

        // Search view (hidden by default)
        commandSearchView.isHidden = true
        commandSearchView.translatesAutoresizingMaskIntoConstraints = false
        commandSearchView.onExecute = { [weak self] cmd in
            self?.onExecute?(cmd.command)
        }
        commandSearchView.onCancel = { [weak self] in
            self?.exitSearchMode()
        }
        view.addSubview(commandSearchView)

        // App icon grid (hidden by default)
        appGridView.translatesAutoresizingMaskIntoConstraints = false
        appGridView.isHidden = true
        appGridView.onLaunch = { [weak self] app in
            self?.onLaunchApp?(app.name)
        }
        view.addSubview(appGridView)

        // Window search field (hidden by default)
        windowSearchField.font = Theme.bodyFont
        windowSearchField.textColor = Theme.text
        windowSearchField.backgroundColor = Theme.bgItem
        windowSearchField.isBezeled = false
        windowSearchField.focusRingType = .none
        windowSearchField.placeholderString = "Filter windows..."
        windowSearchField.isHidden = true
        windowSearchField.delegate = self
        windowSearchField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(windowSearchField)

        // Window list view (hidden by default)
        windowListView.isHidden = true
        windowListView.translatesAutoresizingMaskIntoConstraints = false
        windowListView.onSelect = { [weak self] window in
            self?.onFocusWindow?(window.id)
        }
        view.addSubview(windowListView)

        // Footer — bottom
        footerLabel.font = Theme.smallFont
        footerLabel.textColor = Theme.textDim
        footerLabel.stringValue = "ESC close  |  DEL back  |  : search"
        footerLabel.alignment = .center
        footerLabel.isBezeled = false
        footerLabel.drawsBackground = false
        footerLabel.isEditable = false
        footerLabel.isSelectable = false
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footerLabel)

        NSLayoutConstraint.activate([
            // Breadcrumb
            breadcrumbLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: padding),
            breadcrumbLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            breadcrumbLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),

            // Search field (same position as breadcrumb, shown in app mode)
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: padding),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            // Command menu grid
            commandMenuView.topAnchor.constraint(equalTo: breadcrumbLabel.bottomAnchor, constant: 12),
            commandMenuView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            commandMenuView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            commandMenuView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -8),

            // Search view (overlaps command menu area)
            commandSearchView.topAnchor.constraint(equalTo: view.topAnchor, constant: padding),
            commandSearchView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            commandSearchView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            commandSearchView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -8),

            // App icon grid (same position as command menu)
            appGridView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            appGridView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            appGridView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            appGridView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -8),

            // Window search field (below breadcrumb, shown in window mode)
            windowSearchField.topAnchor.constraint(equalTo: breadcrumbLabel.bottomAnchor, constant: 8),
            windowSearchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            windowSearchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            windowSearchField.heightAnchor.constraint(equalToConstant: 28),

            // Window list view (below window search field)
            windowListView.topAnchor.constraint(equalTo: windowSearchField.bottomAnchor, constant: 8),
            windowListView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            windowListView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            windowListView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -8),

            // Footer
            footerLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padding),
            footerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            footerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
        ])
    }

    private func loadCommands() {
        let raw = CommandLoader.load()
        rootCommands = CommandResolver.resolve(raw)
        currentMenu = rootCommands
        flatCommands = CommandLoader.flattenCommands(rootCommands)
        commandMenuView.setItems(currentMenu)
    }

    // MARK: - Breadcrumb

    private func updateBreadcrumb() {
        if menuStack.isEmpty {
            breadcrumbLabel.stringValue = "Hermes"
        } else {
            let path = menuStack.map { $0.name }
            breadcrumbLabel.stringValue = path.joined(separator: " > ")
        }
    }

    // MARK: - Menu Navigation

    private func handleMenuSelection(key: String, entry: CommandEntry) {
        switch entry {
        case .action(_, let command):
            onExecute?(command)
        case .submenu(let desc, let items):
            menuStack.append((name: desc, items: currentMenu))
            currentMenu = items
            commandMenuView.setItems(currentMenu)
            commandMenuView.clearSelection()
            updateBreadcrumb()
        }
    }

    private func goBack() {
        guard let prev = menuStack.popLast() else {
            onClose?()
            return
        }
        currentMenu = prev.items
        commandMenuView.setItems(currentMenu)
        commandMenuView.clearSelection()
        updateBreadcrumb()
    }

    // MARK: - Search Mode

    private func enterSearchMode() {
        mode = .search
        breadcrumbLabel.isHidden = true
        commandMenuView.isHidden = true
        commandSearchView.isHidden = false
        commandSearchView.setCommands(flatCommands)
        commandSearchView.activate()
        footerLabel.stringValue = "ESC cancel  |  \u{2191}\u{2193} navigate  |  ENTER execute"
    }

    private func exitSearchMode() {
        mode = .command
        commandSearchView.isHidden = true
        breadcrumbLabel.isHidden = false
        commandMenuView.isHidden = false
        footerLabel.stringValue = "ESC close  |  DEL back  |  : search"
        commandMenuView.setItems(currentMenu)
        commandMenuView.clearSelection()
        view.window?.makeFirstResponder(view)
    }

    // MARK: - Keyboard Handling

    override func keyDown(with event: NSEvent) {
        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else {
            super.keyDown(with: event)
            return
        }

        let keyCode = event.keyCode

        // Escape — context-dependent
        if keyCode == 53 { // Escape
            switch mode {
            case .search:
                exitSearchMode()
            case .app:
                exitAppMode()
            case .window:
                exitWindowMode()
            case .command:
                onClose?()
            }
            return
        }

        // In search mode, the CommandSearchView handles all input
        if mode == .search {
            return
        }

        // In app mode, handle grid navigation (search field handles text)
        if mode == .app {
            handleAppKey(event)
            return
        }

        // In window mode, keyboard is handled via the search field delegate
        if mode == .window {
            return
        }

        // Backspace — go back
        if keyCode == 51 { // Delete/Backspace
            goBack()
            return
        }

        // Enter — activate selection
        if keyCode == 36 { // Return
            commandMenuView.activateSelection()
            return
        }

        // Arrow keys — navigate selection
        if keyCode == 123 { // Left
            commandMenuView.moveSelection(by: -1)
            return
        }
        if keyCode == 124 { // Right
            commandMenuView.moveSelection(by: 1)
            return
        }
        if keyCode == 125 { // Down
            commandMenuView.moveSelectionVertical(by: 1)
            return
        }
        if keyCode == 126 { // Up
            commandMenuView.moveSelectionVertical(by: -1)
            return
        }

        // Colon — enter search mode
        if chars == ":" {
            enterSearchMode()
            return
        }

        // At root level: 'a' for app mode, 'w' for window mode
        if menuStack.isEmpty {
            if chars == "a" {
                enterAppMode()
                return
            }
            if chars == "w" {
                enterWindowMode()
                return
            }
        }

        // Single character direct selection
        if chars.count == 1 {
            let key = chars.lowercased()
            if currentMenu[key] != nil {
                commandMenuView.selectByKey(key)
                return
            }
        }

        super.keyDown(with: event)
    }

    private func handleAppKey(_ event: NSEvent) {
        let keyCode = event.keyCode

        // Enter — launch selected app
        if keyCode == 36 {
            appGridView.activateSelection()
            return
        }

        // Arrow keys — grid navigation
        if keyCode == 123 { // Left
            appGridView.moveSelection(by: -1)
            return
        }
        if keyCode == 124 { // Right
            appGridView.moveSelection(by: 1)
            return
        }
        if keyCode == 125 { // Down
            appGridView.moveSelectionVertical(by: 1)
            return
        }
        if keyCode == 126 { // Up
            appGridView.moveSelectionVertical(by: -1)
            return
        }
    }

    // MARK: - App Mode

    private func enterAppMode() {
        mode = .app
        appSearchQuery = ""
        searchField.stringValue = ""
        searchField.placeholderString = "Search apps..."
        searchField.isHidden = false
        breadcrumbLabel.isHidden = true
        commandMenuView.isHidden = true
        appGridView.isHidden = false
        footerLabel.stringValue = "ESC back  |  arrows navigate  |  ENTER launch"
        view.window?.makeFirstResponder(searchField)

        AppScanner.loadApps { [weak self] apps in
            guard let self = self, self.mode == .app else { return }
            self.appGridView.setApps(apps)
        }
    }

    private func exitAppMode() {
        mode = .command
        appSearchQuery = ""
        searchField.isHidden = true
        searchField.placeholderString = "Search apps..."
        breadcrumbLabel.isHidden = false
        commandMenuView.isHidden = false
        appGridView.isHidden = true
        footerLabel.stringValue = "ESC close  |  DEL back  |  : search"
        commandMenuView.setItems(currentMenu)
        commandMenuView.clearSelection()
        view.window?.makeFirstResponder(view)
    }

    // MARK: - Window Mode

    private func enterWindowMode() {
        mode = .window
        breadcrumbLabel.stringValue = "Windows"
        footerLabel.stringValue = "ESC back  |  \u{2191}\u{2193} navigate  |  ENTER focus"
        commandMenuView.isHidden = true
        windowSearchField.isHidden = false
        windowSearchField.stringValue = ""
        windowListView.isHidden = false
        view.window?.makeFirstResponder(windowSearchField)

        WindowManager.queryWindows { [weak self] windows in
            guard let self = self, self.mode == .window else { return }
            self.windowListView.setWindows(windows)
        }
    }

    private func exitWindowMode() {
        mode = .command
        windowListView.isHidden = true
        windowSearchField.isHidden = true
        commandMenuView.isHidden = false
        breadcrumbLabel.stringValue = "Hermes"
        footerLabel.stringValue = "ESC close  |  DEL back  |  : search"
        commandMenuView.setItems(currentMenu)
        commandMenuView.clearSelection()
        view.window?.makeFirstResponder(view)
    }
}

// MARK: - NSTextFieldDelegate (App Filter & Window Filter)

extension HermesViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if mode == .app && field === searchField {
            appSearchQuery = searchField.stringValue
            appGridView.filterApps(appSearchQuery)
        } else if mode == .window && field === windowSearchField {
            windowListView.filter(query: windowSearchField.stringValue)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if mode == .app {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                exitAppMode()
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                appGridView.activateSelection()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                appGridView.moveSelectionVertical(by: 1)
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                appGridView.moveSelectionVertical(by: -1)
                return true
            }
            if commandSelector == #selector(NSResponder.moveLeft(_:)) {
                appGridView.moveSelection(by: -1)
                return true
            }
            if commandSelector == #selector(NSResponder.moveRight(_:)) {
                appGridView.moveSelection(by: 1)
                return true
            }
        } else if mode == .window {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                exitWindowMode()
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                windowListView.activateSelection()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                windowListView.moveSelection(by: 1)
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                windowListView.moveSelection(by: -1)
                return true
            }
        }
        return false
    }
}
