import UIKit

extension UIColor {
    /// Parses a "#RRGGBB" string (the only format `nativeSettingsSpec()`
    /// sends) into a UIColor - returns nil for anything else rather than
    /// guessing, so a malformed value falls back to the caller's own
    /// default color instead of rendering black/transparent silently.
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let rgb = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// One row in the native Settings table - see NativeSettingsBridge's
/// header comment for the full spec this is parsed from.
struct NativeSettingsRow {
    let id: String
    let type: String // toggle, stepper, select, segmented, button, disclosure, link
    let title: String
    let subtitle: String
    let boolValue: Bool
    let stringValue: String
    let options: [(value: String, label: String)]
    let url: String?
    /// SF Symbol name + hex background color for the small rounded-square
    /// icon badge shown leading the row, matching the real iOS Settings
    /// app's own category rows (General, Notifications, ...) - nil for
    /// every row that doesn't pass one (most individual setting rows),
    /// which keeps the plain `.value1` look for those.
    let icon: String?
    let iconColor: String?
}

struct NativeSettingsSection {
    let header: String
    let rows: [NativeSettingsRow]
}

/// The native Settings screen, drawn as iOS 26 Liquid Glass cards (one
/// `UIGlassEffect` card per section) over the app's own parchment/navy
/// background, rather than a system grouped table - the system table's grey
/// cells and bottom action sheet for pickers looked foreign next to the rest
/// of the app. Mirrors the web app's own Settings screen (see index.html's
/// `nativeSettingsSpec()`): most rows relay to the already-rendered HTML
/// control underneath rather than duplicating its logic here.
///
/// Pickers (`select` rows) are a real pull-down `UIMenu` anchored to the
/// value button itself, so they open right where you tap. Colors resolve
/// against the app theme via `overrideUserInterfaceStyle` (`.label` ink,
/// `UIColor.betelGold` accents) so text and gold stay legible on the glass
/// in both themes.
final class NativeSettingsView: UIView {
    /// (rowId, value-as-string-or-nil) - value is set for select and
    /// segmented rows; stepper rows fold "Minus"/"Plus" into the id itself;
    /// nil for a plain toggle/button/disclosure tap (the web side just
    /// clicks the matching real HTML control either way).
    var onAction: ((String, String?) -> Void)?

    private let goldColor = UIColor.betelGold
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var sections: [NativeSettingsSection] = []
    private var isRTL = true
    private var isDark = false
    private var firstRowId: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 130, right: 0)
        addSubview(scrollView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 10
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.leftAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leftAnchor, constant: 16),
            contentStack.rightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.rightAnchor, constant: -16),
        ])
    }

    /// Rebuilt in place on every `configure()` (including right after a
    /// toggle flips) so the native screen always mirrors whatever the web
    /// side just computed. Scroll position is kept unless the screen itself
    /// changed (category list <-> a category).
    func configure(sections: [NativeSettingsSection], isDark: Bool, isRTL: Bool) {
        self.sections = sections
        self.isDark = isDark
        self.isRTL = isRTL
        overrideUserInterfaceStyle = isDark ? .dark : .light
        backgroundColor = isDark
            ? UIColor(red: 0.031, green: 0.051, blue: 0.098, alpha: 1)
            : UIColor(red: 0.937, green: 0.902, blue: 0.824, alpha: 1)
        let newFirst = sections.first?.rows.first?.id
        let screenChanged = newFirst != firstRowId
        firstRowId = newFirst
        rebuild()
        if screenChanged {
            layoutIfNeeded()
            scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.adjustedContentInset.top), animated: false)
        }
    }

    // MARK: - Building

    private func rebuild() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (sIndex, section) in sections.enumerated() {
            if !section.header.isEmpty {
                let header = UILabel()
                header.text = section.header
                header.setScaledFont(14, weight: .bold, maximumSize: 19)
                header.textColor = goldColor
                header.textAlignment = isRTL ? .right : .left
                let wrap = UIView()
                header.translatesAutoresizingMaskIntoConstraints = false
                wrap.addSubview(header)
                NSLayoutConstraint.activate([
                    header.topAnchor.constraint(equalTo: wrap.topAnchor, constant: sIndex == 0 ? 0 : 14),
                    header.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
                    header.leftAnchor.constraint(equalTo: wrap.leftAnchor, constant: 14),
                    header.rightAnchor.constraint(equalTo: wrap.rightAnchor, constant: -14),
                ])
                contentStack.addArrangedSubview(wrap)
            } else if sIndex > 0 {
                let gap = UIView()
                gap.heightAnchor.constraint(equalToConstant: 8).isActive = true
                contentStack.addArrangedSubview(gap)
            }
            contentStack.addArrangedSubview(makeCard(section: section, sectionIndex: sIndex))
        }
    }

    private func makeCard(section: NativeSettingsSection, sectionIndex: Int) -> UIView {
        let card: UIView
        let content: UIView
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect()
            // A light tint keeps the glass clear but gives text a steady
            // backdrop - untinted glass over the flat parchment read washed out.
            effect.tintColor = isDark
                ? UIColor(red: 0.10, green: 0.15, blue: 0.30, alpha: 0.45)
                : UIColor(white: 1, alpha: 0.55)
            let v = UIVisualEffectView(effect: effect)
            card = v
            content = v.contentView
        } else {
            let v = UIVisualEffectView(effect: UIBlurEffect(style: isDark ? .systemThinMaterialDark : .systemThinMaterialLight))
            card = v
            content = v.contentView
        }
        card.layer.cornerRadius = 26
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.layer.borderWidth = 1
        card.layer.borderColor = (isDark ? UIColor(white: 1, alpha: 0.14) : UIColor(white: 1, alpha: 0.9)).cgColor

        let rows = UIStackView()
        rows.axis = .vertical
        rows.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: content.topAnchor),
            rows.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            rows.leftAnchor.constraint(equalTo: content.leftAnchor),
            rows.rightAnchor.constraint(equalTo: content.rightAnchor),
        ])
        for (rIndex, row) in section.rows.enumerated() {
            if rIndex > 0 {
                let sep = UIView()
                sep.backgroundColor = goldColor.withAlphaComponent(0.2)
                sep.translatesAutoresizingMaskIntoConstraints = false
                let sepWrap = UIView()
                sepWrap.addSubview(sep)
                NSLayoutConstraint.activate([
                    sep.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
                    sep.topAnchor.constraint(equalTo: sepWrap.topAnchor),
                    sep.bottomAnchor.constraint(equalTo: sepWrap.bottomAnchor),
                    sep.leftAnchor.constraint(equalTo: sepWrap.leftAnchor, constant: 18),
                    sep.rightAnchor.constraint(equalTo: sepWrap.rightAnchor, constant: -18),
                ])
                rows.addArrangedSubview(sepWrap)
            }
            rows.addArrangedSubview(makeRow(row))
        }
        return card
    }

    private func makeRow(_ row: NativeSettingsRow) -> UIView {
        let rowView = NativeSettingsRowView()
        rowView.rowId = row.id
        rowView.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight

        let h = UIStackView()
        h.axis = .horizontal
        h.alignment = .center
        h.spacing = 12
        h.semanticContentAttribute = rowView.semanticContentAttribute
        h.translatesAutoresizingMaskIntoConstraints = false
        h.isUserInteractionEnabled = true
        rowView.addSubview(h)
        NSLayoutConstraint.activate([
            h.topAnchor.constraint(equalTo: rowView.topAnchor, constant: 12),
            h.bottomAnchor.constraint(equalTo: rowView.bottomAnchor, constant: -12),
            h.leftAnchor.constraint(equalTo: rowView.leftAnchor, constant: 18),
            h.rightAnchor.constraint(equalTo: rowView.rightAnchor, constant: -18),
            rowView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
        ])

        if let icon = row.icon {
            let badge = UIImageView(image: iconBadge(systemName: icon, hexColor: row.iconColor ?? "#8E8E93"))
            badge.setContentHuggingPriority(.required, for: .horizontal)
            h.addArrangedSubview(badge)
        }

        let texts = UIStackView()
        texts.axis = .vertical
        texts.spacing = 3
        texts.alignment = isRTL ? .trailing : .leading
        let title = UILabel()
        title.text = row.title
        title.numberOfLines = 0
        title.setScaledFont(16, weight: .semibold, maximumSize: 22)
        title.textColor = .label
        title.textAlignment = isRTL ? .right : .left
        texts.addArrangedSubview(title)
        if !row.subtitle.isEmpty && row.type != "select" {
            let sub = UILabel()
            sub.text = row.subtitle
            sub.numberOfLines = 0
            sub.setScaledFont(13, weight: .regular, maximumSize: 18)
            sub.textColor = .secondaryLabel
            sub.textAlignment = isRTL ? .right : .left
            texts.addArrangedSubview(sub)
        }
        texts.setContentHuggingPriority(.defaultLow, for: .horizontal)
        texts.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        h.addArrangedSubview(texts)

        if let control = makeControl(for: row, rowView: rowView) {
            control.setContentHuggingPriority(.required, for: .horizontal)
            control.setContentCompressionResistancePriority(.required, for: .horizontal)
            h.addArrangedSubview(control)
        }
        return rowView
    }

    private func makeControl(for row: NativeSettingsRow, rowView: NativeSettingsRowView) -> UIView? {
        switch row.type {
        case "toggle":
            let sw = UISwitch()
            sw.isOn = row.boolValue
            sw.onTintColor = goldColor
            sw.addAction(UIAction { [weak self] _ in self?.onAction?(row.id, nil) }, for: .valueChanged)
            return sw

        case "stepper":
            return makeStepper(row)

        case "segmented":
            let seg = UISegmentedControl(items: row.options.map { $0.label })
            if let idx = row.options.firstIndex(where: { $0.value == row.stringValue }) {
                seg.selectedSegmentIndex = idx
            }
            seg.selectedSegmentTintColor = goldColor
            seg.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 13, weight: .bold)], for: .selected)
            seg.setTitleTextAttributes([.foregroundColor: UIColor.label, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)], for: .normal)
            seg.addAction(UIAction { [weak self, weak seg] _ in
                guard let seg = seg, seg.selectedSegmentIndex >= 0, seg.selectedSegmentIndex < row.options.count else { return }
                self?.onAction?(row.id, row.options[seg.selectedSegmentIndex].value)
            }, for: .valueChanged)
            return seg

        case "select":
            return makeSelectButton(row)

        case "link", "disclosure", "button":
            rowView.onTap = { [weak self] in
                if row.type == "link" {
                    if let s = row.url, let url = URL(string: s) { UIApplication.shared.open(url) }
                } else {
                    self?.onAction?(row.id, nil)
                }
            }
            if row.type == "button" { return nil }
            let chevron = UIImageView(image: UIImage(
                systemName: row.type == "link" ? "arrow.up.forward" : (isRTL ? "chevron.left" : "chevron.right"),
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)))
            chevron.tintColor = .tertiaryLabel
            return chevron

        default:
            return nil
        }
    }

    /// A glass capsule: − value + (the old table version's stack had no
    /// size and never showed up at all).
    private func makeStepper(_ row: NativeSettingsRow) -> UIView {
        let capsule = UIView()
        capsule.backgroundColor = isDark ? UIColor(white: 1, alpha: 0.08) : UIColor(white: 1, alpha: 0.7)
        capsule.layer.cornerRadius = 19
        capsule.layer.cornerCurve = .continuous
        capsule.layer.borderWidth = 1
        capsule.layer.borderColor = goldColor.withAlphaComponent(0.35).resolvedColor(with: traitCollection).cgColor

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 2
        stack.semanticContentAttribute = .forceLeftToRight
        stack.translatesAutoresizingMaskIntoConstraints = false
        capsule.addSubview(stack)

        func stepButton(_ symbol: String, suffix: String, label: String) -> UIButton {
            let b = UIButton(type: .system)
            b.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)), for: .normal)
            b.tintColor = goldColor
            b.accessibilityLabel = label
            b.widthAnchor.constraint(equalToConstant: 38).isActive = true
            b.heightAnchor.constraint(equalToConstant: 38).isActive = true
            b.addAction(UIAction { [weak self] _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                self?.onAction?(row.id + suffix, nil)
            }, for: .touchUpInside)
            return b
        }
        let value = UILabel()
        value.text = row.stringValue
        value.setScaledFont(15, weight: .bold, maximumSize: 19)
        value.textColor = .label
        value.textAlignment = .center
        value.adjustsFontSizeToFitWidth = true
        value.minimumScaleFactor = 0.7
        value.widthAnchor.constraint(equalToConstant: 44).isActive = true

        stack.addArrangedSubview(stepButton("minus", suffix: "Minus", label: "Decrease"))
        stack.addArrangedSubview(value)
        stack.addArrangedSubview(stepButton("plus", suffix: "Plus", label: "Increase"))
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: capsule.topAnchor),
            stack.bottomAnchor.constraint(equalTo: capsule.bottomAnchor),
            stack.leftAnchor.constraint(equalTo: capsule.leftAnchor, constant: 2),
            stack.rightAnchor.constraint(equalTo: capsule.rightAnchor, constant: -2),
        ])
        return capsule
    }

    /// Current value + an up/down chevron; tapping opens a native pull-down
    /// menu right at the button with a checkmark on the current option.
    private func makeSelectButton(_ row: NativeSettingsRow) -> UIView {
        let current = row.options.first(where: { $0.value == row.stringValue })?.label ?? row.subtitle
        var config = UIButton.Configuration.plain()
        config.title = current
        config.image = UIImage(systemName: "chevron.up.chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold))
        config.imagePlacement = isRTL ? .leading : .trailing
        config.imagePadding = 6
        config.baseForegroundColor = goldColor
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            return a
        }
        let button = UIButton(configuration: config)
        button.semanticContentAttribute = .forceLeftToRight
        let actions = row.options.map { option in
            UIAction(title: option.label, state: option.value == row.stringValue ? .on : .off) { [weak self] _ in
                self?.onAction?(row.id, option.value)
            }
        }
        button.menu = UIMenu(title: row.title, children: actions)
        button.showsMenuAsPrimaryAction = true
        return button
    }

    private func iconBadge(systemName: String, hexColor: String) -> UIImage? {
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 9)
            (UIColor(hex: hexColor) ?? .systemGray).setFill()
            path.fill()
            // Specular top sheen so the badge reads as glass, not a flat tile
            let sheen = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height / 2), cornerRadius: 9)
            UIColor(white: 1, alpha: 0.18).setFill()
            sheen.fill()
            let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            guard let symbol = UIImage(systemName: systemName, withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) else { return }
            let origin = CGPoint(x: (size.width - symbol.size.width) / 2, y: (size.height - symbol.size.height) / 2)
            symbol.draw(at: origin)
        }
    }
}

/// A row that highlights while pressed and fires `onTap` (disclosure,
/// link and button rows) - controls inside it handle their own touches.
final class NativeSettingsRowView: UIView {
    var rowId = ""
    var onTap: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard onTap != nil else { return }
        UIView.animate(withDuration: 0.12) { self.backgroundColor = UIColor.label.withAlphaComponent(0.06) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let onTap = onTap else { return }
        UIView.animate(withDuration: 0.25) { self.backgroundColor = .clear }
        if let t = touches.first, bounds.contains(t.location(in: self)) {
            UISelectionFeedbackGenerator().selectionChanged()
            onTap()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.25) { self.backgroundColor = .clear }
    }
}
