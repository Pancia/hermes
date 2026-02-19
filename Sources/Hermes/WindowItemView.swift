import AppKit

/// Single row in the window switcher: space badge + title + app name
class WindowItemView: NSView {
    private let spaceBadge = NSView()
    private let spaceLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let appLabel = NSTextField(labelWithString: "")

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
        layer?.cornerRadius = Theme.itemCornerRadius

        // Space badge background — cyan, 24x22, rounded 4px
        spaceBadge.wantsLayer = true
        spaceBadge.layer?.cornerRadius = 4
        spaceBadge.layer?.backgroundColor = Theme.accent.cgColor
        spaceBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spaceBadge)

        // Space number label — SF Mono 12pt semibold, centered in badge
        spaceLabel.font = Theme.windowSpaceFont
        spaceLabel.textColor = Theme.bg
        spaceLabel.alignment = .center
        spaceLabel.isBezeled = false
        spaceLabel.drawsBackground = false
        spaceLabel.isEditable = false
        spaceLabel.isSelectable = false
        spaceLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spaceLabel)

        // Title — flex, ellipsis
        titleLabel.font = Theme.bodyFont
        titleLabel.textColor = Theme.text
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // App name — dim, 12px
        appLabel.font = Theme.breadcrumbFont
        appLabel.textColor = Theme.textDim
        appLabel.lineBreakMode = .byTruncatingTail
        appLabel.isBezeled = false
        appLabel.drawsBackground = false
        appLabel.isEditable = false
        appLabel.isSelectable = false
        appLabel.translatesAutoresizingMaskIntoConstraints = false
        appLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        appLabel.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(appLabel)

        NSLayoutConstraint.activate([
            // Space badge: 24x22, left-aligned
            spaceBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.itemPadding),
            spaceBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            spaceBadge.widthAnchor.constraint(equalToConstant: 24),
            spaceBadge.heightAnchor.constraint(equalToConstant: 22),

            // Space label centered in badge
            spaceLabel.centerXAnchor.constraint(equalTo: spaceBadge.centerXAnchor),
            spaceLabel.centerYAnchor.constraint(equalTo: spaceBadge.centerYAnchor),

            // Title — after badge, flexible
            titleLabel.leadingAnchor.constraint(equalTo: spaceBadge.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: appLabel.leadingAnchor, constant: -12),

            // App name — right-aligned
            appLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.itemPadding),
            appLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    func configure(window: WindowInfo) {
        spaceLabel.stringValue = "\(window.space)"
        titleLabel.stringValue = window.title
        appLabel.stringValue = window.app
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            layer?.backgroundColor = Theme.bgHover.cgColor
        } else {
            layer?.backgroundColor = Theme.bgItem.cgColor
        }
        super.draw(dirtyRect)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
