import UIKit

/// A real native floating action button + expandable panel, rendered with
/// iOS 26's genuine Liquid Glass material (`UIGlassEffect`) - not a CSS
/// `backdrop-filter` approximation - mirroring the web app's own
/// `.reader-tools`/`.rt-fab`/`.rt-panel` controls (font size, theme toggle,
/// optional autoscroll, home).
///
/// Anchored as a FIXED floating button in the bottom-right corner (above the
/// native tab bar) rather than inline in each screen's header the way the
/// HTML version is: a web-driven exact-position mirror would need constant
/// frame syncing on every scroll/resize/rotation, while a fixed corner FAB
/// is both simpler and a more natural native iOS pattern (as used by many
/// first-party apps).
///
/// REQUIRES BUILDING WITH THE iOS 26 SDK (Xcode 26+) - `UIGlassEffect` is a
/// compile-time symbol only present in that SDK. The `#available` checks
/// below only gate RUNTIME behavior (falling back to a plain blur on older
/// devices); they do nothing for the SDK/Xcode version used to build this
/// file. Building with an older Xcode will fail to compile this file.
final class NativeToolsFabView: UIView {
    enum Action { case minus, plus, theme, autoscroll, home }

    var onAction: ((Action) -> Void)?

    private let fabSize: CGFloat = 46
    private let goldColor = UIColor(red: 0.831, green: 0.686, blue: 0.373, alpha: 1)

    private var panelContainer: UIView?
    private var isExpanded = false

    private var showAutoscroll = false
    private var fontScalePercent = 100
    private var isDarkTheme = false
    private var isAutoscrollActive = false

    private var fontLabel: UILabel?
    private var themeButton: UIButton?
    private var autoscrollButton: UIButton?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupFab()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func glassView(cornerRadius: CGFloat) -> UIView {
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect()
            effect.isInteractive = true
            let v = UIVisualEffectView(effect: effect)
            v.layer.cornerRadius = cornerRadius
            v.clipsToBounds = true
            return v
        } else {
            let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            v.layer.cornerRadius = cornerRadius
            v.clipsToBounds = true
            return v
        }
    }

    private func setupFab() {
        let glass = glassView(cornerRadius: fabSize / 2)
        glass.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)
        NSLayoutConstraint.activate([
            glass.widthAnchor.constraint(equalToConstant: fabSize),
            glass.heightAnchor.constraint(equalToConstant: fabSize),
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        let fabButton = UIButton(type: .system)
        fabButton.translatesAutoresizingMaskIntoConstraints = false
        fabButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        fabButton.tintColor = goldColor
        fabButton.addTarget(self, action: #selector(toggleExpanded), for: .touchUpInside)

        let contentView: UIView = (glass as? UIVisualEffectView)?.contentView ?? glass
        contentView.addSubview(fabButton)
        NSLayoutConstraint.activate([
            fabButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            fabButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            fabButton.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            fabButton.heightAnchor.constraint(equalTo: contentView.heightAnchor),
        ])
    }

    @objc private func toggleExpanded() {
        if isExpanded { collapsePanel() } else { expandPanel() }
    }

    private func iconButton(systemName: String, action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(systemName: systemName), for: .normal)
        b.tintColor = goldColor
        b.widthAnchor.constraint(equalToConstant: 36).isActive = true
        b.heightAnchor.constraint(equalToConstant: 36).isActive = true
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func expandPanel() {
        guard panelContainer == nil, let superview = self.superview else { return }
        isExpanded = true

        // Explicit width (rather than letting the stack size the panel
        // intrinsically) to avoid any Auto Layout ambiguity between the
        // panel's own constraints and its content's.
        let panelWidth: CGFloat = showAutoscroll ? 240 : 200
        let panelHeight: CGFloat = 46

        let panel = glassView(cornerRadius: panelHeight / 2)
        panel.translatesAutoresizingMaskIntoConstraints = false
        superview.insertSubview(panel, belowSubview: self)
        panelContainer = panel
        NSLayoutConstraint.activate([
            panel.trailingAnchor.constraint(equalTo: trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: topAnchor, constant: -10),
            panel.widthAnchor.constraint(equalToConstant: panelWidth),
            panel.heightAnchor.constraint(equalToConstant: panelHeight),
        ])

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 2
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let minusBtn = iconButton(systemName: "minus", action: #selector(tapMinus))

        let fsLabel = UILabel()
        fsLabel.translatesAutoresizingMaskIntoConstraints = false
        fsLabel.text = "\(fontScalePercent)"
        fsLabel.font = .systemFont(ofSize: 13, weight: .bold)
        fsLabel.textColor = UIColor(white: 0.5, alpha: 1)
        fsLabel.textAlignment = .center
        fsLabel.widthAnchor.constraint(equalToConstant: 30).isActive = true
        fontLabel = fsLabel

        let plusBtn = iconButton(systemName: "plus", action: #selector(tapPlus))

        let sep = UIView()
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.backgroundColor = UIColor(white: 0.5, alpha: 0.3)
        sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
        sep.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let themeBtn = iconButton(systemName: isDarkTheme ? "sun.max.fill" : "moon.fill", action: #selector(tapTheme))
        themeButton = themeBtn

        stack.addArrangedSubview(minusBtn)
        stack.addArrangedSubview(fsLabel)
        stack.addArrangedSubview(plusBtn)
        stack.addArrangedSubview(sep)
        stack.addArrangedSubview(themeBtn)

        if showAutoscroll {
            let asBtn = iconButton(systemName: isAutoscrollActive ? "pause.fill" : "play.fill", action: #selector(tapAutoscroll))
            autoscrollButton = asBtn
            stack.addArrangedSubview(asBtn)
        }

        let homeBtn = iconButton(systemName: "house.fill", action: #selector(tapHome))
        stack.addArrangedSubview(homeBtn)

        let contentView: UIView = (panel as? UIVisualEffectView)?.contentView ?? panel
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])

        panel.alpha = 0
        panel.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        UIView.animate(
            withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.4,
            options: [], animations: {
                panel.alpha = 1
                panel.transform = .identity
            }
        )
    }

    private func collapsePanel() {
        isExpanded = false
        guard let panel = panelContainer else { return }
        panelContainer = nil
        fontLabel = nil
        themeButton = nil
        autoscrollButton = nil
        UIView.animate(
            withDuration: 0.2,
            animations: {
                panel.alpha = 0
                panel.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            },
            completion: { _ in panel.removeFromSuperview() }
        )
    }

    @objc private func tapMinus() { onAction?(.minus) }
    @objc private func tapPlus() { onAction?(.plus) }
    @objc private func tapTheme() { onAction?(.theme) }
    @objc private func tapAutoscroll() { onAction?(.autoscroll) }
    @objc private func tapHome() { onAction?(.home); collapsePanel() }

    // MARK: - State from JS

    func configure(showAutoscroll: Bool) {
        self.showAutoscroll = showAutoscroll
        if isExpanded { collapsePanel() }
    }

    func setState(fontScalePercent: Int, isDarkTheme: Bool, isAutoscrollActive: Bool) {
        self.fontScalePercent = fontScalePercent
        self.isDarkTheme = isDarkTheme
        self.isAutoscrollActive = isAutoscrollActive
        fontLabel?.text = "\(fontScalePercent)"
        themeButton?.setImage(UIImage(systemName: isDarkTheme ? "sun.max.fill" : "moon.fill"), for: .normal)
        autoscrollButton?.setImage(UIImage(systemName: isAutoscrollActive ? "pause.fill" : "play.fill"), for: .normal)
    }

    /// Collapses the expanded panel (e.g. when the screen navigates away or
    /// the FAB is hidden), matching the HTML version's "tap elsewhere
    /// closes the panel" behavior.
    func collapseIfExpanded() {
        if isExpanded { collapsePanel() }
    }
}
