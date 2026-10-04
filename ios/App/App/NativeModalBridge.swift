import Foundation
import Capacitor

/// Exposes `window.Capacitor.Plugins.NativeModal.*` to the web app so it
/// can drive a real native Liquid Glass modal card (NativeModalView) in
/// place of the HTML `.overlay`/`.modal` dialogs.
///
/// Only `presentRateModal` is wired up (see openRateModal() in
/// index.html) - the app's other two `.overlay` dialogs are intentionally
/// left as HTML rather than ported blind in this pass:
///   - openFeedbackForm() has three real text inputs (name/email/message)
///     that would need native UITextField/UITextView, keyboard avoidance,
///     and RTL text entry all re-implemented and validated without a way
///     to build/test them in this environment.
///   - celebrate() always shows behind a full-screen HTML confetti burst
///     (see confetti() in index.html); a native modal's own opaque
///     backdrop would sit on top of the webview and hide that animation,
///     which is the point of the celebration.
/// Both are reasonable next steps on their own once this simpler case is
/// confirmed working on a real device.
@objc(NativeModalBridge)
public class NativeModalBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeModalBridge"
    public let jsName = "NativeModal"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "presentRateModal", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "dismiss", returnType: CAPPluginReturnPromise),
    ]

    static weak var activeController: MainViewController?

    @objc func presentRateModal(_ call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let body = call.getString("body") ?? ""
        let buttonText = call.getString("buttonText") ?? ""
        let reviewUrl = call.getString("reviewUrl") ?? ""
        let isRTL = call.getBool("isRTL") ?? true
        DispatchQueue.main.async {
            NativeModalBridge.activeController?.presentRateModal(
                title: title, body: body, buttonText: buttonText, reviewUrl: reviewUrl, isRTL: isRTL
            )
        }
        call.resolve()
    }

    @objc func dismiss(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            NativeModalBridge.activeController?.dismissModal()
        }
        call.resolve()
    }
}
