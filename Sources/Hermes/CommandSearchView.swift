import AppKit

/// Vertical search results list for command search mode.
/// Shows an NSTextField at top and a scrollable list of matched FlatCommands below.
class CommandSearchView: NSView {

    // MARK: - Callbacks

    var onExecute: ((FlatCommand) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - State

    private var allCommands: [FlatCommand] = []
    private var filteredResults: [FlatCommand] = []
    private var selectedIndex: Int = -1

    // MARK: - Views

    private let searchField = NSTextField()
    private let scrollView = NSScrollView()
    private let resultContainer = NSView()
    private var resultViews: [SearchResultRowView] = []

    // MARK: - Constants

    private let rowHeight: CGFloat = 32
    private let resultPadding: CGFloat = 4

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    func setCommands(_ commands: [FlatCommand]) {
        allCommands = commands
    }

    func activate() {
        searchField.stringValue = ""
        selectedIndex = -1
        filteredResults = []
        rebuildResults()
        window?.makeFirstResponder(searchField)
    }

    // MARK: - Setup

    private func setupViews() {
        wantsLayer = true

        // Search field
        searchField.font = Theme.bodyFont
        searchField.textColor = Theme.text
        searchField.backgroundColor = Theme.bgItem
        searchField.isBezeled = false
        searchField.focusRingType = .none
        searchField.placeholderString = "Search commands..."
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchField)

        // Scroll view for results
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        resultContainer.wantsLayer = true
        resultContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = resultContainer

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: topAnchor),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Filtering

    private func updateFilter() {
        let query = searchField.stringValue.lowercased()
        if query.isEmpty {
            filteredResults = []
        } else {
            filteredResults = allCommands.filter { cmd in
                cmd.label.lowercased().contains(query)
                    || cmd.path.contains(where: { $0.lowercased().contains(query) })
            }
            if filteredResults.count > Theme.maxSearchResults {
                filteredResults = Array(filteredResults.prefix(Theme.maxSearchResults))
            }
        }
        selectedIndex = filteredResults.isEmpty ? -1 : 0
        rebuildResults()
    }

    // MARK: - Results Layout

    private func rebuildResults() {
        for v in resultViews { v.removeFromSuperview() }
        resultViews.removeAll()

        let width = scrollView.contentSize.width
        let totalHeight = CGFloat(filteredResults.count) * (rowHeight + resultPadding)

        resultContainer.frame = NSRect(x: 0, y: 0, width: width, height: max(totalHeight, scrollView.contentSize.height))

        for (i, cmd) in filteredResults.enumerated() {
            let y = resultContainer.frame.height - CGFloat(i + 1) * (rowHeight + resultPadding)
            let rowFrame = NSRect(x: 0, y: y, width: width, height: rowHeight)
            let row = SearchResultRowView(frame: rowFrame)
            row.configure(command: cmd)
            row.isHighlighted = (i == selectedIndex)
            row.onClick = { [weak self] in
                self?.selectedIndex = i
                self?.updateHighlights()
                self?.executeSelection()
            }
            resultContainer.addSubview(row)
            resultViews.append(row)
        }
    }

    private func updateHighlights() {
        for (i, row) in resultViews.enumerated() {
            row.isHighlighted = (i == selectedIndex)
        }
        scrollToSelection()
    }

    private func scrollToSelection() {
        guard selectedIndex >= 0, selectedIndex < resultViews.count else { return }
        let row = resultViews[selectedIndex]
        resultContainer.scrollToVisible(row.frame)
    }

    // MARK: - Selection

    func moveSelection(by delta: Int) {
        guard !filteredResults.isEmpty else { return }
        if selectedIndex < 0 {
            selectedIndex = 0
        } else {
            selectedIndex = (selectedIndex + delta + filteredResults.count) % filteredResults.count
        }
        updateHighlights()
    }

    func executeSelection() {
        guard selectedIndex >= 0, selectedIndex < filteredResults.count else { return }
        onExecute?(filteredResults[selectedIndex])
    }

    override func layout() {
        super.layout()
        rebuildResults()
    }
}

// MARK: - NSTextFieldDelegate

extension CommandSearchView: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        updateFilter()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onCancel?()
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            executeSelection()
            return true
        }
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            moveSelection(by: 1)
            return true
        }
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            moveSelection(by: -1)
            return true
        }
        return false
    }
}

// MARK: - Search Result Row

/// Single row in the search results list: label + dim breadcrumb path
class SearchResultRowView: NSView {
    private let labelField = NSTextField(labelWithString: "")
    private let pathField = NSTextField(labelWithString: "")

    var isHighlighted = false {
        didSet { needsDisplay = true }
    }

    var onClick: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 4

        labelField.font = Theme.bodyFont
        labelField.textColor = Theme.text
        labelField.lineBreakMode = .byTruncatingTail
        labelField.isBezeled = false
        labelField.drawsBackground = false
        labelField.isEditable = false
        labelField.isSelectable = false
        labelField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelField)

        pathField.font = Theme.smallFont
        pathField.textColor = Theme.textDim
        pathField.lineBreakMode = .byTruncatingTail
        pathField.isBezeled = false
        pathField.drawsBackground = false
        pathField.isEditable = false
        pathField.isSelectable = false
        pathField.translatesAutoresizingMaskIntoConstraints = false
        pathField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(pathField)

        labelField.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        NSLayoutConstraint.activate([
            labelField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            labelField.centerYAnchor.constraint(equalTo: centerYAnchor),

            pathField.leadingAnchor.constraint(equalTo: labelField.trailingAnchor, constant: 8),
            pathField.centerYAnchor.constraint(equalTo: centerYAnchor),
            pathField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
        ])
    }

    func configure(command: FlatCommand) {
        labelField.stringValue = command.label
        if command.path.isEmpty {
            pathField.stringValue = ""
        } else {
            pathField.stringValue = "+" + command.path.joined(separator: " > ")
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            layer?.backgroundColor = Theme.bgHover.cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
        super.draw(dirtyRect)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
