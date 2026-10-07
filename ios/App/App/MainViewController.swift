import UIKit
import WebKit
import Capacitor

/// Replaces the plain `CAPBridgeViewController` as the app's root view
/// controller so the bottom navigation can be a REAL native `UITabBar`
/// instead of HTML/CSS - CSS `backdrop-filter` can only ever approximate
/// the look of iOS 26's Liquid Glass material, but a genuine `UITabBar`
/// gets the real thing automatically from the OS with zero extra styling
/// code, because it's a native system-rendered material, not something a
/// web view can reach at all.
///
/// `CAPBridgeViewController.loadView()` sets `self.view` to the WKWebView
/// itself (see node_modules/@capacitor/ios's own source), so this simply
/// adds the tab bar as a subview of that webview, pinned to the bottom -
/// no container view controller or child-VC embedding needed, since we
/// aren't swapping between separate screens the way UITabBarController
/// does: every tap just tells the *same* web view (via `window.go(tab)`)
/// to switch screens itself, the same way the HTML nav already did.
///
/// The web app (index.html) hides its own HTML `.bottom-nav` and adds
/// matching bottom padding whenever this bridge is present - see
/// `syncNativeTabBar()` in index.html - so the two never show at once.
class MainViewController: CAPBridgeViewController {
    private let tabBar = UITabBar()
    private let toolsFab = NativeToolsFabView()
    private let topBar = NativeTopBarView()
    private let modal = NativeModalView()
    private let feedbackForm = NativeFeedbackFormView()
    private let toastView = NativeToastView()
    let homeEditOverlay = HomeEditOverlay()
    private let scrollTopCatcher = ScrollTopCatcher()
    private let settingsView = NativeSettingsView()
    /// The app's own language direction (S.lang), from the last tab bar
    /// configure() - also used to place the tools FAB on the matching side.
    private var isRTL = true
    /// Apple Music-style minimized tab bar: while scrolling down the full
    /// bar shrinks away into this small glass circle showing the current
    /// tab's icon (instead of disappearing entirely); tapping it expands
    /// the full bar again.
    private let miniTabButton = UIButton(type: .system)
    private var miniSideConstraint: NSLayoutConstraint?
    private var isTabBarMinimized = false

    /// (id, SF Symbol name) - the label text itself comes from JS via
    /// `configure(items:)` below, since the web app is the single source
    /// of truth for the current UI language (S.lang) and already has a
    /// full translation dictionary; duplicating that into Swift would be
    /// one more place for the two to drift out of sync.
    static let tabOrder: [(id: String, icon: String)] = [
        ("home", "house.fill"),
        ("tehillim", "book.closed.fill"),
        ("prayers", "books.vertical.fill"),
        ("calendar", "calendar"),
        ("settings", "gearshape.fill"),
        // Not a screen of its own - selecting it opens the Library search
        // (window.NativeSearchHost) and the bar re-selects the real tab.
        ("search", "magnifyingglass"),
    ]

    /// Capacitor 8 only auto-registers plugins listed in the generated
    /// capacitor.config.json's `packageClassList`, which `npx cap sync`
    /// fills from npm packages alone - plugins compiled into the app target
    /// itself are never discovered, so every one of them must be registered
    /// here explicitly. Without this, the JS-side `registerPlugin()` calls in
    /// capacitor-native-bridge.js still create `window.Capacitor.Plugins.X`
    /// proxies (so index.html hides its HTML nav/FAB/etc. in favor of the
    /// native ones), but every call into them rejects as unimplemented and
    /// no native UI ever appears.
    /// Tells the web app whether this is a development install, before any
    /// page script runs: there is no App Store/TestFlight receipt on a build
    /// installed straight from Xcode (Debug or Release) or on the simulator.
    /// index.html uses `window.__BETEL_DEV_BUILD` to keep such installs out
    /// of the Firebase visit counter, live presence and Analytics, so
    /// repeated test installs don't inflate the real user numbers.
    override func webViewConfiguration(for instanceConfiguration: InstanceConfiguration) -> WKWebViewConfiguration {
        let configuration = super.webViewConfiguration(for: instanceConfiguration)
        let hasReceipt = Bundle.main.appStoreReceiptURL
            .map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let script = WKUserScript(
            source: "window.__BETEL_DEV_BUILD = \(hasReceipt ? "false" : "true");",
            injectionTime: .atDocumentStart, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(script)
        return configuration
    }

    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(NativeTabBarBridge())
        bridge?.registerPluginInstance(NativeToolsFabBridge())
        bridge?.registerPluginInstance(NativeTopBarBridge())
        bridge?.registerPluginInstance(NativeModalBridge())
        bridge?.registerPluginInstance(NativeSettingsBridge())
        bridge?.registerPluginInstance(NativeToastBridge())
        bridge?.registerPluginInstance(NativeHomeEditBridge())
        bridge?.registerPluginInstance(NativeHapticsBridge())
        bridge?.registerPluginInstance(BetElWidgetBridge())
        bridge?.registerPluginInstance(NativeLiveActivityBridge())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        setupToolsFab()
        setupTopBar()
        setupModal()
        setupFeedbackForm()
        setupToast()
        setupHomeEdit()
        setupScrollToTop()
        setupSettingsView()
        layoutToolsFab()
        topBar.onActionsChanged = { [weak self] in self?.layoutToolsFab() }
        NativeTabBarBridge.activeController = self
        NativeToolsFabBridge.activeController = self
        NativeTopBarBridge.activeController = self
        NativeModalBridge.activeController = self
        NativeToastBridge.activeController = self
        NativeHomeEditBridge.activeController = self
        NativeSettingsBridge.activeController = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        reportHeightToWebView()
    }

    private func setupTabBar() {
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.delegate = self
        tabBar.isHidden = true // hidden until JS calls configure() with real labels, so an unlabeled bar never flashes on launch
        // No explicit appearance/material setup on purpose - iOS 26's
        // default UITabBar appearance already IS the floating Liquid
        // Glass capsule; overriding `standardAppearance`/
        // `scrollEdgeAppearance` here would replace that system material
        // with a manually-drawn one instead of the genuine thing.
        view.addSubview(tabBar)
        NSLayoutConstraint.activate([
            tabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        NSLayoutConstraint.activate([
            tabBar.leftAnchor.constraint(equalTo: view.leftAnchor),
            tabBar.rightAnchor.constraint(equalTo: view.rightAnchor),
        ])
        tabBar.tintColor = MainViewController.tabTint
        setupMiniTabButton()
    }

    private func setupMiniTabButton() {
        miniTabButton.translatesAutoresizingMaskIntoConstraints = false
        miniTabButton.alpha = 0
        miniTabButton.isHidden = true
        miniTabButton.accessibilityLabel = "Show tab bar"
        miniTabButton.addTarget(self, action: #selector(miniTabTapped), for: .touchUpInside)
        view.addSubview(miniTabButton)
        NSLayoutConstraint.activate([
            miniTabButton.widthAnchor.constraint(equalToConstant: 56),
            miniTabButton.heightAnchor.constraint(equalToConstant: 56),
            miniTabButton.centerYAnchor.constraint(equalTo: tabBar.safeAreaLayoutGuide.centerYAnchor),
        ])
        layoutMiniTabButton()
    }

    /// Reading-direction start edge, like Apple Music's minimized bar
    /// (left in LTR languages, right in Hebrew).
    private func layoutMiniTabButton() {
        miniSideConstraint?.isActive = false
        let guide = view.safeAreaLayoutGuide
        miniSideConstraint = isRTL
            ? miniTabButton.rightAnchor.constraint(equalTo: guide.rightAnchor, constant: -20)
            : miniTabButton.leftAnchor.constraint(equalTo: guide.leftAnchor, constant: 20)
        miniSideConstraint?.isActive = true
    }

    /// The app's own emblem (the bundled web icon, public/icon-192.png),
    /// clipped to a circle - shown in the minimized tab bar instead of the
    /// last-tapped tab's icon, by user request. Falls back to a fixed
    /// symbol if the file isn't there for some reason.
    private static let appLogo: UIImage? = {
        guard let path = Bundle.main.path(forResource: "icon-192", ofType: "png", inDirectory: "public"),
              let src = UIImage(contentsOfFile: path) else { return nil }
        let size = CGSize(width: 40, height: 40)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
            src.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysOriginal)
    }()

    private func refreshMiniTabIcon() {
        let image = MainViewController.appLogo
            ?? UIImage(systemName: "house.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold))
        if #available(iOS 26.0, *) {
            var config = UIButton.Configuration.glass()
            config.image = image
            config.cornerStyle = .capsule
            config.baseForegroundColor = MainViewController.tabTint
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            miniTabButton.configuration = config
        } else {
            var config = UIButton.Configuration.filled()
            config.image = image
            config.cornerStyle = .capsule
            config.background.visualEffect = UIBlurEffect(style: .systemMaterial)
            config.baseBackgroundColor = .clear
            config.baseForegroundColor = MainViewController.tabTint
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            miniTabButton.configuration = config
        }
    }

    @objc private func miniTabTapped() {
        UISelectionFeedbackGenerator().selectionChanged()
        setHidden(false)
    }

    /// Pinned to the bottom-right corner, above the tab bar (whether or not
    /// the tab bar is currently visible - see the floating offset below) -
    /// see NativeToolsFabView's own header comment for why this is a fixed
    /// corner position rather than an exact mirror of the HTML version's
    /// inline header placement.
    private func setupToolsFab() {
        toolsFab.translatesAutoresizingMaskIntoConstraints = false
        toolsFab.isHidden = true
        toolsFab.onAction = { [weak self] action in
            guard let self = self else { return }
            let js: String
            switch action {
            case .minus: js = "window.NativeToolsFabHost && window.NativeToolsFabHost.minus()"
            case .plus: js = "window.NativeToolsFabHost && window.NativeToolsFabHost.plus()"
            case .theme: js = "window.NativeToolsFabHost && window.NativeToolsFabHost.theme()"
            case .autoscroll: js = "window.NativeToolsFabHost && window.NativeToolsFabHost.autoscroll()"
            case .home: js = "window.go && window.go('home')"
            }
            self.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
        view.addSubview(toolsFab)
        NSLayoutConstraint.activate([
            toolsFab.widthAnchor.constraint(equalToConstant: 38),
            toolsFab.heightAnchor.constraint(equalToConstant: 38),
        ])
        // Tapping anywhere outside the FAB/its open panel closes the panel.
        // cancelsTouchesInView=false so the tap still reaches the web view.
        let outsideTap = UITapGestureRecognizer(target: self, action: #selector(handleOutsideTap(_:)))
        outsideTap.cancelsTouchesInView = false
        outsideTap.delegate = self
        view.addGestureRecognizer(outsideTap)
    }

    private var toolsFabSideConstraints: [NSLayoutConstraint] = []

    /// Inside the header row itself, as one more glass circle on the side
    /// the header's own actions use (left in Hebrew, right otherwise), just
    /// past any actions already there - never floating over the reading
    /// text. The panel opens downward from it (NativeToolsFabView.expandPanel).
    private func layoutToolsFab() {
        guard toolsFab.superview != nil, topBar.superview != nil else { return }
        NSLayoutConstraint.deactivate(toolsFabSideConstraints)
        let guide = view.safeAreaLayoutGuide
        let inset = 14 + CGFloat(topBar.actionCount) * 46
        toolsFabSideConstraints = [
            toolsFab.centerYAnchor.constraint(equalTo: guide.topAnchor, constant: topBar.contentHeight / 2),
            isRTL
                ? toolsFab.leftAnchor.constraint(equalTo: guide.leftAnchor, constant: inset)
                : toolsFab.rightAnchor.constraint(equalTo: guide.rightAnchor, constant: -inset),
        ]
        NSLayoutConstraint.activate(toolsFabSideConstraints)
        toolsFab.isRTL = isRTL
        // The header view spans the full width and is added later, so it
        // would otherwise swallow taps meant for the button sitting in it.
        view.bringSubviewToFront(toolsFab)
    }

    @objc private func handleOutsideTap(_ gesture: UITapGestureRecognizer) {
        toolsFab.collapseIfExpanded()
    }

    // MARK: - Called by NativeToolsFabBridge (JS-driven)

    func configureToolsFab(showAutoscroll: Bool) {
        toolsFab.configure(showAutoscroll: showAutoscroll)
    }

    func setToolsFabState(fontScalePercent: Int, isDarkTheme: Bool, isAutoscrollActive: Bool) {
        toolsFab.setState(fontScalePercent: fontScalePercent, isDarkTheme: isDarkTheme, isAutoscrollActive: isAutoscrollActive)
    }

    func setToolsFabVisible(_ visible: Bool) {
        if !visible { toolsFab.collapseIfExpanded() }
        toolsFab.isHidden = !visible
    }

    /// Spans the full width and extends up through the status bar (like the
    /// HTML .topbar's own backdrop does), with its interactive content kept
    /// inside the safe area by NativeTopBarView's own constraints.
    private func setupTopBar() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.isHidden = true
        // onBack is replaced on every configureTopBar() call below with a
        // closure bound to that call's own backTo target.
        view.addSubview(topBar)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: topBar.contentHeight),
        ])
    }

    // MARK: - Called by NativeTopBarBridge (JS-driven)

    func configureTopBar(title: String, hasBack: Bool, isRTL: Bool, isDark: Bool, homeLabel: String, settingsLabel: String, shareLabel: String, actions: [(id: String, icon: String, label: String)]) {
        topBar.setTheme(isDark: isDark)
        topBar.configure(title: title, hasBack: hasBack, isRTL: isRTL, homeLabel: homeLabel, settingsLabel: settingsLabel, shareLabel: shareLabel, actions: actions)
        // Both relay to one fixed JS entry point each rather than this
        // method trying to encode what "back" or a given action id means -
        // JS (TOPBAR_BACK_ACTION/TOPBAR_ACTION_HANDLERS in index.html)
        // owns that, since it can be more than a plain `go(tab)` call and
        // the same action id means different things on different screens.
        topBar.onBack = { [weak self] in
            self?.webView?.evaluateJavaScript("window.NativeTopBarHost && window.NativeTopBarHost.onBack()", completionHandler: nil)
        }
        topBar.onTrailingAction = { [weak self] id in
            self?.webView?.evaluateJavaScript("window.NativeTopBarHost && window.NativeTopBarHost.onAction(\(self?.jsStringLiteral(id) ?? "null"))", completionHandler: nil)
        }
        topBar.onQuickAction = { [weak self] action in
            guard let self = self else { return }
            let js: String
            switch action {
            case "home": js = "window.go && window.go('home')"
            case "settings": js = "window.go && window.go('settings')"
            case "share": js = "window.shareApp && window.shareApp()"
            default: return
            }
            self.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
        topBar.isHidden = false
        reportHeightToWebView()
    }

    func setTopBarVisible(_ visible: Bool) {
        topBar.isHidden = !visible
        reportHeightToWebView()
    }

    /// Spans the whole view (its own backdrop dims everything beneath it,
    /// webview included) - see NativeModalBridge's header comment for the
    /// current scope (Rate Us and the celebration modal).
    private func setupModal() {
        modal.translatesAutoresizingMaskIntoConstraints = false
        modal.isHidden = true
        view.addSubview(modal)
        NSLayoutConstraint.activate([
            modal.topAnchor.constraint(equalTo: view.topAnchor),
            modal.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            modal.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            modal.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Called by NativeModalBridge (JS-driven)

    func presentRateModal(title: String, body: String, buttonText: String, reviewUrl: String, isRTL: Bool) {
        modal.onPrimary = { [weak self] in
            if let url = URL(string: reviewUrl) {
                UIApplication.shared.open(url)
            }
            self?.modal.dismiss()
        }
        modal.onDismiss = nil
        modal.present(title: title, body: body, buttonText: buttonText, iconSymbol: "star.fill", isRTL: isRTL)
    }

    /// Mirrors celebrate()'s own behavior: the close X, the backdrop tap,
    /// and the primary ("Amen") button all dismiss AND navigate home -
    /// there's no plain-close path for this one, unlike the Rate modal.
    func presentCelebrationModal(title: String, body: String, buttonText: String, iconSymbol: String, isRTL: Bool) {
        modal.onPrimary = { [weak self] in self?.modal.dismiss() }
        modal.onDismiss = { [weak self] in
            self?.webView?.evaluateJavaScript("window.go && window.go('home')", completionHandler: nil)
        }
        modal.present(title: title, body: body, buttonText: buttonText, iconSymbol: iconSymbol, isRTL: isRTL)
    }

    func dismissModal() {
        modal.dismiss()
    }

    /// Separate full-screen overlay from `modal` (NativeModalView), since
    /// this one hosts real text input/keyboard handling - see
    /// NativeFeedbackFormView's own header comment.
    private func setupFeedbackForm() {
        feedbackForm.translatesAutoresizingMaskIntoConstraints = false
        feedbackForm.isHidden = true
        view.addSubview(feedbackForm)
        NSLayoutConstraint.activate([
            feedbackForm.topAnchor.constraint(equalTo: view.topAnchor),
            feedbackForm.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            feedbackForm.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            feedbackForm.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func presentFeedbackForm(title: String, body: String, namePlaceholder: String, emailPlaceholder: String,
                              messagePlaceholder: String, sendButtonText: String,
                              subject: String, supportEmail: String, isRTL: Bool, subjectPlaceholder: String = "") {
        feedbackForm.onSend = { [weak self] name, email, subject, message in
            self?.relayFeedbackToJS(name: name, email: email, subject: subject, message: message)
            self?.feedbackForm.dismiss()
        }
        feedbackForm.onDismiss = nil
        feedbackForm.present(
            title: title, body: body, namePlaceholder: namePlaceholder, emailPlaceholder: emailPlaceholder,
            messagePlaceholder: messagePlaceholder, sendButtonText: sendButtonText, isRTL: isRTL,
            subjectPlaceholder: subjectPlaceholder
        )
    }

    func dismissFeedbackForm() {
        feedbackForm.dismiss()
    }

    /// The app scrolls inside the web page (on <body>), so iOS's own "tap the status bar to scroll to
    /// top" has nothing to scroll. A tiny invisible UIScrollView that is the ONLY one with
    /// `scrollsToTop` catches that system gesture; its delegate runs the page's own smooth scroll
    /// (window.betelScrollTop) instead. Tapping the header title does the same.
    private func setupScrollToTop() {
        webView?.scrollView.scrollsToTop = false
        let scrollToTop: () -> Void = { [weak self] in
            self?.webView?.evaluateJavaScript("window.betelScrollTop && window.betelScrollTop()", completionHandler: nil)
        }
        scrollTopCatcher.frame = CGRect(x: 0, y: 0, width: 2, height: 2)
        scrollTopCatcher.onScrollToTop = scrollToTop
        view.insertSubview(scrollTopCatcher, at: 0)
        topBar.onTitleTap = scrollToTop
    }

    private func setupHomeEdit() {
        homeEditOverlay.frame = view.bounds
        homeEditOverlay.runJS = { [weak self] js in self?.webView?.evaluateJavaScript(js, completionHandler: nil) }
        homeEditOverlay.topInset = { [weak self] in self?.view.safeAreaInsets.top ?? 0 }
        view.insertSubview(homeEditOverlay, belowSubview: tabBar)
    }

    /// Pinned just above the tab bar, matching the HTML `.toast`'s own
    /// `bottom: calc(var(--native-nav-h) + 20px)` position when a native
    /// tab bar is present (see the `.has-native-tabbar .toast` CSS rule).
    private func setupToast() {
        toastView.translatesAutoresizingMaskIntoConstraints = false
        toastView.isHidden = true
        view.addSubview(toastView)
        NSLayoutConstraint.activate([
            toastView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toastView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toastView.bottomAnchor.constraint(equalTo: tabBar.topAnchor, constant: -20),
            toastView.heightAnchor.constraint(equalToConstant: 76),
        ])
    }

    // MARK: - Called by NativeToastBridge (JS-driven)

    func showToast(message: String) {
        toastView.show(message: message)
    }

    /// Fills the same content area the WKWebView itself occupies (below the
    /// native top bar, above the native tab bar) - this REPLACES the
    /// Settings tab's content visually while shown, not a floating card
    /// like the modal/toast, since it stands in for the whole screen's
    /// content rather than a transient dialog. The HTML Settings screen
    /// keeps rendering underneath the whole time (see syncNativeSettings()
    /// in index.html) - hiding this view just reveals it again.
    private func setupSettingsView() {
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        settingsView.isHidden = true
        // Below the floating tab bar (the list scrolls under it, inset clears it).
        view.insertSubview(settingsView, belowSubview: tabBar)
        NSLayoutConstraint.activate([
            settingsView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            settingsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        settingsView.onAction = { [weak self] id, value in
            self?.relaySettingsAction(id: id, value: value)
        }
    }

    // MARK: - Called by NativeSettingsBridge (JS-driven)

    func configureSettings(title: String, sections: [NativeSettingsSection], isDark: Bool, isRTL: Bool) {
        settingsView.configure(sections: sections, isDark: isDark, isRTL: isRTL)
    }

    func setSettingsVisible(_ visible: Bool) {
        settingsView.isHidden = !visible
    }

    /// Encodes `id` (and `value`, if present) as JSON string literals - via
    /// the `[x]`-then-strip-brackets trick, since `JSONSerialization` only
    /// accepts a top-level Array/Dictionary, not a bare String - so a
    /// row id or option value containing a quote or backslash can't break
    /// out of the generated JS call, same reasoning as
    /// `relayFeedbackToJS` above.
    private func jsStringLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let encoded = String(data: data, encoding: .utf8) else { return "null" }
        return String(encoded.dropFirst().dropLast())
    }

    private func relaySettingsAction(id: String, value: String?) {
        let valueJS = value.map(jsStringLiteral) ?? "null"
        let js = "window.NativeSettingsHost && window.NativeSettingsHost.onAction(\(jsStringLiteral(id)), \(valueJS))"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Hands the typed fields to window.NativeFeedbackHost.send(...) in JS
    /// rather than composing/sending the email in Swift - JS already owns
    /// a single sendFeedbackForm() implementation (silent Cloud Function
    /// relay, falling back to mailto:) shared with the HTML form, and this
    /// way the native path gets that same fallback chain for free instead
    /// of duplicating network code here that can't be tested in this
    /// environment. The fields are JSON-encoded (not interpolated as raw
    /// JS string literals) so a name/email/message containing a quote,
    /// backslash, or newline can't break out of the JS call.
    private func relayFeedbackToJS(name: String, email: String, subject: String, message: String) {
        let payload = ["name": name, "email": email, "subject": subject, "message": message]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        let js = "window.NativeFeedbackHost && window.NativeFeedbackHost.send(\(jsonString))"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    private func reportHeightToWebView() {
        let navHeight = tabBar.isHidden ? 0 : tabBar.frame.height
        let headerHeight = topBar.isHidden ? 0 : (topBar.frame.height)
        let js = """
        document.documentElement.style.setProperty('--native-nav-h','\(navHeight)px');
        document.documentElement.style.setProperty('--native-header-h','\(headerHeight)px');
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Called by NativeTabBarBridge (JS-driven)

    /// `isRTL` (the app's own S.lang, not the device language) decides the
    /// item order: the bar is pinned to LTR layout and the items reversed
    /// for Hebrew, so Home sits on the right in Hebrew and on the left in
    /// every other language no matter what language the device itself is set to.
    func configure(items: [[String: String]], activeTab: String, isRTL: Bool) {
        let byId = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let id = item["id"], let label = item["label"] else { return nil }
            return (id, label)
        })
        let ordered: [UITabBarItem] = MainViewController.tabOrder.compactMap { entry in
            guard let label = byId[entry.id] else { return nil }
            let item = UITabBarItem(title: label, image: UIImage(systemName: entry.icon), tag: 0)
            item.accessibilityIdentifier = entry.id
            return item
        }
        tabBar.semanticContentAttribute = .forceLeftToRight
        tabBar.items = isRTL ? ordered.reversed() : ordered
        self.isRTL = isRTL
        layoutToolsFab()
        layoutMiniTabButton()
        setActive(tab: activeTab)
        setVisible(true)
    }

    func setActive(tab: String) {
        tabBar.selectedItem = tabBar.items?.first { $0.accessibilityIdentifier == tab }
        refreshMiniTabIcon()
    }

    /// Selected-tab color: deep gold on light glass, a bright cream-gold on
    /// dark glass. On iOS 26 the Liquid Glass bar switches between light and
    /// dark by itself depending on what's scrolling under it, and this
    /// dynamic color follows that switch live (so it stays readable over a
    /// dark page even in the light theme, and vice versa).
    static let tabTint = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.973, green: 0.906, blue: 0.706, alpha: 1)
            : UIColor(red: 0.478, green: 0.353, blue: 0.078, alpha: 1)
    }

    /// From JS (S.theme). On iOS 26 the bar is left to adapt to the content
    /// beneath it (see `tabTint`); older systems' blur bar doesn't adapt by
    /// itself, so there it follows the app theme.
    func setTabBarTheme(isDark: Bool) {
        if #available(iOS 26.0, *) {
            tabBar.overrideUserInterfaceStyle = .unspecified
            miniTabButton.overrideUserInterfaceStyle = .unspecified
            return
        }
        let style: UIUserInterfaceStyle = isDark ? .dark : .light
        tabBar.overrideUserInterfaceStyle = style
        miniTabButton.overrideUserInterfaceStyle = style
    }

    func setVisible(_ visible: Bool) {
        tabBar.isHidden = !visible
        if !visible {
            miniTabButton.isHidden = true
            miniTabButton.alpha = 0
            isTabBarMinimized = false
            tabBar.alpha = 1
            tabBar.transform = .identity
        }
        reportHeightToWebView()
    }

    /// Scroll-down "hide" from JS minimizes rather than removes: the full
    /// bar shrinks toward the mini circle's corner and fades, and the mini
    /// circle (current tab's icon) springs in - Apple Music's behavior.
    /// Scrolling back up, or tapping the circle, expands it again.
    func setHidden(_ hidden: Bool) {
        guard !tabBar.isHidden, hidden != isTabBarMinimized else { return }
        isTabBarMinimized = hidden
        if hidden {
            refreshMiniTabIcon()
            miniTabButton.isHidden = false
        }
        let w = tabBar.bounds.width
        let towardCorner = CGAffineTransform(translationX: (isRTL ? 1 : -1) * w * 0.38, y: 0).scaledBy(x: 0.25, y: 0.6)
        UIView.animate(
            withDuration: ReduceMotion.duration(hidden ? 0.34 : 0.42), delay: 0,
            usingSpringWithDamping: 0.82, initialSpringVelocity: 0.3, options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.tabBar.alpha = hidden ? 0 : 1
                self.tabBar.transform = hidden ? towardCorner : .identity
                self.miniTabButton.alpha = hidden ? 1 : 0
                self.miniTabButton.transform = hidden ? .identity : CGAffineTransform(scaleX: 0.6, y: 0.6)
            },
            completion: { _ in
                if !self.isTabBarMinimized { self.miniTabButton.isHidden = true }
            }
        )
    }
}

extension MainViewController: UIGestureRecognizerDelegate {
    /// Only taps that land outside the FAB and its expanded panel count as
    /// "outside" - taps on the panel's own buttons must not close it.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard toolsFab.isExpanded else { return false }
        return !toolsFab.containsTouch(touch)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

extension MainViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let tabId = item.accessibilityIdentifier else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        if tabId == "search" {
            webView?.evaluateJavaScript("window.NativeSearchHost && window.NativeSearchHost.open()", completionHandler: nil)
            return
        }
        webView?.evaluateJavaScript("window.go && window.go('\(tabId)')", completionHandler: nil)
    }
}


/// See `MainViewController.setupScrollToTop()`.
final class ScrollTopCatcher: UIScrollView, UIScrollViewDelegate {
    var onScrollToTop: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        scrollsToTop = true
        isScrollEnabled = true
        alpha = 0.02                       // must be "visible" for the system to pick it
        backgroundColor = .clear
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentSize = CGSize(width: 2, height: 4000)
        contentOffset = CGPoint(x: 0, y: 2000)   // not at the top, so a scroll-to-top is requested
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        onScrollToTop?()
        return false   // never actually scroll this dummy view
    }
}
