import UIKit
import Capacitor

/// The HOME screen as a REAL native iOS screen: a `UICollectionView` with glass cells (`UIGlassEffect` on
/// iOS 26, system material before), the iPhone's own edit mode (long press -> gentle wiggle, minus badges,
/// drag a cell to move it, corner grip to resize, glass + and check pills) and native scrolling.
///
/// The web app stays the single source of truth for WHAT is on the home (texts, order, sizes, translations):
/// index.html extracts a spec from its own rendered home (`homeNativePush`) and sends it through
/// `NativeHome.show`; every tap / layout change comes back through `window.NativeHomeHost.*`.
/// Web / PWA keep the HTML home. Not compile-verified in Xcode.

/// Set false to drop the iPhone-style wiggle in edit mode (everything else stays).
private let nhWiggleEnabled = true

struct NHRow {
    let a: String
    let b: String
    let highlight: Bool
}

struct NHItem {
    var id: String
    var kind: String          // tile | stat | hero | banner | text | dedication | tikkunei | zmanim | social | spacer
    var size: String
    var sizes: [String]
    var givenWide: Bool
    var title: String
    var subtitle: String
    var lines: [String]
    var rows: [NHRow]
    var images: [String]
    var number: String
    var badge: String
    var color: UIColor
    var done: Bool
    var removable: Bool
    var movable: Bool
    var resizable: Bool

    var isSpacer: Bool { kind == "spacer" }

    /// Tiles and stat cards change width with their size; everything else is always full width.
    var wide: Bool {
        switch kind {
        case "tile": return size == "l"
        case "stat": return size == "m" || size == "l"
        case "spacer": return false
        default: return true
        }
    }
}

extension UIColor {
    static func nhHex(_ hex: String) -> UIColor {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return UIColor(red: 0.83, green: 0.69, blue: 0.37, alpha: 1) }
        return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

extension NHItem {
    init(dict d: [String: Any]) {
        let rowsRaw = (d["rows"] as? [[String: Any]]) ?? []
        self.init(
            id: d["id"] as? String ?? "",
            kind: d["kind"] as? String ?? "tile",
            size: d["size"] as? String ?? "s",
            sizes: (d["sizes"] as? [String]) ?? [],
            givenWide: d["wide"] as? Bool ?? false,
            title: d["title"] as? String ?? "",
            subtitle: d["subtitle"] as? String ?? "",
            lines: (d["lines"] as? [String]) ?? [],
            rows: rowsRaw.map { NHRow(a: $0["a"] as? String ?? "", b: $0["b"] as? String ?? "", highlight: $0["hl"] as? Bool ?? false) },
            images: (d["images"] as? [String]) ?? [],
            number: d["number"] as? String ?? "",
            badge: d["badge"] as? String ?? "",
            color: UIColor.nhHex(d["color"] as? String ?? ""),
            done: d["done"] as? Bool ?? false,
            removable: d["removable"] as? Bool ?? true,
            movable: d["movable"] as? Bool ?? true,
            resizable: d["resizable"] as? Bool ?? false
        )
    }
}

/// The small curved corner grip drawn like the one on an iPhone widget (no arrows).
final class NHGrip: UIView {
    private let grip = CAShapeLayer()
    var rtl = false { didSet { setNeedsLayout() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        let r: CGFloat = 20
        let path = UIBezierPath()
        path.move(to: CGPoint(x: r, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: r), controlPoint: CGPoint(x: r, y: r))
        grip.path = path.cgPath
        grip.fillColor = UIColor.clear.cgColor
        grip.strokeColor = UIColor.white.cgColor
        grip.lineWidth = 4
        grip.lineCap = .round
        grip.shadowColor = UIColor.black.cgColor
        grip.shadowOpacity = 0.45
        grip.shadowRadius = 2
        grip.shadowOffset = .zero
        grip.frame = CGRect(x: 0, y: 0, width: r, height: r)
        layer.addSublayer(grip)
        accessibilityLabel = "Resize"
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let r: CGFloat = 20
        grip.frame = CGRect(x: rtl ? 8 : bounds.width - r - 8, y: bounds.height - r - 8, width: r, height: r)
        grip.setAffineTransform(rtl ? CGAffineTransform(scaleX: -1, y: 1) : .identity)
    }
}

/// A view whose layer IS the gradient, so it always fills its bounds (a sublayer sized in layoutSubviews was
/// left at a stale partial frame, which showed as a half-coloured card).
final class NHGradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    var gradient: CAGradientLayer { layer as! CAGradientLayer }
    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class NHCell: UICollectionViewCell {
    static let reuseId = "NHCell"

    private let glass: UIVisualEffectView
    private let tintView = NHGradientView()
    private let accentView = UIView()
    private let dashLayer = CAShapeLayer()
    private let stack = UIStackView()
    let minusButton = UIButton(type: .custom)
    let grip = NHGrip()

    var onSub: ((Int) -> Void)?
    var onMinus: (() -> Void)?
    var onResizePan: ((UIPanGestureRecognizer) -> Void)?
    private(set) var item: NHItem?
    private var rtl = true

    override init(frame: CGRect) {
        if #available(iOS 26.0, *) {
            glass = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        }
        super.init(frame: frame)
        clipsToBounds = false
        contentView.clipsToBounds = false

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
        accentView.translatesAutoresizingMaskIntoConstraints = false
        accentView.isUserInteractionEnabled = false
        glass.contentView.addSubview(tintView)
        glass.contentView.addSubview(accentView)
        NSLayoutConstraint.activate([
            tintView.topAnchor.constraint(equalTo: glass.contentView.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor),
            tintView.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor),
            accentView.topAnchor.constraint(equalTo: glass.contentView.topAnchor),
            accentView.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor),
            accentView.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor),
            accentView.heightAnchor.constraint(equalToConstant: 2.5),
        ])

        dashLayer.fillColor = UIColor.clear.cgColor
        dashLayer.strokeColor = UIColor.secondaryLabel.cgColor
        dashLayer.lineWidth = 2
        dashLayer.lineDashPattern = [7, 6]
        dashLayer.isHidden = true
        contentView.layer.addSublayer(dashLayer)

        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)   // on the cell itself (not inside the glass) so frameless text still shows
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),
        ])

        // minus badge (top corner on the reading-direction start side), like the iPhone's
        var cfg = UIButton.Configuration.filled()
        cfg.image = UIImage(systemName: "minus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .heavy))
        cfg.baseBackgroundColor = UIColor(white: 0.23, alpha: 0.9)
        cfg.baseForegroundColor = .white
        cfg.cornerStyle = .capsule
        minusButton.configuration = cfg
        minusButton.isHidden = true
        minusButton.addAction(UIAction { [weak self] _ in self?.onMinus?() }, for: .touchUpInside)
        minusButton.accessibilityLabel = "Remove"
        contentView.addSubview(minusButton)

        grip.isHidden = true
        grip.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(gripPanned(_:))))
        contentView.addSubview(grip)

        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        layer.removeAnimation(forKey: "wiggle")
        alpha = 1
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dashLayer.frame = contentView.bounds
        dashLayer.path = UIBezierPath(roundedRect: contentView.bounds.insetBy(dx: 1, dy: 1), cornerRadius: 24).cgPath
        let m: CGFloat = 28
        let cx = rtl ? contentView.bounds.maxX - 4 : contentView.bounds.minX + 4
        minusButton.frame = CGRect(x: cx - m / 2 - 2, y: -4, width: m, height: m)
        let g: CGFloat = 56
        grip.rtl = rtl
        grip.frame = CGRect(x: rtl ? 0 : contentView.bounds.width - g, y: contentView.bounds.height - g, width: g, height: g)
    }

    @objc private func gripPanned(_ g: UIPanGestureRecognizer) { onResizePan?(g) }

    // MARK: content

    private func clearStack() {
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 4
    }

    private func label(_ text: String, _ style: UIFont.TextStyle, _ weight: UIFont.Weight, _ color: UIColor = .label,
                       lines: Int = 1, scale: CGFloat = 1, center: Bool = false) -> UILabel {
        let l = UILabel()
        l.text = text
        l.numberOfLines = lines
        l.textColor = color
        l.adjustsFontForContentSizeCategory = true
        l.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize * scale, weight: weight)
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.75
        l.textAlignment = center ? .center : (rtl ? .right : .left)
        return l
    }

    private var gold: UIColor { UIColor(red: 0.83, green: 0.69, blue: 0.37, alpha: 1) }

    func configure(_ it: NHItem, editing: Bool, rtl: Bool, logo: UIImage?) {
        item = it
        self.rtl = rtl
        clearStack()
        let isSpacer = it.isSpacer
        glass.isHidden = isSpacer
        dashLayer.isHidden = !(isSpacer && editing)
        // dedications are plain text (no card, no frame)
        let plain = it.kind == "dedication" || it.kind == "social"
        glass.isHidden = isSpacer || plain
        tintView.gradient.colors = [it.color.withAlphaComponent(0.42).cgColor, it.color.withAlphaComponent(0.12).cgColor]
        accentView.backgroundColor = it.color.withAlphaComponent(0.9)
        accentView.isHidden = !(it.kind == "tile" || it.kind == "stat" || it.kind == "row")
        minusButton.isHidden = !(editing && it.removable)
        grip.isHidden = !(editing && it.resizable)

        switch it.kind {
        case "tile":
            stack.addArrangedSubview(label((it.done ? "✓ " : "") + it.title, .headline, .semibold, lines: 2, scale: it.wide ? 1.25 : 1.05))
            if !it.subtitle.isEmpty {
                stack.addArrangedSubview(label(it.subtitle, .subheadline, .regular, .secondaryLabel, lines: it.wide ? 3 : 2))
            }
        case "row":
            stack.axis = .horizontal
            stack.alignment = .center
            stack.spacing = 10
            if !it.badge.isEmpty {
                let lead = UIImageView(image: UIImage(systemName: it.badge))
                lead.tintColor = .secondaryLabel
                lead.setContentHuggingPriority(.required, for: .horizontal)
                stack.addArrangedSubview(lead)
            }
            let v = UIStackView(arrangedSubviews: [label((it.done ? "✓ " : "") + it.title, .headline, .semibold, lines: 2)])
            v.axis = .vertical
            v.spacing = 2
            if !it.subtitle.isEmpty { v.addArrangedSubview(label(it.subtitle, .subheadline, .regular, .secondaryLabel, lines: 2)) }
            stack.addArrangedSubview(v)
            let rowChev = UIImageView(image: UIImage(systemName: "chevron.forward"))
            rowChev.tintColor = .tertiaryLabel
            rowChev.setContentHuggingPriority(.required, for: .horizontal)
            stack.addArrangedSubview(rowChev)
        case "stat":
            stack.axis = .horizontal
            stack.alignment = .center
            stack.spacing = 10
            let v = UIStackView(arrangedSubviews: [
                label(it.number.isEmpty ? "–" : it.number, .title2, .heavy, scale: it.wide ? 1.4 : 1),
                label(it.title, .caption1, .regular, .secondaryLabel),
            ])
            v.axis = .vertical
            v.spacing = 0
            stack.addArrangedSubview(v)
            let badge = UIImageView(image: UIImage(systemName: it.badge.isEmpty ? "person.2.fill" : it.badge,
                                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: it.wide ? 26 : 18, weight: .semibold)))
            badge.tintColor = it.badge.contains("dot") ? .systemGreen : gold
            badge.setContentHuggingPriority(.required, for: .horizontal)
            stack.addArrangedSubview(badge)
        case "hero":
            stack.alignment = .center
            stack.spacing = 6
            if let logo = logo {
                let iv = UIImageView(image: logo)
                iv.contentMode = .scaleAspectFit
                iv.heightAnchor.constraint(equalToConstant: 118).isActive = true
                stack.addArrangedSubview(iv)
            }
            if !it.title.isEmpty { stack.addArrangedSubview(label(it.title, .subheadline, .regular, .secondaryLabel, center: true)) }
            if !it.subtitle.isEmpty { stack.addArrangedSubview(label(it.subtitle, .title2, .bold, gold, lines: 2, center: true)) }
            if let g = it.lines.first, !g.isEmpty { stack.addArrangedSubview(label(g, .footnote, .regular, .secondaryLabel, lines: 2, center: true)) }
            if it.lines.count > 1 { stack.addArrangedSubview(label("● " + it.lines[1], .footnote, .medium, gold, lines: 2, center: true)) }
        case "banner":
            stack.spacing = 8
            for (i, line) in it.lines.enumerated() {
                let l = label(line, .subheadline, .medium, lines: 3)
                l.isUserInteractionEnabled = true
                l.tag = i
                l.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(subTapped(_:))))
                stack.addArrangedSubview(l)
            }
        case "tikkunei":
            stack.axis = .horizontal
            stack.alignment = .center
            let v = UIStackView(arrangedSubviews: [
                label(it.title, .caption1, .semibold, gold),
                label((it.done ? "✓ " : "") + it.subtitle, .headline, .semibold, lines: 2),
            ])
            v.axis = .vertical
            v.spacing = 2
            stack.addArrangedSubview(v)
            let chev = UIImageView(image: UIImage(systemName: "chevron.forward"))
            chev.tintColor = .tertiaryLabel
            chev.setContentHuggingPriority(.required, for: .horizontal)
            stack.addArrangedSubview(chev)
        case "zmanim":
            stack.spacing = 6
            stack.addArrangedSubview(label(it.title, .subheadline, .bold, gold))
            for r in it.rows {
                let a = label(r.a, .footnote, r.highlight ? .bold : .regular, r.highlight ? gold : .label)
                let b = label(r.b, .footnote, r.highlight ? .bold : .regular, r.highlight ? gold : .secondaryLabel)
                b.textAlignment = rtl ? .left : .right
                b.setContentHuggingPriority(.required, for: .horizontal)
                let row = UIStackView(arrangedSubviews: [a, b])
                row.axis = .horizontal
                stack.addArrangedSubview(row)
            }
        case "dedication":
            stack.spacing = 6
            stack.addArrangedSubview(label(it.title, .caption1, .semibold, gold, center: true))
            if !it.subtitle.isEmpty { stack.addArrangedSubview(label(it.subtitle, .subheadline, .regular, .secondaryLabel, lines: 6, center: true)) }
            if let f = it.lines.first, !f.isEmpty { stack.addArrangedSubview(label(f, .caption2, .regular, .tertiaryLabel, center: true)) }
        case "text":
            stack.spacing = 4
            for line in it.lines { stack.addArrangedSubview(label(line, .subheadline, .medium, .label, lines: 3, center: true)) }
        case "social":
            stack.axis = .horizontal
            stack.alignment = .center
            stack.distribution = .equalCentering
            stack.spacing = it.size == "m" ? 30 : 18
            // the ORIGINAL icons (rasterized from the app's own SVGs by the web layer) - never SF Symbol stand-ins
            let big = it.size == "m"
            let box: CGFloat = big ? 52 : 32
            let glyph: CGFloat = big ? 40 : 24
            for (i, key) in it.lines.enumerated() {
                let b = UIButton(type: .custom)
                if i < it.images.count, let data = Data(base64Encoded: it.images[i]), let img = UIImage(data: data, scale: 3) {
                    b.setImage(img.withRenderingMode(.alwaysOriginal), for: .normal)
                }
                b.imageView?.contentMode = .scaleAspectFit
                b.contentEdgeInsets = UIEdgeInsets(top: (box - glyph) / 2, left: (box - glyph) / 2, bottom: (box - glyph) / 2, right: (box - glyph) / 2)
                b.alpha = big ? 1 : 0.8
                b.tag = i
                b.accessibilityLabel = key
                b.addTarget(self, action: #selector(subTapped(_:)), for: .touchUpInside)
                b.widthAnchor.constraint(equalToConstant: box).isActive = true
                b.heightAnchor.constraint(equalToConstant: box).isActive = true
                stack.addArrangedSubview(b)
            }
        default:
            break
        }
        applyEditing(editing)
    }

    @objc private func subTapped(_ sender: Any) {
        if let g = sender as? UIGestureRecognizer, let v = g.view { onSub?(v.tag) }
        else if let b = sender as? UIButton { onSub?(b.tag) }
    }

    func applyEditing(_ editing: Bool) {
        layer.removeAnimation(forKey: "wiggle")
        guard editing, nhWiggleEnabled, let it = item, it.movable, !it.isSpacer else { return }
        let a = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        a.values = [-0.011, 0.011, -0.011]
        a.keyTimes = [0, 0.5, 1]
        a.duration = 0.2 + Double.random(in: 0...0.04)
        a.repeatCount = .infinity
        a.timeOffset = Double.random(in: 0...0.2)
        layer.add(a, forKey: "wiggle")
    }

    override var isHighlighted: Bool {
        didSet {
            guard let it = item, !it.isSpacer else { return }
            UIView.animate(withDuration: 0.18, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
                self.contentView.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}

final class NativeHomeView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var bottomInset: (() -> CGFloat)?
    var js: ((String) -> Void)?
    var onCollapseChange: ((Bool) -> Void)?
    private let collapseTracker = ScrollCollapseTracker()

    let collectionView: UICollectionView
    private(set) var items: [NHItem] = []
    private var editing = false
    private var rtl = true
    private var logo: UIImage?
    private var spacerPool: [String] = []
    private var screenSignature = ""

    private let addPill = UIButton(type: .custom)
    private let donePill = UIButton(type: .custom)
    private var enterEditLP: UILongPressGestureRecognizer!
    private var dragLP: UILongPressGestureRecognizer!

    private var dragIndex: Int?
    private var snapshot: UIView?
    private var dragOffset = CGPoint.zero
    private var link: CADisplayLink?
    private var resizeAccum: [String: CGFloat] = [:]

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.contentInsetAdjustmentBehavior = .never   // the bottom inset below already includes the safe area
        collectionView.showsVerticalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(NHCell.self, forCellWithReuseIdentifier: NHCell.reuseId)
        addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        enterEditLP = UILongPressGestureRecognizer(target: self, action: #selector(enterEditPressed(_:)))
        enterEditLP.minimumPressDuration = 0.45
        collectionView.addGestureRecognizer(enterEditLP)
        dragLP = UILongPressGestureRecognizer(target: self, action: #selector(dragged(_:)))
        dragLP.minimumPressDuration = 0.12
        dragLP.isEnabled = false
        collectionView.addGestureRecognizer(dragLP)

        setupPill(addPill, symbol: "plus", label: "Add") { [weak self] in self?.js?("window.NativeHomeEditHost && window.NativeHomeEditHost.add()") }
        setupPill(donePill, symbol: "checkmark", label: "Done") { [weak self] in self?.js?("window.NativeHomeEditHost && window.NativeHomeEditHost.done()") }
        NSLayoutConstraint.activate([
            addPill.leftAnchor.constraint(equalTo: leftAnchor, constant: 16),
            donePill.rightAnchor.constraint(equalTo: rightAnchor, constant: -16),
            addPill.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            donePill.topAnchor.constraint(equalTo: topAnchor, constant: 6),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupPill(_ b: UIButton, symbol: String, label: String, action: @escaping () -> Void) {
        var cfg: UIButton.Configuration
        if #available(iOS 26.0, *) { cfg = UIButton.Configuration.glass() } else { cfg = UIButton.Configuration.gray() }
        cfg.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        cfg.cornerStyle = .capsule
        cfg.baseForegroundColor = .label
        b.configuration = cfg
        b.translatesAutoresizingMaskIntoConstraints = false
        b.isHidden = true
        b.accessibilityLabel = label
        b.addAction(UIAction { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }, for: .touchUpInside)
        addSubview(b)
        NSLayoutConstraint.activate([
            b.widthAnchor.constraint(equalToConstant: 68),
            b.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = bottomInset?() ?? 100
        if abs(collectionView.contentInset.bottom - b) > 0.5 {
            collectionView.contentInset.bottom = b
            collectionView.verticalScrollIndicatorInsets.bottom = b
        }
        bringSubviewToFront(addPill)
        bringSubviewToFront(donePill)
    }

    // MARK: data

    func setLogo(_ image: UIImage?) { logo = image }

    func show(items newItems: [NHItem], editing: Bool, canEdit: Bool, rtl: Bool, isDark: Bool, pool: [String]) {
        overrideUserInterfaceStyle = isDark ? .dark : .light
        let attr: UISemanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        semanticContentAttribute = attr
        collectionView.semanticContentAttribute = attr
        self.rtl = rtl
        spacerPool = pool
        // never rebuild while a finger is dragging a cell
        if dragIndex != nil { return }
        let wasEditing = self.editing
        self.editing = editing
        let newSig = newItems.map { $0.id + $0.kind + $0.title }.joined(separator: "|")
        let isNewScreen = newSig != screenSignature
        screenSignature = newSig
        items = newItems
        if isNewScreen { collapseTracker.reset() }
        if editing { normalizeSpacers() }
        enterEditLP.isEnabled = !editing && canEdit
        dragLP.isEnabled = editing
        addPill.isHidden = !editing
        donePill.isHidden = !editing
        let top: CGFloat = editing ? 58 : 0
        if abs(collectionView.contentInset.top - top) > 0.5 {
            let atTop = collectionView.contentOffset.y <= -collectionView.contentInset.top + 1
            collectionView.contentInset.top = top
            if atTop { collectionView.contentOffset.y = -top }
        }
        collectionView.reloadData()
        if isNewScreen { collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.contentInset.top), animated: false) }
        if wasEditing != editing { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    }

    func updateNumbers(_ map: [String: String]) {
        for i in items.indices {
            if let n = map[items[i].id], items[i].number != n {
                items[i].number = n
                if let cell = collectionView.cellForItem(at: IndexPath(item: i, section: 0)) as? NHCell {
                    cell.configure(items[i], editing: editing, rtl: rtl, logo: logo)
                }
            }
        }
    }

    func scrollToTop() {
        collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: true)
    }

    // MARK: UIScrollView

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard dragIndex == nil else { return }
        let y = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            + scrollView.adjustedContentInset.top + scrollView.adjustedContentInset.bottom
        if collapseTracker.update(y: y, maxY: maxY) {
            onCollapseChange?(collapseTracker.collapsed)
        }
    }

    // MARK: layout

    private func width(of it: NHItem) -> CGFloat {
        let content = collectionView.bounds.width - 32
        return it.wide ? content : floor((content - 12) / 2)
    }

    private func height(of it: NHItem, width w: CGFloat) -> CGFloat {
        func textH(_ s: String, _ style: UIFont.TextStyle, _ weight: UIFont.Weight, _ width: CGFloat) -> CGFloat {
            if s.isEmpty { return 0 }
            let f = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: weight)
            return ceil((s as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                     options: .usesLineFragmentOrigin, attributes: [.font: f], context: nil).height)
        }
        // fixed card heights grow with Dynamic Type so larger text is never clipped
        let k = min(1.6, max(1, UIFont.preferredFont(forTextStyle: .body).pointSize / 17))
        func scaled(_ v: CGFloat) -> CGFloat { ceil(v * k) }
        switch it.kind {
        case "tile": return scaled(it.wide ? 132 : (it.size == "m" ? 112 : 92))
        case "stat": return scaled(it.wide ? 96 : 68)
        case "spacer": return 92
        case "hero": return 118 + 24 + 34 + 22 + 22 + 36
        case "banner": return scaled(CGFloat(max(1, it.lines.count)) * 40 + 24)
        case "tikkunei": return scaled(78)
        case "row": return scaled(it.subtitle.isEmpty ? 64 : 80)
        case "zmanim": return scaled(56 + CGFloat(it.rows.count) * 26)
        case "text": return scaled(CGFloat(max(1, it.lines.count)) * 28 + 28)
        case "social": return it.size == "m" ? 96 : 68
        case "dedication":
            return 28 + 24 + textH(it.subtitle, .subheadline, .regular, w - 32) + (it.lines.first?.isEmpty == false ? 24 : 0) + 20
        default: return 92
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let it = items[indexPath.item]
        let w = width(of: it)
        return CGSize(width: w, height: height(of: it, width: w))
    }

    // MARK: UICollectionView

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NHCell.reuseId, for: indexPath) as! NHCell
        let it = items[indexPath.item]
        cell.configure(it, editing: editing, rtl: rtl, logo: logo)
        cell.onSub = { [weak self] idx in self?.js?("window.NativeHomeHost && window.NativeHomeHost.sub('\(it.id)',\(idx))") }
        cell.onMinus = { [weak self] in self?.js?("window.NativeHomeEditHost && window.NativeHomeEditHost.minus('\(it.id)')") }
        cell.onResizePan = { [weak self] g in self?.resizePanned(g, id: it.id) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let c = cell as? NHCell else { return }
        c.alpha = (dragIndex == indexPath.item) ? 0 : 1
        c.applyEditing(editing)
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        !editing && !items[indexPath.item].isSpacer
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let it = items[indexPath.item]
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        js?("window.NativeHomeHost && window.NativeHomeHost.open('\(it.id)')")
    }

    // MARK: edit mode

    @objc private func enterEditPressed(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, !editing else { return }
        js?("window.NativeHomeHost && window.NativeHomeHost.enterEdit()")
    }

    /// Keeps every half-width row complete: an odd run before a full-width item (or at the end) gets an
    /// explicit empty cell, and two empty cells that would make a blank row are dropped.
    private func normalizeSpacers() {
        var out: [NHItem] = []
        var col = 0
        func makeSpacer() -> NHItem? {
            let used = Set(items.filter { $0.isSpacer }.map { $0.id } + out.filter { $0.isSpacer }.map { $0.id })
            guard let id = spacerPool.first(where: { !used.contains($0) }) else { return nil }
            return NHItem(id: id, kind: "spacer", size: "s", sizes: [], givenWide: false, title: "", subtitle: "", lines: [],
                          rows: [], images: [], number: "", badge: "", color: .clear, done: false, removable: true, movable: true, resizable: false)
        }
        func push(_ it: NHItem) {
            if it.isSpacer, col == 1, let last = out.last, last.isSpacer {
                out.removeLast(); col = 0; return
            }
            out.append(it)
            col = it.wide ? 0 : (col ^ 1)
        }
        for it in items {
            if it.wide, col == 1, let sp = makeSpacer() { push(sp) }
            push(it)
        }
        if col == 1, let sp = makeSpacer() { push(sp) }
        items = out
    }

    /// Reports the layout back to the web app (trailing empty cells are never saved).
    private func commit() {
        var list = items
        while let last = list.last, last.isSpacer { list.removeLast() }
        let payload = list.map { ["id": $0.id, "size": $0.size] }
        if let data = try? JSONSerialization.data(withJSONObject: payload), let s = String(data: data, encoding: .utf8) {
            js?("window.NativeHomeHost && window.NativeHomeHost.layout(\(s))")
        }
    }

    // MARK: drag to move

    @objc private func dragged(_ g: UILongPressGestureRecognizer) {
        let p = g.location(in: collectionView)
        switch g.state {
        case .began:
            guard let ip = collectionView.indexPathForItem(at: p), items[ip.item].movable,
                  let cell = collectionView.cellForItem(at: ip) else {
                g.isEnabled = false; g.isEnabled = true; return
            }
            dragIndex = ip.item
            let snap = cell.snapshotView(afterScreenUpdates: false) ?? UIView()
            snap.frame = cell.frame
            snap.layer.shadowColor = UIColor.black.cgColor
            snap.layer.shadowOpacity = 0.35
            snap.layer.shadowRadius = 14
            snap.layer.shadowOffset = CGSize(width: 0, height: 8)
            collectionView.addSubview(snap)
            snapshot = snap
            dragOffset = CGPoint(x: p.x - cell.center.x, y: p.y - cell.center.y)
            cell.alpha = 0
            UIView.animate(withDuration: 0.18) { snap.transform = CGAffineTransform(scaleX: 1.05, y: 1.05) }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            let l = CADisplayLink(target: self, selector: #selector(tick))
            l.add(to: .main, forMode: .common)
            link = l
        case .changed:
            updateDrag(at: p)
        case .ended, .cancelled, .failed:
            endDrag()
        default:
            break
        }
    }

    private func updateDrag(at p: CGPoint) {
        guard let snap = snapshot, let from = dragIndex else { return }
        snap.center = CGPoint(x: p.x - dragOffset.x, y: p.y - dragOffset.y)
        guard let ip = collectionView.indexPathForItem(at: p), ip.item != from,
              let attrs = collectionView.layoutAttributesForItem(at: ip) else { return }
        // only the middle of a neighbour counts, so cells never flip-flop
        guard attrs.frame.insetBy(dx: attrs.frame.width * 0.22, dy: attrs.frame.height * 0.22).contains(p),
              items[ip.item].movable else { return }
        move(from, to: ip.item)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func move(_ a: Int, to b: Int) {
        guard a != b, a < items.count, b < items.count else { return }
        let src = items[a], dst = items[b]
        let swapSpacer = dst.isSpacer && !src.wide
        let moved = items.remove(at: a)
        items.insert(moved, at: b)
        collectionView.performBatchUpdates({
            self.collectionView.moveItem(at: IndexPath(item: a, section: 0), to: IndexPath(item: b, section: 0))
        })
        if swapSpacer {
            // the empty cell takes the dragged cell's old place - nothing slides up to fill it
            let s = b > a ? b - 1 : b + 1
            if s >= 0, s < items.count, items[s].isSpacer {
                let sp = items.remove(at: s)
                items.insert(sp, at: a)
                collectionView.performBatchUpdates({
                    self.collectionView.moveItem(at: IndexPath(item: s, section: 0), to: IndexPath(item: a, section: 0))
                })
            }
        }
        dragIndex = items.firstIndex { $0.id == src.id }
        if let i = dragIndex, let cell = collectionView.cellForItem(at: IndexPath(item: i, section: 0)) { cell.alpha = 0 }
    }

    @objc private func tick() {
        guard snapshot != nil else { return }
        let p = dragLP.location(in: collectionView)
        let visibleTop = collectionView.contentOffset.y + collectionView.adjustedContentInset.top
        let visibleBottom = collectionView.contentOffset.y + collectionView.bounds.height - collectionView.adjustedContentInset.bottom
        var dy: CGFloat = 0
        let band: CGFloat = 70
        if p.y < visibleTop + band { dy = -min(14, (visibleTop + band - p.y) / 6 + 1) }
        else if p.y > visibleBottom - band { dy = min(14, (p.y - (visibleBottom - band)) / 6 + 1) }
        if dy != 0 {
            let minY = -collectionView.adjustedContentInset.top
            let maxY = max(minY, collectionView.contentSize.height - collectionView.bounds.height + collectionView.adjustedContentInset.bottom)
            collectionView.contentOffset.y = min(max(collectionView.contentOffset.y + dy, minY), maxY)
            updateDrag(at: p)
        }
    }

    private func endDrag() {
        link?.invalidate()
        link = nil
        guard let snap = snapshot, let i = dragIndex else { snapshot?.removeFromSuperview(); snapshot = nil; dragIndex = nil; return }
        let target = collectionView.layoutAttributesForItem(at: IndexPath(item: i, section: 0))?.frame ?? snap.frame
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseOut, animations: {
            snap.transform = .identity
            snap.frame = target
        }, completion: { _ in
            snap.removeFromSuperview()
            if let cell = self.collectionView.cellForItem(at: IndexPath(item: i, section: 0)) { cell.alpha = 1 }
            self.snapshot = nil
            self.dragIndex = nil
            self.normalizeSpacers()
            self.collectionView.reloadData()
            self.commit()
        })
    }

    // MARK: resize with the corner grip

    private func resizePanned(_ g: UIPanGestureRecognizer, id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        switch g.state {
        case .began:
            resizeAccum[id] = 0
        case .changed:
            let t = g.translation(in: collectionView)
            let outward = (rtl ? -t.x : t.x) + t.y          // down and outward = bigger
            var it = items[idx]
            guard it.sizes.count >= 2 else { return }
            let big = it.sizes[1], small = it.sizes[0]
            if outward > 34, it.size == small { it.size = big }
            else if outward < -34, it.size == big { it.size = small }
            else { return }
            g.setTranslation(.zero, in: collectionView)
            items[idx] = it
            UISelectionFeedbackGenerator().selectionChanged()
            collectionView.collectionViewLayout.invalidateLayout()
            UIView.animate(withDuration: 0.25) { self.collectionView.layoutIfNeeded() }
            if let cell = collectionView.cellForItem(at: IndexPath(item: idx, section: 0)) as? NHCell {
                cell.configure(it, editing: editing, rtl: rtl, logo: logo)
            }
        case .ended, .cancelled, .failed:
            resizeAccum[id] = nil
            normalizeSpacers()
            collectionView.reloadData()
            commit()
        default:
            break
        }
    }
}

// MARK: - Capacitor bridge

@objc(NativeHomeBridge)
public class NativeHomeBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeHomeBridge"
    public let jsName = "NativeHome"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "show", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hide", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setNumbers", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setLogo", returnType: CAPPluginReturnPromise),
    ]

    static weak var activeController: MainViewController?

    @objc func show(_ call: CAPPluginCall) {
        let rtl = call.getBool("isRTL") ?? true
        let isDark = call.getBool("isDark") ?? true
        let editing = call.getBool("editing") ?? false
        let canEdit = call.getBool("canEdit") ?? false
        let pool = (call.getArray("spacerPool") as? [String]) ?? []
        var items: [NHItem] = []
        for case let d as [String: Any] in (call.getArray("items") ?? []) { items.append(NHItem(dict: d)) }
        DispatchQueue.main.async {
            NativeHomeBridge.activeController?.showNativeHome(items: items, editing: editing, canEdit: canEdit, rtl: rtl, isDark: isDark, pool: pool)
        }
        call.resolve()
    }

    @objc func hide(_ call: CAPPluginCall) {
        DispatchQueue.main.async { NativeHomeBridge.activeController?.hideNativeHome() }
        call.resolve()
    }

    @objc func setNumbers(_ call: CAPPluginCall) {
        var map: [String: String] = [:]
        for case let d as [String: Any] in (call.getArray("items") ?? []) {
            if let id = d["id"] as? String, let n = d["number"] as? String { map[id] = n }
        }
        DispatchQueue.main.async { NativeHomeBridge.activeController?.updateNativeHomeNumbers(map) }
        call.resolve()
    }

    @objc func setLogo(_ call: CAPPluginCall) {
        var s = call.getString("data") ?? ""
        if let r = s.range(of: "base64,") { s = String(s[r.upperBound...]) }
        let image = Data(base64Encoded: s).flatMap { UIImage(data: $0) }
        DispatchQueue.main.async { NativeHomeBridge.activeController?.setNativeHomeLogo(image) }
        call.resolve()
    }
}
