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

final class NLCell: UICollectionViewCell {
    static let reuseId = "NLCell"
    private let glass: UIVisualEffectView
    private let tintLayer = CAGradientLayer()
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
        tintLayer.startPoint = CGPoint(x: 0, y: 0)
        tintLayer.endPoint = CGPoint(x: 1, y: 1)
        glass.contentView.layer.addSublayer(tintLayer)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 3
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.textAlignment = .natural
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        let base = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.font = UIFont.systemFont(ofSize: base.pointSize + 1, weight: .semibold)
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
        tintLayer.frame = glass.contentView.bounds
    }

    func configure(_ item: NLItem) {
        titleLabel.text = item.title
        accessibilityLabel = item.title
        tintLayer.colors = [item.color.withAlphaComponent(0.34).cgColor, item.color.withAlphaComponent(0.04).cgColor]
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.18, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }
}

final class NativeLibraryView: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    var onSelect: ((String) -> Void)?
    var bottomInset: (() -> CGFloat)?
    let collectionView: UICollectionView
    private var items: [NLItem] = []

    override init(frame: CGRect) {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1), heightDimension: .absolute(92)), subitem: item, count: 2)
        group.interItemSpacing = .fixed(12)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
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
        collectionView.semanticContentAttribute = attr
        self.items = items
        collectionView.reloadData()
    }

    func scrollToTop() {
        collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: true)
    }

    // MARK: UICollectionView

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NLCell.reuseId, for: indexPath) as! NLCell
        cell.configure(items[indexPath.item])
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
