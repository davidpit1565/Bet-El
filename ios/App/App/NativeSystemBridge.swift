import UIKit
import Capacitor
import SafariServices
import StoreKit
import CoreImage
import Security

/// Small system helpers the web layer needs as REAL iOS components:
/// - `openURL`: an in-app Safari sheet (SFSafariViewController) so links never leave the app
/// - `shareImage`: the system share sheet with an image (it also offers Save Image / Copy)
/// - `qrImage`: an offline QR code from Core Image (no network, so sharing never fails)
/// - `requestReview`: Apple's own star-rating prompt (no App Store trip; iOS decides how often it shows)
@objc(NativeSystemBridge)
public class NativeSystemBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeSystemBridge"
    public let jsName = "NativeSystem"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "openURL", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "shareImage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "qrImage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestReview", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "keychainGet", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "keychainSet", returnType: CAPPluginReturnPromise),
    ]

    private func topController() -> UIViewController? {
        var top: UIViewController? = bridge?.viewController
        while let p = top?.presentedViewController { top = p }
        return top
    }

    @objc func openURL(_ call: CAPPluginCall) {
        guard let s = call.getString("url"), let url = URL(string: s), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { call.reject("bad url"); return }
        DispatchQueue.main.async {
            let vc = SFSafariViewController(url: url)
            vc.preferredControlTintColor = UIColor(red: 0.83, green: 0.69, blue: 0.37, alpha: 1)
            vc.dismissButtonStyle = .close
            if let top = self.topController() { top.present(vc, animated: true) }
        }
        call.resolve()
    }

    private func image(from s: String) -> UIImage? {
        var b = s
        if let r = b.range(of: "base64,") { b = String(b[r.upperBound...]) }
        return Data(base64Encoded: b).flatMap { UIImage(data: $0) }
    }

    @objc func shareImage(_ call: CAPPluginCall) {
        guard let img = image(from: call.getString("data") ?? "") else { call.reject("no image"); return }
        let text = call.getString("text") ?? ""
        DispatchQueue.main.async {
            var items: [Any] = [img]
            if !text.isEmpty { items.append(text) }
            let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
            if let pop = vc.popoverPresentationController, let top = self.topController() {
                pop.sourceView = top.view
                pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 40, width: 1, height: 1)
                pop.permittedArrowDirections = []
            }
            self.topController()?.present(vc, animated: true)
        }
        call.resolve()
    }

    @objc func qrImage(_ call: CAPPluginCall) {
        guard let text = call.getString("text"), let data = text.data(using: .utf8),
              let f = CIFilter(name: "CIQRCodeGenerator") else { call.reject("no qr"); return }
        f.setValue(data, forKey: "inputMessage")
        f.setValue("M", forKey: "inputCorrectionLevel")
        guard let out = f.outputImage else { call.reject("no qr"); return }
        // dark modules on a light ground: the combination every scanner reads reliably
        let dark = CIColor(red: 0.05, green: 0.09, blue: 0.19)
        let light = CIColor(red: 0.96, green: 0.95, blue: 0.89)
        let colored = CIFilter(name: "CIFalseColor", parameters: ["inputImage": out, "inputColor0": dark, "inputColor1": light])?.outputImage ?? out
        let size = CGFloat(call.getInt("size") ?? 560)
        let scale = max(1, floor(size / colored.extent.width))
        let scaled = colored.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent), let png = UIImage(cgImage: cg).pngData() else {
            call.reject("no qr"); return
        }
        call.resolve(["data": png.base64EncodedString()])
    }

    @objc func requestReview(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            guard let scene = scene else { return }
            if #available(iOS 16.0, *) { AppStore.requestReview(in: scene) }
            else { SKStoreReviewController.requestReview(in: scene) }
        }
        call.resolve()
    }

    // MARK: Keychain flag - survives deleting and reinstalling the app (used so the public user counter counts a device once)
    private func keychainQuery(_ key: String) -> [String: Any] {
        return [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.beitel.tehilim.flags",
                kSecAttrAccount as String: key]
    }

    @objc func keychainGet(_ call: CAPPluginCall) {
        guard let key = call.getString("key") else { call.reject("no key"); return }
        var q = keychainQuery(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        if status == errSecSuccess, let d = out as? Data, let v = String(data: d, encoding: .utf8) {
            call.resolve(["value": v])
        } else {
            call.resolve(["value": NSNull()])
        }
    }

    @objc func keychainSet(_ call: CAPPluginCall) {
        guard let key = call.getString("key"), let value = call.getString("value") else { call.reject("bad args"); return }
        var q = keychainQuery(key)
        SecItemDelete(q as CFDictionary)
        q[kSecValueData as String] = value.data(using: .utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(q as CFDictionary, nil)
        if status == errSecSuccess { call.resolve() } else { call.reject("keychain \(status)") }
    }
}
