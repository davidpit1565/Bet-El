import Foundation
import Capacitor

/// Exposes `window.Capacitor.Plugins.NativeModal.*` to the web app so it
/// can drive a real native Liquid Glass modal card (NativeModalView) in
/// place of the HTML `.overlay`/`.modal` dialogs.
///
/// `presentRateModal` (openRateModal()) and `presentCelebration`
/// (celebrate()) are wired up. openFeedbackForm()'s dialog is
/// intentionally left as HTML rather than ported blind in this pass: it
/// has three real text inputs (name/email/message) that would need native
/// UITextField/UITextView, keyboard avoidance, and RTL text entry all
/// re-implemented and validated without a way to build/test them in this
/// environment - a reasonable next step on its own once these two are
/// confirmed working on a real device.
@objc(NativeModalBridge)
public class NativeModalBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeModalBridge"
    public let jsName = "NativeModal"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "presentRateModal", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "presentCelebration", returnType: CAPPluginReturnPromise),
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

    @objc func presentCelebration(_ call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let body = call.getString("body") ?? ""
        let buttonText = call.getString("buttonText") ?? ""
        let iconSymbol = call.getString("iconSymbol") ?? "star.fill"
        let isRTL = call.getBool("isRTL") ?? true
        DispatchQueue.main.async {
            NativeModalBridge.activeController?.presentCelebrationModal(
                title: title, body: body, buttonText: buttonText, iconSymbol: iconSymbol, isRTL: isRTL
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
