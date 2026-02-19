import AppKit

/// Vertical scrollable list of windows with selection and filtering
class WindowListView: NSView {
    private let scrollView = NSScrollView()
    private let contentView = NSView()
    private var itemViews: [WindowItemView] = []
    private var allWindows: [WindowInfo] = []
    private var filteredWindows: [WindowInfo] = []
    private var selectedIndex: Int = -1

    var onSelect: ((WindowInfo) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
        ])
    }

    func setWindows(_ windows: [WindowInfo]) {
        allWindows = windows
        filteredWindows = windows
        selectedIndex = windows.isEmpty ? -1 : 0
        rebuildList()
    }

    func filter(query: String) {
        if query.isEmpty {
            filteredWindows = allWindows
        } else {
            let q = query.lowercased()
            filteredWindows = allWindows.filter {
                $0.title.lowercased().contains(q) || $0.app.lowercased().contains(q)
            }
        }
        selectedIndex = filteredWindows.isEmpty ? -1 : 0
        rebuildList()
    }

    // MARK: - Selection

    func moveSelection(by delta: Int) {
        guard !filteredWindows.isEmpty else { return }
        if selectedIndex < 0 {
            selectedIndex = 0
        } else {
            selectedIndex = (selectedIndex + delta + filteredWindows.count) % filteredWindows.count
        }
        updateHighlights()
        scrollToSelection()
    }

    func activateSelection() {
        guard selectedIndex >= 0, selectedIndex < filteredWindows.count else { return }
        onSelect?(filteredWindows[selectedIndex])
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

    private func scrollToSelection() {
        guard selectedIndex >= 0, selectedIndex < itemViews.count else { return }
        let itemView = itemViews[selectedIndex]
        contentView.scrollToVisible(itemView.frame)
    }

    // MARK: - Layout

    private func rebuildList() {
        for view in itemViews {
            view.removeFromSuperview()
        }
        itemViews.removeAll()

        let hPadding: CGFloat = 12
        let vPadding: CGFloat = 4
        let spacing: CGFloat = 4
        let rowHeight: CGFloat = 38
        let itemWidth = bounds.width - hPadding * 2

        let totalHeight = CGFloat(filteredWindows.count) * (rowHeight + spacing) - spacing + vPadding * 2
        let contentHeight = max(totalHeight, bounds.height)
        contentView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: contentHeight)

        for (i, window) in filteredWindows.enumerated() {
            let y = contentHeight - vPadding - CGFloat(i + 1) * (rowHeight + spacing) + spacing
            let frame = NSRect(x: hPadding, y: y, width: itemWidth, height: rowHeight)

            let itemView = WindowItemView(frame: frame)
            itemView.configure(window: window)
            itemView.isHighlighted = (i == selectedIndex)
            itemView.onClick = { [weak self] in
                self?.onSelect?(window)
            }

            contentView.addSubview(itemView)
            itemViews.append(itemView)
        }
    }

    override func layout() {
        super.layout()
        rebuildList()
    }
}
