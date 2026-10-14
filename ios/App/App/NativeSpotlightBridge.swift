import Foundation
import UIKit
import CoreSpotlight
import MobileCoreServices
import UniformTypeIdentifiers
import Capacitor

/// Core Spotlight for prayers, Tehillim chapters and the main sections.
///
/// JS (`spotlightSync()` in index.html) builds the item list and calls `index`; this replaces the whole
/// domain, so a language change just re-indexes. A tap on a result reaches SceneDelegate as
/// CSSearchableItemActionType; `handle(_:)` keeps the id until JS is listening (cold start) or notifies the
/// `open` listener right away (warm), and the web app opens the screen through its own openPrayer()/go().
@objc(NativeSpotlightBridge)
public class NativeSpotlightBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeSpotlightBridge"
    public let jsName = "NativeSpotlight"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "index", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "clear", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "consumePending", returnType: CAPPluginReturnPromise),
    ]

    private static let domain = "com.beitel.tehilim.content"
    private static var pendingId: String?
    private static weak var shared: NativeSpotlightBridge?
    private static var jsReady = false

    public override func load() {
        NativeSpotlightBridge.shared = self
    }

    /// Called from SceneDelegate for every NSUserActivity; returns true when it was a Spotlight tap.
    @discardableResult
    static func handle(_ activity: NSUserActivity) -> Bool {
        guard activity.activityType == CSSearchableItemActionType,
              let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return false }
        if jsReady, let plugin = shared {
            plugin.notifyListeners("open", data: ["id": id])
        } else {
            pendingId = id
        }
        return true
    }

    @objc func index(_ call: CAPPluginCall) {
        guard let rows = call.getArray("items") as? [[String: Any]] else { call.reject("items missing"); return }
        let items: [CSSearchableItem] = rows.compactMap { row in
            guard let id = row["id"] as? String, let title = row["title"] as? String else { return nil }
            let attrs: CSSearchableItemAttributeSet
            if #available(iOS 14.0, *) {
                attrs = CSSearchableItemAttributeSet(contentType: UTType.text)
            } else {
                attrs = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
            }
            attrs.title = title
            attrs.contentDescription = row["desc"] as? String
            attrs.keywords = (row["keywords"] as? [String]) ?? []
            let item = CSSearchableItem(uniqueIdentifier: id, domainIdentifier: NativeSpotlightBridge.domain, attributeSet: attrs)
            item.expirationDate = Date.distantFuture
            return item
        }
        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [NativeSpotlightBridge.domain]) { _ in
            index.indexSearchableItems(items) { error in
                if let error = error { call.reject(error.localizedDescription) } else { call.resolve(["count": items.count]) }
            }
        }
    }

    @objc func clear(_ call: CAPPluginCall) {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [NativeSpotlightBridge.domain]) { _ in call.resolve() }
    }

    /// JS calls this once its listener is attached: returns the tap that launched the app (if any).
    @objc func consumePending(_ call: CAPPluginCall) {
        NativeSpotlightBridge.jsReady = true
        let id = NativeSpotlightBridge.pendingId
        NativeSpotlightBridge.pendingId = nil
        call.resolve(id.map { ["id": $0] } ?? [:])
    }
}
