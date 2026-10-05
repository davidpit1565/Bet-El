import UIKit
import Capacitor
import MessageUI

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
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        setupToolsFab()
        setupTopBar()
        setupModal()
        setupFeedbackForm()
        NativeTabBarBridge.activeController = self
        NativeToolsFabBridge.activeController = self
        NativeTopBarBridge.activeController = self
        NativeModalBridge.activeController = self
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
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
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
            toolsFab.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            toolsFab.bottomAnchor.constraint(equalTo: tabBar.topAnchor, constant: -14),
            toolsFab.widthAnchor.constraint(equalToConstant: 46),
            toolsFab.heightAnchor.constraint(equalToConstant: 46),
        ])
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

    func configureTopBar(title: String, backTo: String, isRTL: Bool) {
        topBar.configure(title: title, hasBack: !backTo.isEmpty, isRTL: isRTL)
        topBar.onBack = { [weak self] in
            self?.webView?.evaluateJavaScript("window.go && window.go('\(backTo)')", completionHandler: nil)
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
                              subject: String, supportEmail: String, isRTL: Bool) {
        feedbackForm.onSend = { [weak self] name, email, message in
            self?.sendFeedbackMail(subject: subject, supportEmail: supportEmail, name: name, email: email, message: message)
            self?.feedbackForm.dismiss()
        }
        feedbackForm.onDismiss = nil
        feedbackForm.present(
            title: title, body: body, namePlaceholder: namePlaceholder, emailPlaceholder: emailPlaceholder,
            messagePlaceholder: messagePlaceholder, sendButtonText: sendButtonText, isRTL: isRTL
        )
    }

    func dismissFeedbackForm() {
        feedbackForm.dismiss()
    }

    /// Matches the HTML version's own mailto: body exactly ("שם: .../
    /// אימייל: .../\n\n...", hardcoded Hebrew labels regardless of UI
    /// language - the HTML form does the same). Prefers
    /// MFMailComposeViewController's in-app compose sheet when Mail is
    /// configured on the device, falling back to the plain mailto: URL
    /// (the same mechanism the web/HTML path always uses) otherwise.
    private func sendFeedbackMail(subject: String, supportEmail: String, name: String, email: String, message: String) {
        let body = "שם: \(name)\nאימייל: \(email)\n\n\(message)"
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients([supportEmail])
            mail.setSubject(subject)
            mail.setMessageBody(body, isHTML: false)
            present(mail, animated: true)
        } else if let url = mailtoURL(to: supportEmail, subject: subject, body: body) {
            UIApplication.shared.open(url)
        }
    }

    private func mailtoURL(to: String, subject: String, body: String) -> URL? {
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = to
        comps.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        return comps.url
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

    func configure(items: [[String: String]], activeTab: String) {
        let byId = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let id = item["id"], let label = item["label"] else { return nil }
            return (id, label)
        })
        tabBar.items = MainViewController.tabOrder.compactMap { entry in
            guard let label = byId[entry.id] else { return nil }
            let item = UITabBarItem(title: label, image: UIImage(systemName: entry.icon), tag: 0)
            item.accessibilityIdentifier = entry.id
            return item
        }
        setActive(tab: activeTab)
        setVisible(true)
    }

    func setActive(tab: String) {
        tabBar.selectedItem = tabBar.items?.first { $0.accessibilityIdentifier == tab }
    }

    func setVisible(_ visible: Bool) {
        tabBar.isHidden = !visible
        reportHeightToWebView()
    }

    func setHidden(_ hidden: Bool) {
        // The scroll-away/reveal behavior the HTML nav already had - a
        // simple fade+slide, not full removal (setVisible above is for
        // "this screen has no nav at all", a different state).
        UIView.animate(withDuration: hidden ? 0.26 : 0.38) {
            self.tabBar.alpha = hidden ? 0 : 1
            self.tabBar.transform = hidden
                ? CGAffineTransform(translationX: 0, y: self.tabBar.frame.height)
                : .identity
        }
    }
}

extension MainViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let tabId = item.accessibilityIdentifier else { return }
        webView?.evaluateJavaScript("window.go && window.go('\(tabId)')", completionHandler: nil)
    }
}

extension MainViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
