import AppKit

/// 3-column grid layout showing command menu items
class CommandMenuView: NSView {
    private var itemViews: [MenuItemView] = []
    private var sortedKeys: [String] = []
    private var items: [String: CommandEntry] = [:]
    private var selectedIndex: Int = -1

    var onSelect: ((String, CommandEntry) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setItems(_ newItems: [String: CommandEntry]) {
        items = newItems
        sortedKeys = newItems.keys.sorted()
        selectedIndex = -1
        rebuildGrid()
    }

    // MARK: - Selection

    var selectedKey: String? {
        guard selectedIndex >= 0, selectedIndex < sortedKeys.count else { return nil }
        return sortedKeys[selectedIndex]
    }

    func selectByKey(_ key: String) {
        guard let idx = sortedKeys.firstIndex(of: key) else { return }
        setSelection(idx)
        if let entry = items[key] {
            onSelect?(key, entry)
        }
    }

    func moveSelection(by delta: Int) {
        guard !sortedKeys.isEmpty else { return }
        if selectedIndex < 0 {
            selectedIndex = 0
        } else {
            selectedIndex = (selectedIndex + delta + sortedKeys.count) % sortedKeys.count
        }
        updateHighlights()
    }

    /// Move selection vertically: +1 = down, -1 = up
    func moveSelectionVertical(by delta: Int) {
        guard !sortedKeys.isEmpty else { return }
        let columns = Theme.gridColumns
        let rows = (sortedKeys.count + columns - 1) / columns

        if selectedIndex < 0 {
            selectedIndex = 0
        } else {
            let col = selectedIndex % columns
            let row = selectedIndex / columns
            var newRow = row + delta

            // Wrap vertically
            if newRow < 0 { newRow = rows - 1 }
            if newRow >= rows { newRow = 0 }

            let newIndex = newRow * columns + col
            if newIndex < sortedKeys.count {
                selectedIndex = newIndex
            } else {
                // If wrapping lands past the end, go to last item in that column
                selectedIndex = (rows - 1) * columns + col
                if selectedIndex >= sortedKeys.count {
                    selectedIndex = sortedKeys.count - 1
                }
            }
        }
        updateHighlights()
    }

    func activateSelection() {
        guard let key = selectedKey, let entry = items[key] else { return }
        onSelect?(key, entry)
    }

    func clearSelection() {
        selectedIndex = -1
        updateHighlights()
    }

    private func setSelection(_ index: Int) {
        selectedIndex = index
        updateHighlights()
    }

    private func updateHighlights() {
        for (i, view) in itemViews.enumerated() {
            view.isHighlighted = (i == selectedIndex)
        }
    }

    // MARK: - Grid Layout

    private func rebuildGrid() {
        // Remove old views
        for view in itemViews {
            view.removeFromSuperview()
        }
        itemViews.removeAll()

        let columns = Theme.gridColumns
        let spacing: CGFloat = 6
        let hPadding: CGFloat = 12
        let vPadding: CGFloat = 8
        let availableWidth = bounds.width - hPadding * 2 - spacing * CGFloat(columns - 1)
        let colWidth = availableWidth / CGFloat(columns)
        let rowHeight: CGFloat = 38

        for (i, key) in sortedKeys.enumerated() {
            guard let entry = items[key] else { continue }

            let col = i % columns
            let row = i / columns

            let x = hPadding + CGFloat(col) * (colWidth + spacing)
            let y = bounds.height - vPadding - CGFloat(row + 1) * (rowHeight + spacing)
            let frame = NSRect(x: x, y: y, width: colWidth, height: rowHeight)

            let itemView = MenuItemView(frame: frame)
            itemView.configure(key: key, entry: entry)
            itemView.onClick = { [weak self] in
                self?.onSelect?(key, entry)
            }

            addSubview(itemView)
            itemViews.append(itemView)
        }
    }

    override func layout() {
        super.layout()
        rebuildGrid()
        updateHighlights()
    }
}
