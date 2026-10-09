import Foundation
import Capacitor

/// Exposes `window.Capacitor.Plugins.NativeModal.*` to the web app so it
/// can drive a real native Liquid Glass modal card (NativeModalView) in
/// place of the HTML `.overlay`/`.modal` dialogs.
///
/// `presentRateModal` (openRateModal()), `presentCelebration`
/// (celebrate()), and `presentFeedbackForm` (openFeedbackForm()) are all
/// wired up. The feedback form uses its own native view
/// (NativeFeedbackFormView) rather than NativeModalView, since it needs
/// real UITextField/UITextView input, keyboard avoidance, and RTL text
/// entry instead of a fixed title/body/button. Its Send button doesn't
/// send anything itself - MainViewController.relayFeedbackToJS() hands
/// the typed fields to window.NativeFeedbackHost.send(...) in JS, which
/// owns the one sendFeedbackForm() implementation (shared with the HTML
/// form): a silent Cloud Function relay first, falling back to mailto:
/// only if that call fails. See functions/index.js and
/// sendFeedbackForm() in index.html.
@objc(NativeModalBridge)
public class NativeModalBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeModalBridge"
    public let jsName = "NativeModal"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "presentRateModal", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "presentCelebration", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "presentFeedbackForm", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "presentActionSheet", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "dismiss", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "dismissFeedbackForm", returnType: CAPPluginReturnPromise),
    ]

    static weak var activeController: MainViewController?

    /// System action sheet (UIAlertController, `.actionSheet`) - picks up the real Liquid Glass look
    /// on iOS 26 and the classic sheet on older iOS. Resolves with `{ id }` of the tapped action, or
    /// `{ id: "cancel" }`. Params: title, actions: [{ id, title, destructive? }], cancelTitle.
    @objc func presentActionSheet(_ call: CAPPluginCall) {
        let title = call.getString("title")
        let cancelTitle = call.getString("cancelTitle") ?? "Cancel"
        let actions = call.getArray("actions", JSObject.self) ?? []
        DispatchQueue.main.async {
            guard let vc = NativeModalBridge.activeController else { call.resolve(["id": "cancel"]); return }
            let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
            for a in actions {
                let id = a["id"] as? String ?? ""
                let t = a["title"] as? String ?? ""
                let destructive = a["destructive"] as? Bool ?? false
                sheet.addAction(UIAlertAction(title: t, style: destructive ? .destructive : .default) { _ in
                    call.resolve(["id": id])
                })
            }
            sheet.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in call.resolve(["id": "cancel"]) })
            if let pop = sheet.popoverPresentationController {
                pop.sourceView = vc.view
                pop.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 1, height: 1)
                pop.permittedArrowDirections = []
            }
            (vc.presentedViewController ?? vc).present(sheet, animated: true)
        }
    }

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

    @objc func presentFeedbackForm(_ call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let body = call.getString("body") ?? ""
        let namePlaceholder = call.getString("namePlaceholder") ?? ""
        let emailPlaceholder = call.getString("emailPlaceholder") ?? ""
        let messagePlaceholder = call.getString("messagePlaceholder") ?? ""
        let subjectPlaceholder = call.getString("subjectPlaceholder") ?? ""
        let sendButtonText = call.getString("sendButtonText") ?? ""
        let subject = call.getString("subject") ?? ""
        let supportEmail = call.getString("supportEmail") ?? ""
        let isRTL = call.getBool("isRTL") ?? true
        DispatchQueue.main.async {
            NativeModalBridge.activeController?.presentFeedbackForm(
                title: title, body: body, namePlaceholder: namePlaceholder, emailPlaceholder: emailPlaceholder,
                messagePlaceholder: messagePlaceholder, sendButtonText: sendButtonText,
                subject: subject, supportEmail: supportEmail, isRTL: isRTL,
                subjectPlaceholder: subjectPlaceholder
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

    @objc func dismissFeedbackForm(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            NativeModalBridge.activeController?.dismissFeedbackForm()
        }
        call.resolve()
    }
}
