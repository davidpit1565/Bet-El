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

/// One input of a "form" row: a text field or a pull-down menu.
struct NativeSettingsField {
    let key: String
    let kind: String // text, menu
    let placeholder: String
    let value: String
    let options: [(value: String, label: String)]
}

/// One row in the native Settings table - see NativeSettingsBridge's
/// header comment for the full spec this is parsed from.
struct NativeSettingsRow {
    let id: String
    let type: String // toggle, stepper, select, segmented, button, disclosure, link, item, form
    let title: String
    let subtitle: String
    let boolValue: Bool
    let stringValue: String
    let options: [(value: String, label: String)]
    let url: String?
    /// SF Symbol name + hex background color for the small rounded-square
    /// icon badge shown leading the row, matching the real iOS Settings
    /// app's own category rows.
    let icon: String?
    let iconColor: String?
    let fields: [NativeSettingsField]
    let buttonLabel: String
}

struct NativeSettingsSection {
    let header: String
    let footer: String
    let rows: [NativeSettingsRow]
}

/// The native Settings screen: a real `UITableView` in `.insetGrouped` style
/// (the same list the iOS Settings app uses) with a real `UISwitch`,
/// `UIStepper`, `UISegmentedControl`, pull-down `UIMenu` pickers, text fields
/// and swipe-to-delete rows. The web app's `nativeSettingsSpec()` stays the
/// single source of truth: every change is relayed to
/// `window.NativeSettingsHost.onAction(id, value)` and JS answers by
/// re-sending the whole spec. Accent colors resolve against the app theme via
/// `overrideUserInterfaceStyle`; on iOS 26 the add buttons use Liquid Glass,
/// older systems get the plain filled style.
final class NativeSettingsView: UIView, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    /// (rowId, value) - value carries the chosen option (select/segmented), the
    /// item index (item delete) or a JSON object (form); nil for plain taps.
    var onAction: ((String, String?) -> Void)?

    private let goldColor = UIColor.betelGold
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sections: [NativeSettingsSection] = []
    private var isRTL = true
    private var isDark = false
    private var firstRowId: String?
    private var drafts: [String: [String: String]] = [:]
    private var pendingClear: String?
    private let baseBottomInset: CGFloat = 130

    override init(frame: CGRect) {
        super.init(frame: frame)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .interactive
        tableView.cellLayoutMarginsFollowReadableWidth = false
        tableView.sectionHeaderTopPadding = 8
        tableView.contentInset.bottom = baseBottomInset
        tableView.verticalScrollIndicatorInsets.bottom = baseBottomInset
        tableView.tintColor = goldColor
        tableView.backgroundColor = .clear
        addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { NotificationCenter.default.removeObserver(self) }

    /// Rebuilt on every `configure()` (including right after a toggle flips)
    /// so the native screen always mirrors whatever the web side just
    /// computed. Scroll position is kept unless the screen itself changed
    /// (category list <-> a category).
    func configure(sections: [NativeSettingsSection], isDark: Bool, isRTL: Bool) {
        self.sections = sections
        self.isDark = isDark
        self.isRTL = isRTL
        if let id = pendingClear { drafts[id] = nil; pendingClear = nil }
        overrideUserInterfaceStyle = isDark ? .dark : .light
        backgroundColor = isDark
            ? UIColor(red: 0.031, green: 0.051, blue: 0.098, alpha: 1)
            : UIColor(red: 0.937, green: 0.902, blue: 0.824, alpha: 1)
        tableView.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        let newFirst = sections.first?.rows.first?.id
        let screenChanged = newFirst != firstRowId
        firstRowId = newFirst
        if screenChanged { drafts.removeAll() }
        tableView.reloadData()
        if screenChanged {
            tableView.layoutIfNeeded()
            tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
        }
    }

    // MARK: - Keyboard

    @objc private func keyboardChanged(_ note: Notification) {
        guard window != nil, let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let local = convert(frame, from: nil)
        let overlap = max(0, bounds.maxY - local.minY)
        let bottom = overlap > 0 ? overlap + 12 : baseBottomInset
        tableView.contentInset.bottom = bottom
        tableView.verticalScrollIndicatorInsets.bottom = bottom
        if overlap > 0, let responder = findFirstResponder(in: tableView) {
            let rect = tableView.convert(responder.bounds, from: responder)
            tableView.scrollRectToVisible(rect.insetBy(dx: 0, dy: -40), animated: true)
        }
    }

    private func findFirstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder { return view }
        for sub in view.subviews { if let r = findFirstResponder(in: sub) { return r } }
        return nil
    }

    // MARK: - Data source

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let text = sections[section].header
        guard !text.isEmpty else { return nil }
        return headerFooter(text: text, header: true)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let text = sections[section].footer
        guard !text.isEmpty else { return nil }
        return headerFooter(text: text, header: false)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        sections[section].header.isEmpty ? (section == 0 ? 8 : 12) : UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        sections[section].footer.isEmpty ? 4 : UITableView.automaticDimension
    }

    private func headerFooter(text: String, header: Bool) -> UIView {
        let v = UITableViewHeaderFooterView()
        v.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        var c = header ? UIListContentConfiguration.groupedHeader() : UIListContentConfiguration.groupedFooter()
        c.text = text
        c.textProperties.color = header ? goldColor : .secondaryLabel
        if header { c.textProperties.font = UIFont.preferredFont(forTextStyle: .footnote).bold() }
        c.textProperties.alignment = .natural
        v.contentConfiguration = c
        return v
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        cell.contentView.semanticContentAttribute = cell.semanticContentAttribute
        cell.tintColor = goldColor
        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = isDark ? UIColor(red: 0.075, green: 0.105, blue: 0.2, alpha: 1) : UIColor(white: 1, alpha: 0.78)
        cell.backgroundConfiguration = bg

        switch row.type {
        case "segmented": configureSegmented(cell, row)
        case "form": configureForm(cell, row)
        default: configureStandard(cell, row)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        ["disclosure", "button", "link"].contains(sections[indexPath.section].rows[indexPath.row].type)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row.type {
        case "link":
            if let s = row.url, let url = URL(string: s) { UIApplication.shared.open(url) }
        case "disclosure", "button":
            UISelectionFeedbackGenerator().selectionChanged()
            onAction?(row.id, nil)
        default: break
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let row = sections[indexPath.section].rows[indexPath.row]
        guard row.type == "item" else { return nil }
        let delete = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, done in
            self?.onAction?(row.id, row.stringValue)
            done(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }

    // MARK: - Standard rows

    private func configureStandard(_ cell: UITableViewCell, _ row: NativeSettingsRow) {
        var c = UIListContentConfiguration.subtitleCell()
        c.text = row.title
        c.textProperties.numberOfLines = 0
        c.textProperties.color = row.type == "button" ? goldColor : .label
        // A select row shows its current choice on the right, so the
        // subtitle (the same current value) would only duplicate it.
        if !row.subtitle.isEmpty && row.type != "select" {
            c.secondaryText = row.subtitle
            c.secondaryTextProperties.numberOfLines = 0
            c.secondaryTextProperties.color = .secondaryLabel
            c.secondaryTextProperties.font = UIFont.preferredFont(forTextStyle: .footnote)
        }
        c.textToSecondaryTextVerticalPadding = 2
        if let icon = row.icon {
            c.image = iconBadge(systemName: icon, hexColor: row.iconColor ?? "#8E8E93")
            c.imageProperties.reservedLayoutSize = CGSize(width: 30, height: 30)
            c.imageToTextPadding = 14
        }
        cell.contentConfiguration = c

        switch row.type {
        case "toggle":
            let sw = UISwitch()
            sw.isOn = row.boolValue
            sw.onTintColor = goldColor
            sw.addAction(UIAction { [weak self] _ in self?.onAction?(row.id, nil) }, for: .valueChanged)
            cell.accessoryView = sw
            cell.selectionStyle = .none
        case "stepper":
            cell.accessoryView = makeStepper(row)
            cell.selectionStyle = .none
        case "select":
            cell.accessoryView = makeSelectButton(row)
            cell.selectionStyle = .none
        case "disclosure":
            cell.accessoryType = .disclosureIndicator
        case "link":
            let iv = UIImageView(image: UIImage(systemName: "arrow.up.forward",
                                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
            iv.tintColor = .tertiaryLabel
            iv.sizeToFit()
            cell.accessoryView = iv
        case "item":
            let b = UIButton(type: .system)
            b.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
            b.tintColor = .systemRed
            b.accessibilityLabel = "Delete"
            b.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
            b.addAction(UIAction { [weak self] _ in self?.onAction?(row.id, row.stringValue) }, for: .touchUpInside)
            cell.accessoryView = b
            cell.selectionStyle = .none
        default:
            cell.selectionStyle = .none
        }
    }

    /// A real UIStepper plus the current value. UIStepper keeps its own
    /// number, so each press is turned into a plus/minus event and the stepper
    /// is re-centred; the shown value always comes from JS.
    private func makeStepper(_ row: NativeSettingsRow) -> UIView {
        let value = UILabel()
        value.text = row.stringValue
        value.font = UIFont.monospacedDigitSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .semibold)
        value.adjustsFontForContentSizeCategory = true
        value.textColor = .secondaryLabel
        // Two plain buttons (UIStepper's value-reset trick proved unreliable on device: taps did nothing).
        func stepButton(_ symbol: String, _ suffix: String, _ label: String) -> UIButton {
            let b = UIButton(type: .system)
            b.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)), for: .normal)
            b.tintColor = goldColor
            b.accessibilityLabel = label
            b.widthAnchor.constraint(equalToConstant: 46).isActive = true
            b.heightAnchor.constraint(equalToConstant: 34).isActive = true
            b.addAction(UIAction { [weak self] _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                self?.onAction?(row.id + suffix, nil)
            }, for: .touchUpInside)
            return b
        }
        let divider = UIView()
        divider.backgroundColor = UIColor.separator
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        divider.heightAnchor.constraint(equalToConstant: 18).isActive = true
        let stepper = UIStackView(arrangedSubviews: [stepButton("minus", "Minus", "−"), divider, stepButton("plus", "Plus", "+")])
        stepper.axis = .horizontal
        stepper.alignment = .center
        stepper.backgroundColor = UIColor.tertiarySystemFill
        stepper.layer.cornerRadius = 9
        stepper.semanticContentAttribute = .forceLeftToRight
        let stack = UIStackView(arrangedSubviews: [value, stepper])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.semanticContentAttribute = .forceLeftToRight
        stack.frame.size = stack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return stack
    }

    /// Current value + an up/down chevron; tapping opens a native pull-down
    /// menu with a checkmark on the current option.
    private func makeSelectButton(_ row: NativeSettingsRow) -> UIView {
        let current = row.options.first(where: { $0.value == row.stringValue })?.label ?? row.subtitle
        var config = UIButton.Configuration.plain()
        config.title = current
        config.image = UIImage(systemName: "chevron.up.chevron.down",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold))
        config.imagePlacement = .trailing
        config.imagePadding = 6
        config.baseForegroundColor = .secondaryLabel
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 0)
        config.titleLineBreakMode = .byTruncatingTail
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = UIFont.preferredFont(forTextStyle: .body)
            return a
        }
        let button = UIButton(configuration: config)
        button.semanticContentAttribute = .forceLeftToRight
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.menu = UIMenu(title: row.title, children: row.options.map { option in
            UIAction(title: option.label, state: option.value == row.stringValue ? .on : .off) { [weak self] _ in
                self?.onAction?(row.id, option.value)
            }
        })
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = false
        button.frame.size = button.systemLayoutSizeFitting(CGSize(width: 220, height: UIView.layoutFittingCompressedSize.height),
                                                           withHorizontalFittingPriority: .fittingSizeLevel,
                                                           verticalFittingPriority: .fittingSizeLevel)
        button.frame.size.width = min(button.frame.size.width, 220)
        return button
    }

    // MARK: - Segmented row

    private func configureSegmented(_ cell: UITableViewCell, _ row: NativeSettingsRow) {
        cell.selectionStyle = .none
        let title = UILabel()
        title.text = row.title
        title.numberOfLines = 0
        title.font = UIFont.preferredFont(forTextStyle: .body)
        title.adjustsFontForContentSizeCategory = true
        title.textColor = .label
        let stack = UIStackView(arrangedSubviews: [title])
        if !row.subtitle.isEmpty {
            let sub = UILabel()
            sub.text = row.subtitle
            sub.numberOfLines = 0
            sub.font = UIFont.preferredFont(forTextStyle: .footnote)
            sub.adjustsFontForContentSizeCategory = true
            sub.textColor = .secondaryLabel
            stack.addArrangedSubview(sub)
        }
        let seg = UISegmentedControl(items: row.options.map { $0.label })
        if let idx = row.options.firstIndex(where: { $0.value == row.stringValue }) { seg.selectedSegmentIndex = idx }
        seg.selectedSegmentTintColor = goldColor
        seg.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        seg.setTitleTextAttributes([.foregroundColor: UIColor.label], for: .normal)
        seg.apportionsSegmentWidthsByContent = false
        for case let label as UILabel in seg.subviews.flatMap({ $0.subviews }) { label.numberOfLines = 2; label.adjustsFontSizeToFitWidth = true }
        seg.addAction(UIAction { [weak self, weak seg] _ in
            guard let seg = seg, seg.selectedSegmentIndex >= 0, seg.selectedSegmentIndex < row.options.count else { return }
            self?.onAction?(row.id, row.options[seg.selectedSegmentIndex].value)
        }, for: .valueChanged)
        stack.addArrangedSubview(seg)
        stack.axis = .vertical
        stack.spacing = 6
        stack.setCustomSpacing(10, after: stack.arrangedSubviews[stack.arrangedSubviews.count - 2])
        pin(stack, in: cell.contentView)
    }

    // MARK: - Form row (name / dedication / yahrzeit)

    private func configureForm(_ cell: UITableViewCell, _ row: NativeSettingsRow) {
        cell.selectionStyle = .none
        var draft = drafts[row.id] ?? [:]
        for f in row.fields where f.kind == "menu" && draft[f.key] == nil { draft[f.key] = f.value }
        drafts[row.id] = draft

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10

        var menuRun: UIStackView?
        for field in row.fields {
            if field.kind == "menu" {
                if menuRun == nil {
                    let h = UIStackView()
                    h.axis = .horizontal
                    h.spacing = 10
                    h.distribution = .fillEqually
                    stack.addArrangedSubview(h)
                    menuRun = h
                }
                menuRun?.addArrangedSubview(makeFormMenu(row: row, field: field))
            } else {
                menuRun = nil
                let tf = UITextField()
                tf.borderStyle = .roundedRect
                tf.placeholder = field.placeholder
                tf.text = drafts[row.id]?[field.key] ?? ""
                tf.font = UIFont.preferredFont(forTextStyle: .body)
                tf.adjustsFontForContentSizeCategory = true
                tf.returnKeyType = .done
                tf.autocorrectionType = .no
                tf.clearButtonMode = .whileEditing
                tf.delegate = self
                tf.textAlignment = .natural
                tf.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
                tf.addAction(UIAction { [weak self, weak tf] _ in
                    self?.drafts[row.id, default: [:]][field.key] = tf?.text ?? ""
                }, for: .editingChanged)
                tf.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
                stack.addArrangedSubview(tf)
            }
        }

        var cfg: UIButton.Configuration
        if #available(iOS 26.0, *) { cfg = .prominentGlass() } else { cfg = .filled() }
        cfg.title = row.buttonLabel
        cfg.image = UIImage(systemName: "plus")
        cfg.imagePadding = 6
        cfg.baseBackgroundColor = goldColor
        cfg.baseForegroundColor = .white
        cfg.cornerStyle = .capsule
        cfg.buttonSize = .medium
        let add = UIButton(configuration: cfg)
        add.titleLabel?.adjustsFontForContentSizeCategory = true
        add.addAction(UIAction { [weak self] _ in self?.submitForm(row) }, for: .touchUpInside)
        let addWrap = UIStackView(arrangedSubviews: [add])
        addWrap.axis = .horizontal
        addWrap.alignment = .center
        addWrap.distribution = .fill
        add.setContentHuggingPriority(.required, for: .horizontal)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addWrap.addArrangedSubview(spacer)
        stack.addArrangedSubview(addWrap)

        pin(stack, in: cell.contentView)
    }

    private func makeFormMenu(row: NativeSettingsRow, field: NativeSettingsField) -> UIButton {
        let selected = drafts[row.id]?[field.key] ?? field.value
        let label = field.options.first(where: { $0.value == selected })?.label ?? selected
        var config = UIButton.Configuration.gray()
        config.title = label
        config.image = UIImage(systemName: "chevron.up.chevron.down",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold))
        config.imagePlacement = .trailing
        config.imagePadding = 6
        config.baseForegroundColor = .label
        config.cornerStyle = .medium
        config.titleLineBreakMode = .byTruncatingTail
        let b = UIButton(configuration: config)
        b.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        b.titleLabel?.adjustsFontForContentSizeCategory = true
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        b.menu = UIMenu(children: field.options.map { option in
            UIAction(title: option.label, state: option.value == selected ? .on : .off) { [weak self, weak b] _ in
                self?.drafts[row.id, default: [:]][field.key] = option.value
                if var cfg = b?.configuration { cfg.title = option.label; b?.configuration = cfg }
                // Rebuild the menu so the checkmark follows the choice.
                b?.menu = UIMenu(children: field.options.map { o in
                    UIAction(title: o.label, state: o.value == option.value ? .on : .off) { _ in
                        self?.drafts[row.id, default: [:]][field.key] = o.value
                        if var cfg = b?.configuration { cfg.title = o.label; b?.configuration = cfg }
                    }
                })
            }
        })
        b.showsMenuAsPrimaryAction = true
        return b
    }

    private func submitForm(_ row: NativeSettingsRow) {
        endEditing(true)
        var payload: [String: String] = [:]
        for f in row.fields { payload[f.key] = drafts[row.id]?[f.key] ?? f.value }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Text drafts are cleared when JS accepts the entry (it re-sends the
        // spec); if it rejects an empty name the typed text stays.
        pendingClear = row.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if self?.pendingClear == row.id { self?.pendingClear = nil }
        }
        onAction?(row.id, json)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    // MARK: - Helpers

    private func pin(_ content: UIView, in container: UIView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        let guide = container.layoutMarginsGuide
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            content.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
        ])
    }

    private func iconBadge(systemName: String, hexColor: String) -> UIImage? {
        let size = CGSize(width: 30, height: 30)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 7)
            (UIColor(hex: hexColor) ?? .systemGray).setFill()
            path.fill()
            let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            guard let symbol = UIImage(systemName: systemName, withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) else { return }
            let origin = CGPoint(x: (size.width - symbol.size.width) / 2, y: (size.height - symbol.size.height) / 2)
            symbol.draw(at: origin)
        }
    }
}

private extension UIFont {
    func bold() -> UIFont {
        guard let d = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: d, size: pointSize)
    }
}
