import AppKit

/// 6-column icon grid for the app launcher mode
class AppGridView: NSView {
    private var itemViews: [AppItemView] = []
    private var allApps: [AppInfo] = []
    private var filteredApps: [AppInfo] = []
    private var selectedIndex: Int = -1

    private let columns = Theme.appGridColumns
    private let maxVisible = Theme.maxAppsVisible

    var onLaunch: ((AppInfo) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Data

    func setApps(_ apps: [AppInfo]) {
        allApps = apps
        filteredApps = Array(apps.prefix(maxVisible))
        selectedIndex = filteredApps.isEmpty ? -1 : 0
        rebuildGrid()
    }

    func filterApps(_ query: String) {
        if query.isEmpty {
            filteredApps = Array(allApps.prefix(maxVisible))
        } else {
            let q = query.lowercased()
            filteredApps = Array(
                allApps.filter { $0.name.lowercased().contains(q) }.prefix(maxVisible)
            )
        }
        selectedIndex = filteredApps.isEmpty ? -1 : 0
        rebuildGrid()
    }

    // MARK: - Selection

    func moveSelection(by delta: Int) {
        guard !filteredApps.isEmpty else { return }
        if selectedIndex < 0 {
            selectedIndex = 0
        } else {
            selectedIndex = (selectedIndex + delta + filteredApps.count) % filteredApps.count
        }
        updateHighlights()
    }

    func moveSelectionVertical(by delta: Int) {
        guard !filteredApps.isEmpty else { return }
        let rows = (filteredApps.count + columns - 1) / columns

        if selectedIndex < 0 {
            selectedIndex = 0
        } else {
            let col = selectedIndex % columns
            let row = selectedIndex / columns
            var newRow = row + delta

            if newRow < 0 { newRow = rows - 1 }
            if newRow >= rows { newRow = 0 }

            let newIndex = newRow * columns + col
            if newIndex < filteredApps.count {
                selectedIndex = newIndex
            } else {
                selectedIndex = filteredApps.count - 1
            }
        }
        updateHighlights()
    }

    func activateSelection() {
        guard selectedIndex >= 0, selectedIndex < filteredApps.count else { return }
        onLaunch?(filteredApps[selectedIndex])
    }

    func clearSelection() {
        selectedIndex = -1
        updateHighlights()
    }

    private func updateHighlights() {
        for (i, view) in itemViews.enumerated() {
            view.isHighlighted = (i == selectedIndex)
        }
    }

    // MARK: - Grid Layout

    private func rebuildGrid() {
        for view in itemViews {
            view.removeFromSuperview()
        }
        itemViews.removeAll()

        let spacing: CGFloat = 8
        let hPadding: CGFloat = 16
        let vPadding: CGFloat = 8
        let availableWidth = bounds.width - hPadding * 2 - spacing * CGFloat(columns - 1)
        let cellWidth = availableWidth / CGFloat(columns)
        let cellHeight: CGFloat = 80 // icon(48) + gap(4) + label(~14) + padding

        for (i, app) in filteredApps.enumerated() {
            let col = i % columns
            let row = i / columns

            let x = hPadding + CGFloat(col) * (cellWidth + spacing)
            let y = bounds.height - vPadding - CGFloat(row + 1) * (cellHeight + spacing)
            let frame = NSRect(x: x, y: y, width: cellWidth, height: cellHeight)

            let itemView = AppItemView(frame: frame)
            itemView.configure(app: app)
            itemView.onClick = { [weak self] in
                self?.onLaunch?(app)
            }

            addSubview(itemView)
            itemViews.append(itemView)
        }

        updateHighlights()
    }

    override func layout() {
        super.layout()
        rebuildGrid()
    }
}
