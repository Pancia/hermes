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
    private var searchQuery = ""
    private var flatCommands: [FlatCommand] = []

    // MARK: - Views

    private let breadcrumbLabel = NSTextField(labelWithString: "")
    private let commandMenuView = CommandMenuView()
    private let searchField = NSTextField()
    private let footerLabel = NSTextField(labelWithString: "")

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
        searchQuery = ""
        searchField.isHidden = true
        breadcrumbLabel.stringValue = "Hermes"
        commandMenuView.clearSelection()
        commandMenuView.setItems(currentMenu)
        commandMenuView.isHidden = false
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

        // Search field (hidden by default)
        searchField.font = Theme.bodyFont
        searchField.textColor = Theme.text
        searchField.backgroundColor = Theme.bgItem
        searchField.isBezeled = false
        searchField.focusRingType = .none
        searchField.placeholderString = "Search commands..."
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

            // Search field (same position as breadcrumb, shown when in search mode)
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: padding),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            // Command menu grid
            commandMenuView.topAnchor.constraint(equalTo: breadcrumbLabel.bottomAnchor, constant: 12),
            commandMenuView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            commandMenuView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            commandMenuView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -8),

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
        searchQuery = ""
        searchField.stringValue = ""
        searchField.isHidden = false
        breadcrumbLabel.isHidden = true
        view.window?.makeFirstResponder(searchField)
        footerLabel.stringValue = "ESC cancel  |  ENTER execute"
        showSearchResults()
    }

    private func exitSearchMode() {
        mode = .command
        searchField.isHidden = true
        breadcrumbLabel.isHidden = false
        footerLabel.stringValue = "ESC close  |  DEL back  |  : search"
        commandMenuView.setItems(currentMenu)
        commandMenuView.clearSelection()
        // Return keyboard focus to the view
        view.window?.makeFirstResponder(view)
    }

    private func showSearchResults() {
        let query = searchQuery.lowercased()
        if query.isEmpty {
            commandMenuView.setItems([:])
            return
        }

        var results: [String: CommandEntry] = [:]
        var count = 0
        for cmd in flatCommands {
            guard count < Theme.maxSearchResults else { break }
            if cmd.label.lowercased().contains(query) || cmd.command.lowercased().contains(query) {
                let pathStr = cmd.path.isEmpty ? "" : cmd.path.joined(separator: " > ") + " > "
                results[cmd.key + String(count)] = .action(title: "\(pathStr)\(cmd.label)", command: cmd.command)
                count += 1
            }
        }
        commandMenuView.setItems(results)
    }

    // MARK: - Keyboard Handling

    override func keyDown(with event: NSEvent) {
        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else {
            super.keyDown(with: event)
            return
        }

        let keyCode = event.keyCode

        // Escape — always close or exit search
        if keyCode == 53 { // Escape
            if mode == .search {
                exitSearchMode()
            } else {
                onClose?()
            }
            return
        }

        // In search mode, let the text field handle most input
        if mode == .search {
            handleSearchKey(event)
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

    private func handleSearchKey(_ event: NSEvent) {
        let keyCode = event.keyCode

        // Enter — execute first/selected result
        if keyCode == 36 {
            commandMenuView.activateSelection()
            return
        }

        // Arrow keys for navigation within search results
        if keyCode == 125 { // Down
            commandMenuView.moveSelectionVertical(by: 1)
            return
        }
        if keyCode == 126 { // Up
            commandMenuView.moveSelectionVertical(by: -1)
            return
        }
    }

    // MARK: - App Mode

    private func enterAppMode() {
        mode = .app
        breadcrumbLabel.stringValue = "Applications"
        footerLabel.stringValue = "ESC close  |  DEL back"
        commandMenuView.setItems([:])

        AppScanner.loadApps { [weak self] apps in
            guard let self = self, self.mode == .app else { return }
            var items: [String: CommandEntry] = [:]
            var used: Set<Character> = []
            for app in apps.prefix(Theme.maxAppsVisible) {
                if let key = CommandLoader.assignKey(from: app.name, used: &used) {
                    items[String(key)] = .action(title: app.name, command: "")
                }
            }
            self.currentMenu = items
            self.commandMenuView.setItems(items)
            self.commandMenuView.onSelect = { [weak self] _, entry in
                if case .action(let title, _) = entry {
                    self?.onLaunchApp?(title)
                }
            }
        }
    }

    // MARK: - Window Mode

    private func enterWindowMode() {
        mode = .window
        breadcrumbLabel.stringValue = "Windows"
        footerLabel.stringValue = "ESC close  |  DEL back"
        commandMenuView.setItems([:])

        WindowManager.queryWindows { [weak self] windows in
            guard let self = self, self.mode == .window else { return }
            var items: [String: CommandEntry] = [:]
            var used: Set<Character> = []
            for win in windows {
                if let key = CommandLoader.assignKey(from: win.app + win.title, used: &used) {
                    items[String(key)] = .action(title: "[\(win.space)] \(win.app) — \(win.title)", command: "\(win.id)")
                }
            }
            self.currentMenu = items
            self.commandMenuView.setItems(items)
            self.commandMenuView.onSelect = { [weak self] _, entry in
                if case .action(_, let idStr) = entry, let id = Int(idStr) {
                    self?.onFocusWindow?(id)
                }
            }
        }
    }
}

// MARK: - NSTextFieldDelegate (Search)

extension HermesViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard mode == .search else { return }
        searchQuery = searchField.stringValue
        showSearchResults()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            exitSearchMode()
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commandMenuView.activateSelection()
            return true
        }
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            commandMenuView.moveSelectionVertical(by: 1)
            return true
        }
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            commandMenuView.moveSelectionVertical(by: -1)
            return true
        }
        return false
    }
}
