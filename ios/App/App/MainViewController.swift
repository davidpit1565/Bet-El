import UIKit
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
        NativeTabBarBridge.activeController = self
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

    private func reportHeightToWebView() {
        let height = tabBar.isHidden ? 0 : tabBar.frame.height
        let js = "document.documentElement.style.setProperty('--native-nav-h','\(height)px')"
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
