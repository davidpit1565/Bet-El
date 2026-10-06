import Foundation
import Capacitor

/// Exposes `window.Capacitor.Plugins.NativeToast.show(...)` to the web app
/// so `toast()` in index.html can show a real native Liquid Glass pill
/// (NativeToastView) instead of the HTML `.toast` CSS approximation - see
/// NativeModalBridge's header comment for the same pattern used there.
@objc(NativeToastBridge)
public class NativeToastBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeToastBridge"
    public let jsName = "NativeToast"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "show", returnType: CAPPluginReturnPromise),
    ]

    static weak var activeController: MainViewController?

    @objc func show(_ call: CAPPluginCall) {
        let message = call.getString("message") ?? ""
        DispatchQueue.main.async {
            NativeToastBridge.activeController?.showToast(message: message)
        }
        call.resolve()
    }
}
