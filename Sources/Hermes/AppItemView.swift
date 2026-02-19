import AppKit

/// Single app cell: 48x48 rounded icon + centered label below
class AppItemView: NSView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")

    var isHighlighted = false {
        didSet { needsDisplay = true }
    }

    var onClick: (() -> Void)?

    private(set) var appInfo: AppInfo?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 8

        // Icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 10
        iconView.layer?.masksToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // Name label
        nameLabel.font = Theme.appNameFont
        nameLabel.textColor = Theme.text
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        nameLabel.isBezeled = false
        nameLabel.drawsBackground = false
        nameLabel.isEditable = false
        nameLabel.isSelectable = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        let iconSize = Theme.appIconSize

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            nameLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            nameLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 80),
        ])
    }

    func configure(app: AppInfo) {
        appInfo = app
        nameLabel.stringValue = app.name

        // Load icon
        if let image = AppScanner.loadIcon(for: app) {
            iconView.image = image
        } else {
            // Fallback: generic app icon
            iconView.image = NSWorkspace.shared.icon(forFile: app.path)
            // Try extracting in background
            AppScanner.extractIcon(appPath: app.path, appName: app.name) { [weak self] path in
                guard let self = self, let path = path else { return }
                if let img = NSImage(contentsOfFile: path) {
                    self.iconView.image = img
                }
            }
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
