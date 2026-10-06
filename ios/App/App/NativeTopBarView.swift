import UIKit

/// A real native floating header bar, rendered with iOS 26's genuine
/// Liquid Glass material (`UIGlassEffect`) - not a CSS `backdrop-filter`
/// approximation - mirroring the web app's shared `topbar(title, backTo,
/// rightHtml)` HTML header (back-or-logo on one side, a centered title).
///
/// Only the plain case is modeled here: a title and an optional back
/// button. Screens with custom right-side actions (share/QR, the inline
/// tools FAB) keep their own HTML header - see index.html's
/// `tb-native-exempt` class and `hideNativeTopBar()`.
///
/// REQUIRES BUILDING WITH THE iOS 26 SDK (Xcode 26+) - see
/// NativeToolsFabView's header comment for why; the same applies here.
final class NativeTopBarView: UIView {
    var onBack: (() -> Void)?

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

    private let goldColor = UIColor(red: 0.831, green: 0.686, blue: 0.373, alpha: 1)
    private let barHeight: CGFloat = 44

    private let titleLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private var backButtonWidthConstraint: NSLayoutConstraint?

    /// The bar's own height below the safe-area top inset - used by
    /// MainViewController to report --native-header-h to the web view.
    var contentHeight: CGFloat { barHeight }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBar()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupBar() {
        let glass: UIView
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect()
            let v = UIVisualEffectView(effect: effect)
            glass = v
        } else {
            glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        }
        glass.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let contentView: UIView = (glass as? UIVisualEffectView)?.contentView ?? glass

        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.tintColor = goldColor
        backButton.addTarget(self, action: #selector(tapBack), for: .touchUpInside)
        contentView.addSubview(backButton)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = goldColor
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isUserInteractionEnabled = true
        titleLabel.addInteraction(UIContextMenuInteraction(delegate: self))
        contentView.addSubview(titleLabel)

        let widthConstraint = backButton.widthAnchor.constraint(equalToConstant: 34)
        backButtonWidthConstraint = widthConstraint

        NSLayoutConstraint.activate([
            backButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            backButton.heightAnchor.constraint(equalToConstant: barHeight),
            widthConstraint,

            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: barHeight),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -40),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    @objc private func tapBack() { onBack?() }

    /// `isRTL` picks the chevron direction explicitly (matching the web
    /// app's own I.prev getter, which flips by document direction) rather
    /// than relying on automatic UIKit mirroring, since the app's RTL
    /// state is driven by its own language setting, not the device's.
    private var quickActionLabels: (home: String, settings: String, share: String) = ("Home", "Settings", "Share")

    func configure(title: String, hasBack: Bool, isRTL: Bool, homeLabel: String, settingsLabel: String, shareLabel: String) {
        titleLabel.text = title
        backButton.isHidden = !hasBack
        let symbol = isRTL ? "chevron.right" : "chevron.left"
        backButton.setImage(UIImage(systemName: symbol), for: .normal)
        if !homeLabel.isEmpty { quickActionLabels.home = homeLabel }
        if !settingsLabel.isEmpty { quickActionLabels.settings = settingsLabel }
        if !shareLabel.isEmpty { quickActionLabels.share = shareLabel }
        // Always keep a valid horizontal constraint active, even when
        // hidden, so Auto Layout never has an ambiguous/unconstrained
        // backButton frame.
        backLeading(isRTL: isRTL)
    }

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    private func backLeading(isRTL: Bool) {
        leadingConstraint?.isActive = false
        trailingConstraint?.isActive = false
        if isRTL {
            let c = backButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -8)
            c.isActive = true
            trailingConstraint = c
        } else {
            let c = backButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 8)
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
