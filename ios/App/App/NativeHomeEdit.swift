import UIKit
import Capacitor

/// Real iOS 26 Liquid Glass controls for the home screen's edit mode.
///
/// The home screen's tiles are web content, but everything you TOUCH in edit
/// mode is a genuine native UIKit control drawn with Apple's own
/// `UIGlassEffect` (via `UIButton.Configuration.glass()`), not a CSS look-alike:
/// the minus badges, the corner resize handles, the "+" / check pills at the
/// top, the remove confirmation (a system `UIAlertController`) and the add-button
/// sheet (a system sheet). JS (index.html's HOME CUSTOMIZATION) sends where each
/// tile currently is (`setControls`) and gets taps/drags back through
/// `window.NativeHomeEditHost`.
final class HomeEditOverlay: UIView {
    struct Spec {
        let id: String
        let minus: Bool
        let resize: Bool
        let frame: CGRect
    }

    /// Runs a JS snippet in the web view (set by MainViewController).
    var runJS: ((String) -> Void)?
    /// Bottom edge of the native header, so the pills sit just under it.
    var topInset: (() -> CGFloat)?
    /// Called when the overlay appears so the owner can lift it above the native header (which otherwise
    /// covers the + / check pills and swallows their taps).
    var onShow: (() -> Void)?

    private var minusButtons: [String: UIButton] = [:]
    private var resizeHandles: [String: ResizeHandle] = [:]
    private let addButton = HomeEditOverlay.glassButton(symbol: "plus", pointSize: 18, size: CGSize(width: 68, height: 44))
    private let doneButton = HomeEditOverlay.glassButton(symbol: "checkmark", pointSize: 18, size: CGSize(width: 68, height: 44))
    private var pillsInstalled = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Taps that don't land on one of the controls fall through to the web view.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    // MARK: - Glass controls

    static func glassButton(symbol: String, pointSize: CGFloat, size: CGSize) -> UIButton {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .bold))
        if #available(iOS 26.0, *) {
            var config = UIButton.Configuration.glass()
            config.image = image
            config.cornerStyle = .capsule
            config.baseForegroundColor = .label
            config.contentInsets = .zero
            button.configuration = config
        } else {
            var config = UIButton.Configuration.filled()
            config.image = image
            config.cornerStyle = .capsule
            config.background.visualEffect = UIBlurEffect(style: .systemThinMaterial)
            config.baseBackgroundColor = .clear
            config.baseForegroundColor = .label
            config.contentInsets = .zero
            button.configuration = config
        }
        button.bounds = CGRect(origin: .zero, size: size)
        return button
    }

    private func installPills() {
        guard !pillsInstalled else { return }
        pillsInstalled = true
        addButton.accessibilityLabel = "Add"
        doneButton.accessibilityLabel = "Done"
        addButton.addAction(UIAction { [weak self] _ in
            self?.runJS?("window.NativeHomeEditHost && window.NativeHomeEditHost.add()")
        }, for: .touchUpInside)
        doneButton.addAction(UIAction { [weak self] _ in
            self?.runJS?("window.NativeHomeEditHost && window.NativeHomeEditHost.done()")
        }, for: .touchUpInside)
        addSubview(addButton)
        addSubview(doneButton)
    }

    private func layoutPills() {
        // Comfortably below the status bar / Dynamic Island and the native header, never under them
        let y = (topInset?() ?? 0) + 12
        // Physical corners (like the iPhone's own edit mode): + on the left, check on the right
        addButton.frame = CGRect(x: 16, y: y, width: 68, height: 44)
        doneButton.frame = CGRect(x: bounds.width - 16 - 68, y: y, width: 68, height: 44)
    }

    // MARK: - Updating from JS

    func apply(specs: [Spec], rtl: Bool, isDark: Bool) {
        overrideUserInterfaceStyle = isDark ? .dark : .light
        if isHidden { isHidden = false; onShow?() }
        installPills()
        layoutPills()
        bringSubviewToFront(addButton)
        bringSubviewToFront(doneButton)

        let minusSize: CGFloat = 28
        let handleSize: CGFloat = 56
        var keepMinus = Set<String>()
        var keepResize = Set<String>()

        for spec in specs {
            if spec.minus {
                keepMinus.insert(spec.id)
                let button: UIButton
                if let existing = minusButtons[spec.id] {
                    button = existing
                } else {
                    button = HomeEditOverlay.glassButton(symbol: "minus", pointSize: 12, size: CGSize(width: minusSize, height: minusSize))
                    button.accessibilityLabel = "Remove"
                    let id = spec.id
                    button.addAction(UIAction { [weak self] _ in
                        self?.runJS?("window.NativeHomeEditHost && window.NativeHomeEditHost.minus('\(id)')")
                    }, for: .touchUpInside)
                    addSubview(button)
                    minusButtons[spec.id] = button
                }
                // the tile's top corner on the reading-direction start side
                let cx = rtl ? spec.frame.maxX - 6 : spec.frame.minX + 6
                button.frame = CGRect(x: cx - minusSize / 2, y: spec.frame.minY + 6 - minusSize / 2, width: minusSize, height: minusSize)
            }
            if spec.resize {
                keepResize.insert(spec.id)
                let handle: ResizeHandle
                if let existing = resizeHandles[spec.id] {
                    handle = existing
                } else {
                    handle = ResizeHandle(id: spec.id)
                    handle.runJS = { [weak self] js in self?.runJS?(js) }
                    addSubview(handle)
                    resizeHandles[spec.id] = handle
                }
                // bottom corner on the reading-direction end side
                let cx = rtl ? spec.frame.minX + handleSize / 2 + 2 : spec.frame.maxX - handleSize / 2 - 2
                handle.frame = CGRect(x: cx - handleSize / 2, y: spec.frame.maxY - handleSize - 2, width: handleSize, height: handleSize)
            }
        }
        for (id, view) in minusButtons where !keepMinus.contains(id) { view.removeFromSuperview(); minusButtons[id] = nil }
        for (id, view) in resizeHandles where !keepResize.contains(id) { view.removeFromSuperview(); resizeHandles[id] = nil }
    }

    func hideAll() {
        isHidden = true
        minusButtons.values.forEach { $0.removeFromSuperview() }
        resizeHandles.values.forEach { $0.removeFromSuperview() }
        minusButtons.removeAll()
        resizeHandles.removeAll()
    }
}

/// The corner resize handle: a glass circle that forwards a pan gesture to JS
/// (which owns the small -> medium -> large stepping), like the handle on an
/// iPhone widget.
final class ResizeHandle: UIView {
    let id: String
    var runJS: ((String) -> Void)?

    init(id: String) {
        self.id = id
        super.init(frame: .zero)
        let glass = HomeEditOverlay.glassButton(symbol: "arrow.up.left.and.arrow.down.right", pointSize: 13, size: CGSize(width: 34, height: 34))
        glass.isUserInteractionEnabled = false   // the pan below owns all touches
        glass.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)
        NSLayoutConstraint.activate([
            glass.centerXAnchor.constraint(equalTo: centerXAnchor),
            glass.centerYAnchor.constraint(equalTo: centerYAnchor),
            glass.widthAnchor.constraint(equalToConstant: 34),
            glass.heightAnchor.constraint(equalToConstant: 34),
        ])
        accessibilityLabel = "Resize"
        isAccessibilityElement = true
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        let t = gesture.translation(in: superview)
        let host = "window.NativeHomeEditHost && window.NativeHomeEditHost"
        switch gesture.state {
        case .began:
            runJS?("\(host).resizeStart('\(id)')")
        case .changed:
            runJS?("\(host).resizeMove('\(id)',\(Double(t.x)),\(Double(t.y)))")
        case .ended, .cancelled, .failed:
            runJS?("\(host).resizeEnd('\(id)')")
        default:
            break
        }
    }
}

/// The "add a button" sheet: a plain system sheet (glass on iOS 26) listing every
/// button that isn't on the home yet.
final class HomeAddSheetController: UITableViewController, UIAdaptivePresentationControllerDelegate {
    var rows: [(id: String, label: String)] = []
    var resetLabel = ""
    var emptyLabel = ""
    var onFinish: ((String?, Bool) -> Void)?
    private var finished = false

    override init(style: UITableView.Style) { super.init(style: style) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
    }

    @objc private func closeTapped() { finish(nil, false) }

    func finish(_ id: String?, _ reset: Bool) {
        guard !finished else { return }
        finished = true
        let callback = onFinish
        dismiss(animated: true) { callback?(id, reset) }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard !finished else { return }
        finished = true
        onFinish?(nil, false)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { resetLabel.isEmpty ? 1 : 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? max(rows.count, rows.isEmpty ? 1 : 0) : 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        if indexPath.section == 1 {
            content.text = resetLabel
            content.textProperties.color = .systemRed
        } else if rows.isEmpty {
            content.text = emptyLabel
            content.textProperties.color = .secondaryLabel
            cell.selectionStyle = .none
        } else {
            content.text = rows[indexPath.row].label
            let plus = UIImageView(image: UIImage(systemName: "plus.circle.fill"))
            plus.tintColor = .betelGold
            plus.sizeToFit()
            cell.accessoryView = plus
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 { finish(nil, true); return }
        guard !rows.isEmpty else { return }
        finish(rows[indexPath.row].id, false)
    }
}

extension MainViewController {
    /// A system alert (real Liquid Glass on iOS 26) asking whether to remove a home button.
    func homeEditConfirm(title: String, message: String, cancel: String, remove: String, isDark: Bool, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = isDark ? .dark : .light
        alert.addAction(UIAlertAction(title: cancel, style: .cancel) { _ in completion(false) })
        alert.addAction(UIAlertAction(title: remove, style: .destructive) { _ in completion(true) })
        (presentedViewController ?? self).present(alert, animated: true)
    }

    func homeEditSheet(title: String, rows: [(id: String, label: String)], resetLabel: String, emptyLabel: String,
                       rtl: Bool, isDark: Bool, completion: @escaping (String?, Bool) -> Void) {
        let list = HomeAddSheetController(style: .insetGrouped)
        list.title = title
        list.rows = rows
        list.resetLabel = resetLabel
        list.emptyLabel = emptyLabel
        list.onFinish = completion
        list.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        let nav = UINavigationController(rootViewController: list)
        nav.overrideUserInterfaceStyle = isDark ? .dark : .light
        nav.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        nav.presentationController?.delegate = list
        present(nav, animated: true)
    }
}

@objc(NativeHomeEditBridge)
public class NativeHomeEditBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeHomeEditBridge"
    public let jsName = "NativeHomeEdit"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "setControls", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hide", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "confirmRemove", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showAddSheet", returnType: CAPPluginReturnPromise),
    ]

    static weak var activeController: MainViewController?

    @objc func setControls(_ call: CAPPluginCall) {
        let rtl = call.getBool("rtl") ?? true
        let isDark = call.getBool("isDark") ?? false
        let raw = call.getArray("items") ?? []
        var specs: [HomeEditOverlay.Spec] = []
        for case let d as [String: Any] in raw {
            func num(_ key: String) -> CGFloat { CGFloat((d[key] as? NSNumber)?.doubleValue ?? 0) }
            specs.append(HomeEditOverlay.Spec(
                id: d["id"] as? String ?? "",
                minus: d["minus"] as? Bool ?? false,
                resize: d["resize"] as? Bool ?? false,
                frame: CGRect(x: num("x"), y: num("y"), width: num("w"), height: num("h"))
            ))
        }
        DispatchQueue.main.async {
            NativeHomeEditBridge.activeController?.homeEditOverlay.apply(specs: specs, rtl: rtl, isDark: isDark)
        }
        call.resolve()
    }

    @objc func hide(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            NativeHomeEditBridge.activeController?.homeEditOverlay.hideAll()
        }
        call.resolve()
    }

    @objc func confirmRemove(_ call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let message = call.getString("message") ?? ""
        let cancel = call.getString("cancel") ?? "Cancel"
        let remove = call.getString("remove") ?? "Remove"
        let isDark = call.getBool("isDark") ?? false
        DispatchQueue.main.async {
            guard let controller = NativeHomeEditBridge.activeController else { call.resolve(["confirmed": false]); return }
            controller.homeEditConfirm(title: title, message: message, cancel: cancel, remove: remove, isDark: isDark) { ok in
                call.resolve(["confirmed": ok])
            }
        }
    }

    @objc func showAddSheet(_ call: CAPPluginCall) {
        let title = call.getString("title") ?? ""
        let resetLabel = call.getString("resetLabel") ?? ""
        let emptyLabel = call.getString("emptyLabel") ?? ""
        let rtl = call.getBool("rtl") ?? true
        let isDark = call.getBool("isDark") ?? false
        let rawRows = call.getArray("rows") ?? []
        var rows: [(id: String, label: String)] = []
        for case let d as [String: Any] in rawRows {
            rows.append((d["id"] as? String ?? "", d["label"] as? String ?? ""))
        }
        DispatchQueue.main.async {
            guard let controller = NativeHomeEditBridge.activeController else { call.resolve([:]); return }
            controller.homeEditSheet(title: title, rows: rows, resetLabel: resetLabel, emptyLabel: emptyLabel, rtl: rtl, isDark: isDark) { id, reset in
                if let id = id { call.resolve(["id": id]) }
                else if reset { call.resolve(["reset": true]) }
                else { call.resolve([:]) }
            }
        }
    }
}
