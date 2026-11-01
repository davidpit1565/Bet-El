import UIKit

/// A real native floating header bar, rendered with iOS 26's genuine
/// Liquid Glass material (`UIGlassEffect`) - not a CSS `backdrop-filter`
/// approximation - mirroring the web app's shared `topbar(title, backTo,
/// rightHtml, nativeOpts)` HTML header: a title, an optional back button,
/// and 0-3 trailing icon actions (favorite/share/QR/info - see
/// `onTrailingAction`/`configure(actions:)`). Only screens whose
/// right-side content is a genuinely unrepresentable whole panel (the
/// siddur/Tehillim-chapter readers' own multi-button toolsFab, as opposed
/// to a plain icon button) keep their own HTML header instead - see
/// index.html's `tb-native-exempt` class and `hideNativeTopBar()`.
///
/// REQUIRES BUILDING WITH THE iOS 26 SDK (Xcode 26+) - see
/// NativeToolsFabView's header comment for why; the same applies here.
final class NativeTopBarView: UIView {
    var onBack: (() -> Void)?

    /// A tap on one of the (0-3) trailing icon buttons `configure(actions:)`
    /// sets up - favorite/share/QR/info, the handful of screens whose only
    /// "custom right-side content" is plain icon buttons rather than a
    /// whole panel (see index.html's `topbar(title, backTo, rightHtml,
    /// nativeOpts)` - those pass `nativeOpts.actions` through
    /// `syncNativeTopBar` instead of leaving the screen tb-native-exempt).
    var onTrailingAction: ((String) -> Void)?

    /// Long-pressing the title reveals a real `UIContextMenuInteraction`
    /// quick-jump menu ("home"/"settings"/"share") - the one piece of the
    /// screen that's genuine native UIKit content (everything below the
    /// bar is the WKWebView), so it's also the only spot a true system
    /// context menu can attach to; the web app's own cards/tiles are plain
    /// HTML, and WKWebView's own context-menu customization hook
    /// (`webView(_:contextMenuConfigurationForElement:completionHandler:)`)
    /// only fires for links/images, not arbitrary custom DOM elements, so
    /// it can't give those tiles one.
    var onQuickAction: ((String) -> Void)?

    private let goldColor = UIColor.betelGold
    private var barHeight: CGFloat { A11y.scaled(44) }
    private var buttonSize: CGFloat { A11y.scaled(38) }
    private var scaledConstraints: [(NSLayoutConstraint, CGFloat)] = []

    private let titleLabel = UILabel()
    /// Glass title button (shown instead of the plain label when a `titleSheet` is present): tapping it opens `TitleSheetViewController`.
    private let titleButton = UIButton(type: .system)
    /// Spec for the picker sheet behind the title button; set by NativeTopBarBridge.configure before each configure() (nil = plain title).
    static var titleSheet: TitleSheetSpec?
    var onTitleSheet: (() -> Void)?
    @objc private func titleSheetTapped() { onTitleSheet?() }
    private let backButton = UIButton(type: .system)
    private var backButtonWidthConstraint: NSLayoutConstraint?
    private let actionsStack = UIStackView()
    private var titleLeadingConstraint: NSLayoutConstraint!
    private var titleTrailingConstraint: NSLayoutConstraint!
    private var titleButtonLeading: NSLayoutConstraint!
    private var titleButtonTrailing: NSLayoutConstraint!
    private var titleButtonText = ""
    private var titleButtonSize: CGFloat = 0

    /// The bar's own height below the safe-area top inset - used by
    /// MainViewController to report --native-header-h to the web view.
    var contentHeight: CGFloat { barHeight }

    /// Tapping the header title scrolls the page back to the top (like tapping the iOS status bar).
    var onTitleTap: (() -> Void)?
    @objc private func titleTapped() { onTitleTap?() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBar()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// iOS 26-style header: no full-width material band (a UIGlassEffect
    /// slab over the parchment background read as a heavy grey strip) -
    /// just the app's own background color fading out under the status
    /// bar/title so scrolled content stays legible, with the back button
    /// and actions as individual floating Liquid Glass circles, the way
    /// system apps' navigation bars look on iOS 26.
    private let fadeLayer = CAGradientLayer()

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fadeLayer.frame = bounds
        CATransaction.commit()
        fitTitleButtonFont()
    }

    /// Long titles / long languages shrink the font instead of being cut off ("...").
    private func fitTitleButtonFont() {
        guard !titleButton.isHidden, var config = titleButton.configuration, !titleButtonText.isEmpty, titleButtonLeading != nil else { return }
        let sideMargins = titleButtonLeading.constant + abs(titleButtonTrailing.constant)
        let chrome: CGFloat = 18 + 16 + 8 + A11y.scaled(12) + 4
        let avail = bounds.width - safeAreaInsets.left - safeAreaInsets.right - sideMargins - chrome
        guard avail > 40 else { return }
        var size = A11y.scaled(18)
        let minSize: CGFloat = 11
        while size > minSize {
            let w = (titleButtonText as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: size, weight: .bold)]).width
            if w <= avail { break }
            size -= 0.5
        }
        guard abs(size - titleButtonSize) > 0.1 else { return }
        titleButtonSize = size
        var attrs = AttributeContainer()
        attrs.font = UIFont.systemFont(ofSize: size, weight: .bold)
        config.attributedTitle = AttributedString(titleButtonText, attributes: attrs)
        titleButton.configuration = config
    }

    /// The header's opaque background - also used by the Search tab's docked field right under it.
    static func background(isDark: Bool) -> UIColor {
        isDark
            ? UIColor(red: 0.051, green: 0.078, blue: 0.165, alpha: 1)
            : UIColor(red: 0.965, green: 0.937, blue: 0.875, alpha: 1)
    }

    func setTheme(isDark: Bool) {
        let bg = NativeTopBarView.background(isDark: isDark)
        // fully OPAQUE (no fade to transparent): scrolled text must never show through the header
        fadeLayer.colors = [bg.cgColor, bg.cgColor]
        fadeLayer.locations = [0, 1]
        overrideUserInterfaceStyle = isDark ? .dark : .light
    }

    static func glassCircle(_ button: UIButton, symbol: String, tint: UIColor) {
        let image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        if #available(iOS 26.0, *) {
            var config = UIButton.Configuration.glass()
            config.image = image
            config.cornerStyle = .capsule
            config.baseForegroundColor = tint
            button.configuration = config
        } else {
            var config = UIButton.Configuration.filled()
            config.image = image
            config.cornerStyle = .capsule
            config.background.visualEffect = UIBlurEffect(style: .systemThinMaterial)
            config.baseBackgroundColor = .clear
            config.baseForegroundColor = tint
            button.configuration = config
        }
    }

    private func setupBar() {
        setTheme(isDark: false)
        layer.addSublayer(fadeLayer)
        let contentView: UIView = self

        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.tintColor = goldColor
        NativeTopBarView.glassCircle(backButton, symbol: "chevron.right", tint: goldColor)
        backButton.addTarget(self, action: #selector(tapBack), for: .touchUpInside)
        contentView.addSubview(backButton)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.setScaledFont(17, weight: .bold, maximumSize: 24)
        titleLabel.textColor = goldColor
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isUserInteractionEnabled = true
        titleLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(titleTapped)))
        titleLabel.addInteraction(UIContextMenuInteraction(delegate: self))
        contentView.addSubview(titleLabel)

        titleButton.translatesAutoresizingMaskIntoConstraints = false
        titleButton.isHidden = true
        titleButton.addTarget(self, action: #selector(titleSheetTapped), for: .touchUpInside)
        titleButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleButton.addInteraction(UIContextMenuInteraction(delegate: self))
        contentView.addSubview(titleButton)

        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        actionsStack.axis = .horizontal
        actionsStack.spacing = 8
        actionsStack.alignment = .center
        contentView.addSubview(actionsStack)

        let widthConstraint = backButton.widthAnchor.constraint(equalToConstant: buttonSize)
        backButtonWidthConstraint = widthConstraint
        let backHeight = backButton.heightAnchor.constraint(equalToConstant: buttonSize)
        let actionsHeight = actionsStack.heightAnchor.constraint(equalToConstant: buttonSize)
        let titleHeight = titleLabel.heightAnchor.constraint(equalToConstant: barHeight)
        scaledConstraints = [(widthConstraint, 38), (backHeight, 38), (actionsHeight, 38), (titleHeight, 44)]

        titleLeadingConstraint = titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 40)
        titleTrailingConstraint = titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -40)

        // The title button is tied to the bar's own margins (same values as the hidden label, kept in sync in setActions),
        // not to the label - the label only measures its short text and used to squeeze the button.
        titleButtonLeading = titleButton.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 56)
        titleButtonTrailing = titleButton.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -56)

        NSLayoutConstraint.activate([
            backButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            backHeight,
            widthConstraint,

            actionsStack.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            actionsHeight,

            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleHeight,
            titleLeadingConstraint,
            titleTrailingConstraint,
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            titleButton.centerXAnchor.constraint(equalTo: titleLabel.centerXAnchor),
            titleButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            titleButtonLeading,
            titleButtonTrailing,
        ])
    }

    /// Actions that open a native menu (see NativeTopBarBridge.configure) and the callback for a picked item.
    static var menus: [String: [(id: String, title: String, on: Bool)]] = [:]
    var onMenuSelect: ((String, String) -> Void)?

    @objc private func tapTrailingAction(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        onTrailingAction?(id)
    }

    /// Rebuilt from scratch on every `configure()` call (cheap - at most 3
    /// buttons) rather than diffed, same as NativeSettingsView's table
    /// reload - there's no per-button state to preserve between screens.
    /// How many trailing action buttons are showing - the tools "…" button
    /// (MainViewController.layoutToolsFab) sits just past them in this row.
    private(set) var actionCount = 0
    var onActionsChanged: (() -> Void)?

    private var lastActions: [(id: String, icon: String, label: String)] = []
    private var lastIsRTL = true
    /// MainViewController re-reads `contentHeight` (header offset, tools FAB) when Dynamic Type changes.
    var onScaleChanged: (() -> Void)?

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        guard previous?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory else { return }
        for (c, base) in scaledConstraints { c.constant = A11y.scaled(base) }
        setActions(lastActions, isRTL: lastIsRTL)
        onScaleChanged?()
    }

    private func setActions(_ actions: [(id: String, icon: String, label: String)], isRTL: Bool) {
        lastActions = actions
        lastIsRTL = isRTL
        actionCount = actions.count
        defer { onActionsChanged?() }
        actionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for action in actions {
            let button = UIButton(type: .system)
            NativeTopBarView.glassCircle(button, symbol: action.icon, tint: goldColor)
            button.accessibilityIdentifier = action.id
            if !action.label.isEmpty { button.accessibilityLabel = action.label }
            button.widthAnchor.constraint(equalToConstant: buttonSize).isActive = true
            button.heightAnchor.constraint(equalToConstant: buttonSize).isActive = true
            button.accessibilityTraits = .button
            if let items = NativeTopBarView.menus[action.id], !items.isEmpty {
                let aid = action.id
                button.menu = UIMenu(children: items.map { item in
                    UIAction(title: item.title, state: item.on ? .on : .off) { [weak self] _ in self?.onMenuSelect?(aid, item.id) }
                })
                button.showsMenuAsPrimaryAction = true
            } else {
                button.addTarget(self, action: #selector(tapTrailingAction(_:)), for: .touchUpInside)
            }
            actionsStack.addArrangedSubview(button)
        }
        actionsLeading(isRTL: isRTL)
        // The title's own side margins need to clear whichever side the
        // actions stack ends up on, or a 2-3 icon row would overlap a
        // long title instead of the title just truncating around it.
        // + room for the tools "…" button that can sit past the actions
        let actionSideMargin: CGFloat = CGFloat(66 + actions.count * 46) + buttonSize - 38
        titleLeadingConstraint.constant = isRTL ? 56 : actionSideMargin
        titleTrailingConstraint.constant = isRTL ? -actionSideMargin : -56
        titleButtonLeading.constant = titleLeadingConstraint.constant
        titleButtonTrailing.constant = titleTrailingConstraint.constant
    }

    private var actionsLeadingConstraint: NSLayoutConstraint?
    private var actionsTrailingConstraint: NSLayoutConstraint?

    /// Mirrors `backLeading(isRTL:)` below, placed on the opposite side
    /// from the back button - the same side the HTML `rightHtml` content
    /// renders on in `topbar()`.
    private func actionsLeading(isRTL: Bool) {
        actionsLeadingConstraint?.isActive = false
        actionsTrailingConstraint?.isActive = false
        if isRTL {
            let c = actionsStack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 14)
            c.isActive = true
            actionsLeadingConstraint = c
        } else {
            let c = actionsStack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -14)
            c.isActive = true
            actionsTrailingConstraint = c
        }
    }

    @objc private func tapBack() { onBack?() }

    /// `isRTL` picks the chevron direction explicitly (matching the web
    /// app's own I.prev getter, which flips by document direction) rather
    /// than relying on automatic UIKit mirroring, since the app's RTL
    /// state is driven by its own language setting, not the device's.
    private var quickActionLabels: (home: String, settings: String, share: String) = (A11y.t("home"), A11y.t("settings"), A11y.t("share"))

    func configure(title: String, hasBack: Bool, isRTL: Bool, homeLabel: String, settingsLabel: String, shareLabel: String, actions: [(id: String, icon: String, label: String)]) {
        titleLabel.text = title
        updateTitleButton(title: title, isRTL: isRTL)
        backButton.isHidden = !hasBack
        let symbol = isRTL ? "chevron.right" : "chevron.left"
        NativeTopBarView.glassCircle(backButton, symbol: symbol, tint: goldColor)
        backButton.accessibilityLabel = A11y.t("back")
        if !homeLabel.isEmpty { quickActionLabels.home = homeLabel }
        if !settingsLabel.isEmpty { quickActionLabels.settings = settingsLabel }
        if !shareLabel.isEmpty { quickActionLabels.share = shareLabel }
        // Always keep a valid horizontal constraint active, even when
        // hidden, so Auto Layout never has an ambiguous/unconstrained
        // backButton frame.
        backLeading(isRTL: isRTL)
        setActions(actions, isRTL: isRTL)
    }

    /// Real Liquid Glass capsule on iOS 26 (plain blur capsule before that) holding "title v"; only visible when a titleSheet exists.
    private func updateTitleButton(title: String, isRTL: Bool) {
        let has = NativeTopBarView.titleSheet != nil
        titleButton.isHidden = !has
        titleLabel.isHidden = has
        guard has else { return }
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = UIButton.Configuration.glass()
        } else {
            config = UIButton.Configuration.filled()
            config.background.visualEffect = UIBlurEffect(style: .systemThinMaterial)
            config.baseBackgroundColor = .clear
        }
        config.cornerStyle = .capsule
        config.baseForegroundColor = goldColor
        config.titleLineBreakMode = .byTruncatingTail
        titleButtonText = title
        titleButtonSize = 0
        var attrs = AttributeContainer()
        attrs.font = UIFont.systemFont(ofSize: A11y.scaled(18), weight: .bold)
        config.attributedTitle = AttributedString(title, attributes: attrs)
        config.image = UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: A11y.scaled(12), weight: .bold))
        config.imagePlacement = .trailing
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 16)
        titleButton.configuration = config
        setNeedsLayout()
        titleButton.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        titleButton.accessibilityLabel = title
        titleButton.accessibilityTraits = .button
    }

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    private func backLeading(isRTL: Bool) {
        leadingConstraint?.isActive = false
        trailingConstraint?.isActive = false
        if isRTL {
            let c = backButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -14)
            c.isActive = true
            trailingConstraint = c
        } else {
            let c = backButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 14)
            c.isActive = true
            leadingConstraint = c
        }
    }
}

extension NativeTopBarView: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self = self else { return nil }
            let home = UIAction(title: self.quickActionLabels.home, image: UIImage(systemName: "house.fill")) { _ in
                self.onQuickAction?("home")
            }
            let settings = UIAction(title: self.quickActionLabels.settings, image: UIImage(systemName: "gearshape.fill")) { _ in
                self.onQuickAction?("settings")
            }
            let share = UIAction(title: self.quickActionLabels.share, image: UIImage(systemName: "square.and.arrow.up")) { _ in
                self.onQuickAction?("share")
            }
            return UIMenu(title: "", children: [home, settings, share])
        }
    }
}


// MARK: - Title picker sheet

struct TitleSheetItem { let id: String; let title: String; let on: Bool }

/// What the Chok reader's title button shows: a swipeable row of days and wrapping category chips.
/// A pick is reported back as (actionId, itemId) - the same `NativeTopBarHost.onMenu` path the round menu buttons used.
struct TitleSheetSpec {
    let daysTitle: String
    let secsTitle: String
    let daysAction: String
    let secsAction: String
    let days: [TitleSheetItem]
    let secs: [TitleSheetItem]
    var isRTL = true
    var isDark = false
}

/// Lays chips out in wrapping rows (RTL-aware); its height follows the width it is given.
final class ChipWrapView: UIView {
    var rtl = true
    var spacing: CGFloat = 8
    private var heightConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        heightConstraint = heightAnchor.constraint(equalToConstant: 10)
        heightConstraint?.isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        guard width > 0 else { return }
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let sz = v.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            let w = min(sz.width, width)
            if x > 0 && x + w > width { x = 0; y += rowH + spacing; rowH = 0 }
            let fx = rtl ? width - x - w : x
            v.frame = CGRect(x: fx, y: y, width: w, height: sz.height)
            x += w + spacing
            rowH = max(rowH, sz.height)
        }
        let total = y + rowH
        if abs((heightConstraint?.constant ?? 0) - total) > 0.5 { heightConstraint?.constant = total }
    }
}

final class TitleSheetViewController: UIViewController {
    static let refreshNotification = Notification.Name("BetElTitleSheetRefresh")
    private var spec: TitleSheetSpec
    private let onPick: (String, String) -> Void
    private let daysScroll = UIScrollView()
    private var selectedDayChip: UIView?

    init(spec: TitleSheetSpec, onPick: @escaping (String, String) -> Void) {
        self.spec = spec
        self.onPick = onPick
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func chip(_ item: TitleSheetItem, action: String) -> UIButton {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = item.on ? UIButton.Configuration.prominentGlass() : UIButton.Configuration.glass()
        } else {
            config = item.on ? UIButton.Configuration.filled() : UIButton.Configuration.tinted()
        }
        config.cornerStyle = .capsule
        if item.on {
            // Selected = the app's gold with dark text (not system blue).
            config.baseBackgroundColor = UIColor.betelGold
            config.baseForegroundColor = UIColor(red: 0.051, green: 0.078, blue: 0.165, alpha: 1)
            config.background.visualEffect = nil
        } else {
            config.baseForegroundColor = UIColor.betelGold
        }
        config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16)
        var attrs = AttributeContainer()
        attrs.font = UIFont.systemFont(ofSize: A11y.scaled(15), weight: item.on ? .bold : .semibold)
        config.attributedTitle = AttributedString(item.title, attributes: attrs)
        let b = UIButton(configuration: config)
        b.semanticContentAttribute = spec.isRTL ? .forceRightToLeft : .forceLeftToRight
        b.accessibilityTraits = item.on ? [.button, .selected] : .button
        b.addAction(UIAction { [weak self] _ in
            self?.onPick(action, item.id)   // sheet stays open; JS re-sends titleSheet and we refresh
        }, for: .touchUpInside)
        return b
    }

    private func heading(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.systemFont(ofSize: A11y.scaled(13), weight: .semibold)
        l.textColor = .secondaryLabel
        l.textAlignment = spec.isRTL ? .right : .left
        l.semanticContentAttribute = spec.isRTL ? .forceRightToLeft : .forceLeftToRight
        return l
    }

    private var outerScroll: UIScrollView?

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshFromJS), name: TitleSheetViewController.refreshNotification, object: nil)
        buildContent()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    /// JS re-sent `titleSheet` (after a pick): rebuild the chips in place so the selection moves, keep scroll positions.
    @objc private func refreshFromJS() {
        guard let newSpec = NativeTopBarView.titleSheet else { return }
        let dayX = daysScroll.contentOffset.x
        let outerY = outerScroll?.contentOffset.y ?? 0
        spec = newSpec
        view.subviews.forEach { $0.removeFromSuperview() }
        daysScroll.subviews.forEach { $0.removeFromSuperview() }
        selectedDayChip = nil
        buildContent()
        view.layoutIfNeeded()
        daysScroll.contentOffset = CGPoint(x: dayX, y: 0)
        outerScroll?.contentOffset = CGPoint(x: 0, y: outerY)
    }

    private func buildContent() {
        overrideUserInterfaceStyle = spec.isDark ? .dark : .light
        view.backgroundColor = NativeTopBarView.background(isDark: spec.isDark)
        view.semanticContentAttribute = spec.isRTL ? .forceRightToLeft : .forceLeftToRight

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        outerScroll = scroll
        view.addSubview(scroll)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        // Days: one horizontally swipeable row, no arrows.
        daysScroll.showsHorizontalScrollIndicator = false
        daysScroll.translatesAutoresizingMaskIntoConstraints = false
        let daysStack = UIStackView()
        daysStack.axis = .horizontal
        daysStack.spacing = 8
        daysStack.semanticContentAttribute = spec.isRTL ? .forceRightToLeft : .forceLeftToRight
        daysStack.translatesAutoresizingMaskIntoConstraints = false
        daysScroll.addSubview(daysStack)
        for d in spec.days {
            let c = chip(d, action: spec.daysAction)
            if d.on { selectedDayChip = c }
            daysStack.addArrangedSubview(c)
        }
        NSLayoutConstraint.activate([
            daysStack.leadingAnchor.constraint(equalTo: daysScroll.contentLayoutGuide.leadingAnchor, constant: 20),
            daysStack.trailingAnchor.constraint(equalTo: daysScroll.contentLayoutGuide.trailingAnchor, constant: -20),
            daysStack.topAnchor.constraint(equalTo: daysScroll.contentLayoutGuide.topAnchor),
            daysStack.bottomAnchor.constraint(equalTo: daysScroll.contentLayoutGuide.bottomAnchor),
            daysStack.heightAnchor.constraint(equalTo: daysScroll.frameLayoutGuide.heightAnchor),
            daysScroll.heightAnchor.constraint(equalToConstant: A11y.scaled(44)),
        ])

        // Categories: wrapping rows.
        let wrap = ChipWrapView()
        wrap.rtl = spec.isRTL
        wrap.translatesAutoresizingMaskIntoConstraints = false
        for s in spec.secs { wrap.addSubview(chip(s, action: spec.secsAction)) }

        func padded(_ v: UIView) -> UIView {
            let box = UIView()
            v.translatesAutoresizingMaskIntoConstraints = false
            box.addSubview(v)
            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 20),
                v.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -20),
                v.topAnchor.constraint(equalTo: box.topAnchor),
                v.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            ])
            return box
        }
        stack.addArrangedSubview(padded(heading(spec.daysTitle)))
        stack.addArrangedSubview(daysScroll)
        stack.setCustomSpacing(24, after: daysScroll)
        stack.addArrangedSubview(padded(heading(spec.secsTitle)))
        stack.addArrangedSubview(padded(wrap))

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Bring the selected day to the middle of the row.
        guard let chip = selectedDayChip, daysScroll.bounds.width > 0 else { return }
        let target = chip.convert(chip.bounds, to: daysScroll)
        let maxX = max(0, daysScroll.contentSize.width - daysScroll.bounds.width)
        let x = min(max(0, target.midX - daysScroll.bounds.width / 2), maxX)
        if abs(daysScroll.contentOffset.x - x) > 1 && !didCenter { daysScroll.contentOffset = CGPoint(x: x, y: 0) }
        if daysScroll.contentSize.width > 0 { didCenter = true }
    }
    private var didCenter = false
}
