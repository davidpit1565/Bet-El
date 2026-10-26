import UIKit
import Capacitor

/// The Library screen (the grid of book categories) as a REAL native iOS screen: a `UICollectionView`
/// with a compositional layout, glass cards (`UIGlassEffect` on iOS 26, system material before),
/// native scrolling/bounce, press feedback and haptics. The web app stays the single source of
/// truth for WHAT is listed (titles, order, colours) - it sends the items through `NativeLibrary.show`
/// and gets taps back through `window.NativeLibraryHost.open(key)`. Web / PWA keep the HTML tiles.
/// Not compile-verified in Xcode.

struct NLItem {
    let key: String
    let title: String
    let color: UIColor
}

/// Flow layout that never lets UIKit flip it for the device's language: UIKit mirrors a collection view
/// (frames AND, when the forced direction differs from the device's, the cell contents) based on the
/// device layout direction, which showed an English app on a Hebrew iPhone with mirrored text. Geometry is
/// always laid out left-to-right and then mirrored here, by the APP's direction (`mirror`), so the card
/// order is right and nothing is ever drawn reversed. Cell contents set their own semantic attribute.
final class MirrorFlowLayout: UICollectionViewFlowLayout {
    var mirror = false { didSet { if mirror != oldValue { invalidateLayout() } } }

    override var flipsHorizontallyInOppositeLayoutDirection: Bool { false }

    private func mirrored(_ a: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        guard mirror, let w = collectionView?.bounds.width, let c = a.copy() as? UICollectionViewLayoutAttributes else { return a }
        c.frame.origin.x = w - a.frame.maxX
        return c
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let r = mirror ? CGRect(x: 0, y: rect.minY, width: max(rect.maxX, collectionView?.bounds.width ?? rect.width), height: rect.height) : rect
        return super.layoutAttributesForElements(in: r)?.map { mirrored($0) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        super.layoutAttributesForItem(at: indexPath).map { mirrored($0) }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        super.shouldInvalidateLayout(forBoundsChange: newBounds) || (mirror && newBounds.width != collectionView?.bounds.width)
    }
}

final class NLCell: UICollectionViewCell {
    static let reuseId = "NLCell"
    private let glass: UIVisualEffectView
    private let tintView = NHGradientView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        if #available(iOS 26.0, *) {
            glass = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        }
        super.init(frame: frame)
        glass.translatesAutoresizingMaskIntoConstraints = false
        glass.layer.cornerRadius = 24
        glass.clipsToBounds = true
        contentView.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: contentView.topAnchor),
            glass.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            glass.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
        tintView.translatesAutoresizingMaskIntoConstraints = false
        glass.contentView.addSubview(tintView)
        NSLayoutConstraint.activate([
            tintView.topAnchor.constraint(equalTo: glass.contentView.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor),
            tintView.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor),
        ])

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 3
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.textAlignment = .natural
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.setScaledFont(18, weight: .semibold, maximumSize: 30)
        glass.contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: glass.contentView.centerYAnchor),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    /// `rtl` is the APP language's direction (from JS), never the device locale: `.natural` and
    /// leading/trailing would otherwise follow the iPhone's language, not the app's.
    func configure(_ item: NLItem, rtl: Bool) {
        let attr: UISemanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        for v in [self, contentView, glass, glass.contentView, tintView, titleLabel] as [UIView] { v.semanticContentAttribute = attr }
        titleLabel.textAlignment = rtl ? .right : .left
        titleLabel.text = item.title
        accessibilityLabel = item.title
        tintView.gradient.colors = [item.color.withAlphaComponent(0.42).cgColor, item.color.withAlphaComponent(0.12).cgColor]
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.18, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }
}

final class NativeLibraryView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onSelect: ((String) -> Void)?
    var bottomInset: (() -> CGFloat)?
    var onCollapseChange: ((Bool) -> Void)?
    let collectionView: UICollectionView
    private var items: [NLItem] = []
    private var rtl = true
    private let collapseTracker = ScrollCollapseTracker()
    private let flowLayout: MirrorFlowLayout

    override init(frame: CGRect) {
        let flow = MirrorFlowLayout()
        flow.minimumLineSpacing = 12
        flow.minimumInteritemSpacing = 12
        flow.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        flowLayout = flow
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flow)
        super.init(frame: frame)
        backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(NLCell.self, forCellWithReuseIdentifier: NLCell.reuseId)
        addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if previous?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = bottomInset?() ?? 100
        if abs(collectionView.contentInset.bottom - b) > 0.5 {
            collectionView.contentInset.bottom = b
            collectionView.verticalScrollIndicatorInsets.bottom = b
        }
    }

    func show(items: [NLItem], rtl: Bool, isDark: Bool) {
        overrideUserInterfaceStyle = isDark ? .dark : .light
        let attr: UISemanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        semanticContentAttribute = attr
        collectionView.semanticContentAttribute = .forceLeftToRight   // geometry is mirrored by MirrorFlowLayout
        flowLayout.mirror = rtl
        self.rtl = rtl
        self.items = items
        collapseTracker.reset()
        collectionView.reloadData()
    }

    func scrollToTop() {
        collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: true)
    }

    // MARK: UIScrollView

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let y = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            + scrollView.adjustedContentInset.top + scrollView.adjustedContentInset.bottom
        if collapseTracker.update(y: y, maxY: maxY) {
            onCollapseChange?(collapseTracker.collapsed)
        }
    }

    // MARK: UICollectionView

    /// Two columns; accessibility text sizes switch to one full-width column so long titles are never clipped.
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let big = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let cols: CGFloat = big ? 1 : 2
        let w = collectionView.bounds.width - 32 - 12 * (cols - 1)
        return CGSize(width: floor(w / cols), height: A11y.scaled(92))
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NLCell.reuseId, for: indexPath) as! NLCell
        cell.configure(items[indexPath.item], rtl: rtl)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSelect?(items[indexPath.item].key)
    }
}

// MARK: - Capacitor bridge

@objc(NativeLibraryBridge)
public class NativeLibraryBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeLibraryBridge"
    public let jsName = "NativeLibrary"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "show", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hide", returnType: CAPPluginReturnPromise),
    ]

    static weak var activeController: MainViewController?

    private static func color(_ hex: String) -> UIColor {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return .systemYellow }
        return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    @objc func show(_ call: CAPPluginCall) {
        let rtl = call.getBool("isRTL") ?? true
        let isDark = call.getBool("isDark") ?? true
        var items: [NLItem] = []
        for case let d as [String: Any] in (call.getArray("items") ?? []) {
            items.append(NLItem(key: d["key"] as? String ?? "", title: d["title"] as? String ?? "",
                                color: NativeLibraryBridge.color(d["color"] as? String ?? "")))
        }
        DispatchQueue.main.async {
            NativeLibraryBridge.activeController?.showNativeLibrary(items: items, rtl: rtl, isDark: isDark)
        }
        call.resolve()
    }

    @objc func hide(_ call: CAPPluginCall) {
        DispatchQueue.main.async { NativeLibraryBridge.activeController?.hideNativeLibrary() }
        call.resolve()
    }
}
