import AppKit

/// Custom NSView cell: cyan key badge + label + arrow indicator for submenus
class MenuItemView: NSView {
    let keyLabel = NSTextField(labelWithString: "")
    let titleLabel = NSTextField(labelWithString: "")
    let arrowLabel = NSTextField(labelWithString: "")
    private let keyBadge = NSView()

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

        // Key badge background
        keyBadge.wantsLayer = true
        keyBadge.layer?.cornerRadius = 4
        keyBadge.layer?.backgroundColor = Theme.accent.cgColor
        keyBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(keyBadge)

        // Key label (single char, centered in badge)
        keyLabel.font = Theme.keyFont
        keyLabel.textColor = Theme.bg
        keyLabel.alignment = .center
        keyLabel.isBezeled = false
        keyLabel.drawsBackground = false
        keyLabel.isEditable = false
        keyLabel.isSelectable = false
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(keyLabel)

        // Title label
        titleLabel.font = Theme.bodyFont
        titleLabel.textColor = Theme.text
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Arrow indicator for submenus
        arrowLabel.font = Theme.bodyFont
        arrowLabel.textColor = Theme.textDim
        arrowLabel.stringValue = ">"
        arrowLabel.isBezeled = false
        arrowLabel.drawsBackground = false
        arrowLabel.isEditable = false
        arrowLabel.isSelectable = false
        arrowLabel.isHidden = true
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(arrowLabel)

        NSLayoutConstraint.activate([
            // Key badge: 26x24, left-aligned with padding
            keyBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.itemPadding),
            keyBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            keyBadge.widthAnchor.constraint(equalToConstant: 26),
            keyBadge.heightAnchor.constraint(equalToConstant: 24),

            // Key label centered in badge
            keyLabel.centerXAnchor.constraint(equalTo: keyBadge.centerXAnchor),
            keyLabel.centerYAnchor.constraint(equalTo: keyBadge.centerYAnchor),

            // Title label
            titleLabel.leadingAnchor.constraint(equalTo: keyBadge.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: arrowLabel.leadingAnchor, constant: -4),

            // Arrow indicator
            arrowLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.itemPadding),
            arrowLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    func configure(key: String, entry: CommandEntry) {
        keyLabel.stringValue = key.uppercased()
        titleLabel.stringValue = entry.title

        if entry.isSubmenu {
            titleLabel.textColor = Theme.textSubmenu
            arrowLabel.isHidden = false
        } else {
            titleLabel.textColor = Theme.text
            arrowLabel.isHidden = true
        }
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
