import UIKit
import Capacitor

/// The Calendar screen as REAL Apple UIKit - not a web look-alike:
///  - `UICalendarView` (Apple's own calendar month grid, iOS 16+) driven by a real Hebrew
///    (`Calendar(identifier: .hebrew)`) or Gregorian calendar, with Apple's selection + today
///    highlight + decoration dots for holidays;
///  - `UISegmentedControl` for Hebrew / Gregorian;
///  - `UIButton.Configuration.glass()` buttons (iOS 26 Liquid Glass) for "jump to date" / "today",
///    with a real `UIDatePicker` sheet for the jump;
///  - a paging `UIScrollView` day pager: swipe sideways to go to the next/previous day (the
///    same paging physics as every Apple app), each page a `UIVisualEffectView` glass card
///    (`UIGlassEffect` on iOS 26, system material before).
/// All day data comes from the web app (single source of truth for zmanim/parsha/holidays):
/// `window.NativeCalendarHost.day(ymd)` / `.events(start,end)` in index.html. On iOS < 16 the
/// bridge reports unsupported and the web calendar is used instead. Not compile-verified in Xcode.

// MARK: - Models

struct NCDayInfo: Decodable {
    struct Portion: Decodable { let label: String; let val: String; let a: Int; let b: Int }
    struct Row: Decodable { let label: String; let time: String; let next: Bool? }
    let ymd: String
    let title: String
    let greg: String
    let events: [String]
    let parashaLabel: String?
    let parasha: String?
    let parashaKey: String?
    let portions: [Portion]
    let loc: String?
    let zmanim: [Row]
    let shabbat: [Row]
    struct Hill: Decodable { let name: String; let sub: String? }
    let hillulot: [Hill]
    let hillulotTitle: String?
    let hillulotFooter: String?
}

/// Rounded inset-grouped container holding Apple's UICalendarView.
final class NCCard: UIView {
    func embed(_ view: UIView, insets: UIEdgeInsets, isDark: Bool) {
        backgroundColor = isDark ? UIColor(red: 0.075, green: 0.105, blue: 0.2, alpha: 1) : UIColor(white: 1, alpha: 0.78)
        if #available(iOS 26.0, *) { cornerConfiguration = .corners(radius: .fixed(26)) } else { layer.cornerRadius = 10 }
        clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            view.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom),
            view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            view.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
        ])
    }
}

// MARK: - Inset-grouped list pieces (same look as the Settings list: UITableView .insetGrouped)

/// One inset-grouped section: optional header above, rounded rows with hairline separators, optional footer below.
final class NCGroup: UIStackView {
    private let box = UIView()
    private let rows = UIStackView()

    init(header: String?, footer: String?, tint: UIColor, isDark: Bool, rtl: Bool) {
        super.init(frame: .zero)
        axis = .vertical
        spacing = 6
        let attr: UISemanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        semanticContentAttribute = attr
        if let h = header, !h.isEmpty {
            let l = UILabel()
            l.text = h.uppercased(with: .current)
            l.numberOfLines = 0
            l.textAlignment = rtl ? .right : .left
            l.textColor = tint
            l.font = UIFont.preferredFont(forTextStyle: .footnote)
            l.adjustsFontForContentSizeCategory = true
            let wrap = UIView(); l.translatesAutoresizingMaskIntoConstraints = false; wrap.addSubview(l)
            NSLayoutConstraint.activate([
                l.topAnchor.constraint(equalTo: wrap.topAnchor), l.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
                l.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 16), l.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -16),
            ])
            addArrangedSubview(wrap)
        }
        box.backgroundColor = isDark ? UIColor(red: 0.075, green: 0.105, blue: 0.2, alpha: 1) : UIColor(white: 1, alpha: 0.78)
        if #available(iOS 26.0, *) { box.cornerRadius26() } else { box.layer.cornerRadius = 10 }
        box.clipsToBounds = true
        rows.axis = .vertical
        rows.semanticContentAttribute = attr
        rows.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: box.topAnchor), rows.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            rows.leadingAnchor.constraint(equalTo: box.leadingAnchor), rows.trailingAnchor.constraint(equalTo: box.trailingAnchor),
        ])
        addArrangedSubview(box)
        if let f = footer, !f.isEmpty {
            let l = UILabel()
            l.text = f; l.numberOfLines = 0; l.textColor = .secondaryLabel; l.textAlignment = rtl ? .right : .left
            l.font = UIFont.preferredFont(forTextStyle: .footnote); l.adjustsFontForContentSizeCategory = true
            let wrap = UIView(); l.translatesAutoresizingMaskIntoConstraints = false; wrap.addSubview(l)
            NSLayoutConstraint.activate([
                l.topAnchor.constraint(equalTo: wrap.topAnchor), l.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
                l.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 16), l.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -16),
            ])
            addArrangedSubview(wrap)
        }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func addRow(_ row: UIView) {
        if !rows.arrangedSubviews.isEmpty {
            let sep = UIView()
            sep.backgroundColor = UIColor.separator.withAlphaComponent(0.6)
            sep.translatesAutoresizingMaskIntoConstraints = false
            sep.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
            let holder = UIView(); holder.addSubview(sep)
            NSLayoutConstraint.activate([
                sep.topAnchor.constraint(equalTo: holder.topAnchor), sep.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
                sep.leadingAnchor.constraint(equalTo: holder.leadingAnchor, constant: 16), sep.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
            ])
            rows.addArrangedSubview(holder)
        }
        rows.addArrangedSubview(row)
    }
}

private extension UIView {
    @available(iOS 26.0, *)
    func cornerRadius26() { cornerConfiguration = .corners(radius: .fixed(26)) }
}

// MARK: - One day's detail page (native grouped list)

final class NCDayPage: UIView {
    var onPortion: ((Int, Int) -> Void)?
    var onShare: (() -> Void)?
    var onParasha: ((String) -> Void)?
    var tint: UIColor = .systemYellow { didSet { tintColor = tint } }
    var isDark = true

    private let stack = UIStackView()
    private var isRTL = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .vertical
        stack.spacing = 22
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func label(_ text: String, style: UIFont.TextStyle, weight: UIFont.Weight = .regular,
                       color: UIColor = .label, align: NSTextAlignment = .natural) -> UILabel {
        let l = UILabel()
        l.text = text
        l.numberOfLines = 0
        l.textAlignment = align == .natural ? (isRTL ? .right : .left) : align   // never absolute-left in Hebrew (user rule)
        l.semanticContentAttribute = semanticContentAttribute
        l.textColor = color
        let base = UIFont.preferredFont(forTextStyle: style)
        l.font = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
        l.adjustsFontForContentSizeCategory = true
        return l
    }

    /// A standard list row: leading title, trailing value, optional disclosure chevron / tap.
    private func listRow(_ title: String, value: String?, highlight: Bool = false, chevron: Bool = false,
                         icon: String? = nil, tap: (() -> Void)? = nil) -> UIView {
        let name = label(title, style: .body, color: highlight ? tint : .label)
        var parts: [UIView] = []
        if let icon = icon, let img = UIImage(systemName: icon) {
            let iv = UIImageView(image: img); iv.tintColor = tint; iv.contentMode = .scaleAspectFit
            iv.setContentHuggingPriority(.required, for: .horizontal)
            parts.append(iv)
        }
        parts.append(name)
        if let v = value {
            let t = label(v, style: .body, weight: highlight ? .semibold : .regular, color: highlight ? tint : .secondaryLabel, align: .right)
            t.font = UIFont.monospacedDigitSystemFont(ofSize: t.font.pointSize, weight: highlight ? .semibold : .regular)
            t.textAlignment = isRTL ? .left : .right
            t.setContentHuggingPriority(.required, for: .horizontal)
            t.setContentCompressionResistancePriority(.required, for: .horizontal)
            let spacer = UIView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            name.setContentHuggingPriority(.defaultLow, for: .horizontal)
            parts.append(t)
        }
        if chevron {
            let sym = effectiveUserInterfaceLayoutDirection == .rightToLeft ? "chevron.left" : "chevron.right"
            let c = UIImageView(image: UIImage(systemName: sym)); c.tintColor = .tertiaryLabel
            c.setContentHuggingPriority(.required, for: .horizontal)
            parts.append(c)
        }
        let s = UIStackView(arrangedSubviews: parts)
        s.axis = .horizontal; s.spacing = 10; s.alignment = .center
        s.isLayoutMarginsRelativeArrangement = true
        s.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16)
        s.semanticContentAttribute = semanticContentAttribute
        if let tap = tap {
            let g = TapAction(tap)
            s.addGestureRecognizer(g)
        }
        return s
    }

    /// Name on top, the note underneath (long names + notes used to squeeze the name into one letter per line).
    private func stackedRow(_ title: String, sub: String?, icon: String) -> UIView {
        let name = label(title, style: .body, align: .center)
        var texts: [UIView] = [name]
        if let sub = sub, !sub.isEmpty { texts.append(label(sub, style: .footnote, color: .secondaryLabel, align: .center)) }
        let col = UIStackView(arrangedSubviews: texts)
        col.axis = .vertical; col.spacing = 2; col.alignment = .fill
        col.semanticContentAttribute = semanticContentAttribute
        var parts: [UIView] = []
        if let img = UIImage(systemName: icon) {
            let iv = UIImageView(image: img); iv.tintColor = tint; iv.contentMode = .scaleAspectFit
            iv.setContentHuggingPriority(.required, for: .horizontal)
            iv.setContentCompressionResistancePriority(.required, for: .horizontal)
            parts.append(iv)
        }
        parts.append(col)
        let s = UIStackView(arrangedSubviews: parts)
        s.axis = .horizontal; s.spacing = 12; s.alignment = .center
        s.isLayoutMarginsRelativeArrangement = true
        s.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16)
        s.semanticContentAttribute = semanticContentAttribute
        return s
    }

    private final class TapAction: UITapGestureRecognizer {
        private let handler: () -> Void
        init(_ h: @escaping () -> Void) { handler = h; super.init(target: nil, action: nil); addTarget(self, action: #selector(fire)) }
        @objc private func fire() { handler() }
    }

    private func shareButton(title: String) -> UIView {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) { config = UIButton.Configuration.prominentGlass() } else { config = UIButton.Configuration.filled() }
        config.title = title
        config.image = UIImage(systemName: "square.and.arrow.up")
        config.imagePadding = 8
        config.cornerStyle = .capsule
        config.baseBackgroundColor = tint
        config.baseForegroundColor = UIColor(white: 0.12, alpha: 1)
        let b = UIButton(configuration: config)
        b.addAction(UIAction { [weak self] _ in self?.onShare?() }, for: .touchUpInside)
        return b
    }

    func configure(_ info: NCDayInfo?, shareTitle: String, rtl: Bool) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        isRTL = rtl
        semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        stack.semanticContentAttribute = semanticContentAttribute
        guard let info = info else { return }

        // Title block (like a large-title header of a detail screen)
        let head = UIStackView(arrangedSubviews: [
            label(info.title, style: .title2, weight: .bold, align: .center),
            label(info.greg, style: .subheadline, color: .secondaryLabel, align: .center),
        ])
        head.axis = .vertical; head.spacing = 2
        stack.addArrangedSubview(head)

        func group(_ header: String?, footer: String? = nil) -> NCGroup {
            NCGroup(header: header, footer: footer, tint: tint, isDark: isDark, rtl: rtl)
        }

        if !info.events.isEmpty {
            let g = group(nil)
            for e in info.events { g.addRow(listRow(e, value: nil, highlight: true, icon: "star.fill")) }
            stack.addArrangedSubview(g)
        }
        // Zmanim sit right under the calendar (user request); parasha / portions / hillulot follow.
        if !info.shabbat.isEmpty {
            let g = group(nil)
            for z in info.shabbat { g.addRow(listRow(z.label, value: z.time, highlight: true, icon: "flame.fill")) }
            stack.addArrangedSubview(g)
        }
        if !info.zmanim.isEmpty {
            let g = group(info.loc.map { "📍 " + $0 })
            for z in info.zmanim { g.addRow(listRow(z.label, value: z.time, highlight: z.next ?? false)) }
            stack.addArrangedSubview(g)
        }
        if (info.parasha != nil && info.parashaLabel != nil) || !info.portions.isEmpty {
            let g = group(nil)
            if let pl = info.parashaLabel, let pv = info.parasha {
                if let key = info.parashaKey {
                    g.addRow(listRow(pl, value: pv, chevron: true, icon: "book.closed") { [weak self] in self?.onParasha?(key) })
                } else { g.addRow(listRow(pl, value: pv, icon: "book.closed")) }
            }
            for p in info.portions {
                let a = p.a, b = p.b
                g.addRow(listRow(p.label, value: p.val, chevron: true, icon: "text.book.closed") { [weak self] in self?.onPortion?(a, b) })
            }
            stack.addArrangedSubview(g)
        }
        if !info.hillulot.isEmpty {
            let g = group(info.hillulotTitle, footer: info.hillulotFooter)
            for h in info.hillulot { g.addRow(stackedRow(h.name, sub: h.sub, icon: "flame")) }
            stack.addArrangedSubview(g)
        }
        stack.addArrangedSubview(shareButton(title: shareTitle))
    }
}

// MARK: - The screen

@available(iOS 16.0, *)
final class NativeCalendarView: UIView, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate, UIScrollViewDelegate {
    struct Config {
        var rtl = true
        var isDark = true
        var lang = "he"
        var ymd = ""
        var civil = false
        var hebrewLabel = "Hebrew"
        var civilLabel = "Gregorian"
        var jumpLabel = "Jump"
        var todayLabel = "Today"
        var okLabel = "OK"
        var shareLabel = "Share"
    }

    /// Evaluates JS in the web view; the completion gets the (String) result.
    var runJS: ((String, @escaping (Any?) -> Void) -> Void)?
    var fire: ((String) -> Void)?
    var present: ((UIViewController) -> Void)?
    var bottomInset: (() -> CGFloat)?

    let scrollView = UIScrollView()
    private let content = UIStackView()
    private let segmented = UISegmentedControl(items: ["", ""])
    private let jumpButton = UIButton(type: .system)
    private let todayButton = UIButton(type: .system)
    private let calendarCard = NCCard()
    private let calendarView = UICalendarView()
    private var selectionBehavior: UICalendarSelectionSingleDate!
    private let pager = UIScrollView()
    private var pages: [NCDayPage] = [NCDayPage(), NCDayPage(), NCDayPage()]
    private var pagerHeight: NSLayoutConstraint!
    private var pagerHeights: [CGFloat] = [0, 0, 0]

    private var cfg = Config()
    private var isHebrew = true
    private var selected = Date()
    private var eventDays = Set<String>()
    private var lastLayoutWidth: CGFloat = 0

    private var gregorian: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone.current; return c
    }
    private var hebrewCal: Calendar {
        var c = Calendar(identifier: .hebrew); c.timeZone = TimeZone.current; return c
    }
    private var activeCal: Calendar { isHebrew ? hebrewCal : gregorian }
    private var gold: UIColor {
        cfg.isDark ? UIColor(red: 0.83, green: 0.69, blue: 0.37, alpha: 1) : UIColor(red: 0.54, green: 0.39, blue: 0.08, alpha: 1)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Layout

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        content.axis = .vertical
        content.spacing = 14
        content.alignment = .fill
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
        ])

        // Controls row: [segmented | jump | today]
        segmented.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        segmented.selectedSegmentIndex = 0
        segmented.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [segmented, jumpButton, todayButton])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        content.addArrangedSubview(row)
        jumpButton.addTarget(self, action: #selector(jumpTapped), for: .touchUpInside)
        todayButton.addTarget(self, action: #selector(todayTapped), for: .touchUpInside)

        // Apple's own calendar month grid inside a glass card
        calendarView.delegate = self
        calendarCard.translatesAutoresizingMaskIntoConstraints = false
        calendarCard.embed(calendarView, insets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8), isDark: cfg.isDark)
        content.addArrangedSubview(calendarCard)

        // Day pager: three pages (prev / current / next), real paging physics
        pager.isPagingEnabled = true
        pager.showsHorizontalScrollIndicator = false
        pager.bounces = true
        pager.delegate = self
        pager.semanticContentAttribute = .forceLeftToRight
        pager.translatesAutoresizingMaskIntoConstraints = false
        pagerHeight = pager.heightAnchor.constraint(equalToConstant: 300)
        pagerHeight.isActive = true
        for p in pages { pager.addSubview(p) }
        content.addArrangedSubview(pager)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = pager.bounds.width
        guard w > 0 else { return }
        let h = pagerHeight.constant
        for (i, p) in pages.enumerated() { p.frame = CGRect(x: CGFloat(i) * w, y: 0, width: w, height: h) }
        pager.contentSize = CGSize(width: w * 3, height: h)
        if !pager.isDragging && !pager.isDecelerating && abs(w - lastLayoutWidth) > 0.5 {
            pager.contentOffset = CGPoint(x: w, y: 0)
        }
        lastLayoutWidth = w
        let b = bottomInset?() ?? 100
        if abs(scrollView.contentInset.bottom - b) > 0.5 {
            scrollView.contentInset.bottom = b
            scrollView.verticalScrollIndicatorInsets.bottom = b
        }
    }

    // MARK: Public API

    func show(_ config: Config) {
        cfg = config
        isHebrew = !config.civil
        overrideUserInterfaceStyle = config.isDark ? .dark : .light
        backgroundColor = config.isDark ? UIColor(red: 0.031, green: 0.051, blue: 0.098, alpha: 1) : UIColor(red: 0.937, green: 0.902, blue: 0.824, alpha: 1)
        calendarCard.backgroundColor = config.isDark ? UIColor(red: 0.075, green: 0.105, blue: 0.2, alpha: 1) : UIColor(white: 1, alpha: 0.78)
        tintColor = gold
        let attr: UISemanticContentAttribute = config.rtl ? .forceRightToLeft : .forceLeftToRight
        semanticContentAttribute = attr
        content.semanticContentAttribute = attr
        calendarView.semanticContentAttribute = attr
        // UICalendarView follows the TRAIT layout direction, not semanticContentAttribute: without this Sunday sat on the left in Hebrew.
        if #available(iOS 17.0, *) { calendarView.traitOverrides.layoutDirection = config.rtl ? .rightToLeft : .leftToRight }
        segmented.semanticContentAttribute = attr

        segmented.setTitle(config.hebrewLabel, forSegmentAt: 0)
        segmented.setTitle(config.civilLabel, forSegmentAt: 1)
        segmented.selectedSegmentIndex = isHebrew ? 0 : 1
        segmented.selectedSegmentTintColor = gold
        segmented.setTitleTextAttributes([.foregroundColor: UIColor.label], for: .normal)
        segmented.setTitleTextAttributes([.foregroundColor: UIColor(white: 0.12, alpha: 1)], for: .selected)
        styleButton(jumpButton, title: config.jumpLabel, symbol: "calendar.badge.clock")
        styleButton(todayButton, title: config.todayLabel, symbol: nil)
        for p in pages {
            p.tint = gold
            p.isDark = config.isDark
            p.onPortion = { [weak self] a, b in self?.fire?("window.NativeCalendarHost.openPortion(\(a),\(b))") }
            p.onParasha = { [weak self] key in self?.fire?("window.NativeCalendarHost.openParasha('\(key)')") }
            p.onShare = { [weak self] in
                guard let self = self else { return }
                self.fire?("window.NativeCalendarHost.share('\(self.ymd(self.selected))')")
            }
        }

        selected = date(fromYMD: config.ymd) ?? Date()
        // Hebrew UI + Hebrew calendar: ask for Hebrew-letter numerals (א׳ ב׳ ...) instead of digits.
        applyLocale()
        calendarView.tintColor = gold
        applyCalendar()
        loadEvents()
        reloadPages()
    }

    func scrollToTop() { scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.adjustedContentInset.top), animated: true) }

    // MARK: Styling helpers

    private func styleButton(_ button: UIButton, title: String, symbol: String?) {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) { config = UIButton.Configuration.glass() } else { config = UIButton.Configuration.tinted() }
        config.title = title
        if let s = symbol { config.image = UIImage(systemName: s); config.imagePadding = 4 }
        config.cornerStyle = .capsule
        config.baseForegroundColor = gold
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { c in
            var c = c
            c.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            return c
        }
        button.configuration = config
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    // MARK: Dates

    private func ymd(_ d: Date) -> String {
        let c = gregorian.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04ld-%02ld-%02ld", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func date(fromYMD s: String) -> Date? {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        var c = DateComponents(); c.year = p[0]; c.month = p[1]; c.day = p[2]; c.hour = 12
        return gregorian.date(from: c)
    }

    private func shifted(_ d: Date, by days: Int) -> Date {
        return gregorian.date(byAdding: .day, value: days, to: d) ?? d
    }

    private func comps(_ d: Date, level: Set<Calendar.Component>) -> DateComponents {
        var c = activeCal.dateComponents(level, from: d)
        c.calendar = activeCal
        return c
    }

    // MARK: Calendar view wiring

    /// Hebrew day-of-month as letters (א׳ ... ט״ו ... ל׳), 15/16 written ט״ו / ט״ז.
    private func hebrewDayLetters(_ n: Int) -> String {
        let ones = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"]
        let tens = ["", "י", "כ", "ל"]
        var out: String
        if n == 15 { out = "טו" } else if n == 16 { out = "טז" } else { out = tens[n / 10] + ones[n % 10] }
        if out.count == 1 { return out + "׳" }
        return String(out.dropLast()) + "״" + String(out.last!)
    }

    private func secondaryDayText(_ d: Date) -> String {
        if isHebrew { return String(gregorian.component(.day, from: d)) }
        let hd = hebrewCal.component(.day, from: d)
        return cfg.lang == "he" ? hebrewDayLetters(hd) : String(hd)
    }

    private func applyLocale() {
        calendarView.locale = Locale(identifier: cfg.lang == "he" ? (isHebrew ? "he_IL@numbers=hebr" : "he_IL") : cfg.lang)
    }

    private func applyCalendar() {
        applyLocale()
        calendarView.calendar = activeCal
        selectionBehavior = UICalendarSelectionSingleDate(delegate: self)
        calendarView.selectionBehavior = selectionBehavior
        selectionBehavior.setSelected(comps(selected, level: [.era, .year, .month, .day]), animated: false)
        calendarView.setVisibleDateComponents(comps(selected, level: [.era, .year, .month]), animated: false)
    }

    private func loadEvents() {
        let start = ymd(shifted(selected, by: -400)), end = ymd(shifted(selected, by: 400))
        runJS?("JSON.stringify(window.NativeCalendarHost.events('\(start)','\(end)'))") { [weak self] r in
            guard let self = self, let s = r as? String, let data = s.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else { return }
            self.eventDays = Set(arr)
            // Re-assigning the calendar makes UICalendarView ask for every decoration again.
            self.calendarView.calendar = self.activeCal
        }
    }

    func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
        guard let d = activeCal.date(from: dateComponents) else { return nil }
        let hasEvent = eventDays.contains(ymd(d))
        // The OTHER calendar's day under each number (Hebrew letters under Gregorian days, Gregorian numbers under Hebrew days).
        let other = secondaryDayText(d)
        let gold = self.gold, dark = cfg.isDark
        return UICalendarView.Decoration.customView {
            let l = UILabel()
            l.text = other
            l.font = UIFont.systemFont(ofSize: 10, weight: hasEvent ? .bold : .regular)
            l.textColor = hasEvent ? gold : (dark ? UIColor(white: 1, alpha: 0.55) : UIColor(white: 0, alpha: 0.5))
            l.textAlignment = .center
            l.adjustsFontSizeToFitWidth = true
            l.minimumScaleFactor = 0.7
            return l
        }
    }

    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        guard let c = dateComponents, let d = activeCal.date(from: c) else { return }
        select(gregorian.date(bySettingHour: 12, minute: 0, second: 0, of: d) ?? d, syncCalendar: false)
    }

    // MARK: Selection + pager

    private func select(_ d: Date, syncCalendar: Bool) {
        selected = d
        if syncCalendar {
            selectionBehavior.setSelected(comps(d, level: [.era, .year, .month, .day]), animated: true)
            calendarView.setVisibleDateComponents(comps(d, level: [.era, .year, .month]), animated: true)
        }
        UISelectionFeedbackGenerator().selectionChanged()
        fire?("window.NativeCalendarHost.onSelect('\(ymd(d))')")
        reloadPages()
    }

    private func reloadPages() {
        let dates = [shifted(selected, by: -1), selected, shifted(selected, by: 1)]
        var done = 0
        for (i, d) in dates.enumerated() {
            runJS?("JSON.stringify(window.NativeCalendarHost.day('\(ymd(d))'))") { [weak self] r in
                guard let self = self else { return }
                var info: NCDayInfo? = nil
                if let s = r as? String, let data = s.data(using: .utf8) {
                    info = try? JSONDecoder().decode(NCDayInfo.self, from: data)
                }
                self.pages[i].configure(info, shareTitle: self.cfg.shareLabel, rtl: self.cfg.rtl)
                done += 1
                if done == 3 { self.relayoutPager() }
            }
        }
    }

    private func relayoutPager() {
        let w = pager.bounds.width
        guard w > 0 else { setNeedsLayout(); return }
        var maxH: CGFloat = 0
        for p in pages {
            let h = p.systemLayoutSizeFitting(CGSize(width: w, height: UIView.layoutFittingCompressedSize.height),
                                              withHorizontalFittingPriority: .required,
                                              verticalFittingPriority: .fittingSizeLevel).height
            maxH = max(maxH, h)
        }
        pagerHeight.constant = maxH
        pager.contentOffset = CGPoint(x: w, y: 0)
        setNeedsLayout()
        layoutIfNeeded()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === pager else { return }
        let w = pager.bounds.width
        guard w > 0 else { return }
        let idx = Int((pager.contentOffset.x / w).rounded())
        if idx == 0 { select(shifted(selected, by: -1), syncCalendar: true) }
        else if idx == 2 { select(shifted(selected, by: 1), syncCalendar: true) }
        pager.contentOffset = CGPoint(x: w, y: 0)
    }

    // MARK: Actions

    @objc private func modeChanged() {
        isHebrew = segmented.selectedSegmentIndex == 0
        applyCalendar()
        UISelectionFeedbackGenerator().selectionChanged()
        fire?("window.NativeCalendarHost.onMode(\(isHebrew ? "false" : "true"))")
    }

    @objc private func todayTapped() { select(gregorian.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date(), syncCalendar: true) }

    @objc private func jumpTapped() {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        vc.overrideUserInterfaceStyle = cfg.isDark ? .dark : .light
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.calendar = activeCal
        picker.locale = calendarView.locale
        picker.date = selected
        picker.translatesAutoresizingMaskIntoConstraints = false
        let ok = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = cfg.okLabel
        config.cornerStyle = .capsule
        config.baseBackgroundColor = gold
        config.baseForegroundColor = UIColor(white: 0.12, alpha: 1)
        ok.configuration = config
        ok.translatesAutoresizingMaskIntoConstraints = false
        ok.addAction(UIAction { [weak self, weak vc, weak picker] _ in
            guard let self = self, let picker = picker else { return }
            let d = self.gregorian.date(bySettingHour: 12, minute: 0, second: 0, of: picker.date) ?? picker.date
            vc?.dismiss(animated: true) { self.select(d, syncCalendar: true) }
        }, for: .touchUpInside)
        vc.view.addSubview(picker)
        vc.view.addSubview(ok)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: vc.view.topAnchor, constant: 24),
            picker.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 16),
            picker.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -16),
            ok.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 12),
            ok.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            ok.widthAnchor.constraint(equalToConstant: 160),
            ok.heightAnchor.constraint(equalToConstant: 44),
        ])
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present?(vc)
    }
}

// MARK: - Capacitor bridge

@objc(NativeCalendarBridge)
public class NativeCalendarBridge: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NativeCalendarBridge"
    public let jsName = "NativeCalendar"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "isSupported", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "show", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hide", returnType: CAPPluginReturnPromise),
    ]

    static weak var activeController: MainViewController?

    @objc func isSupported(_ call: CAPPluginCall) {
        if #available(iOS 16.0, *) { call.resolve(["supported": true]) } else { call.resolve(["supported": false]) }
    }

    @objc func show(_ call: CAPPluginCall) {
        let rtl = call.getBool("isRTL") ?? true
        let isDark = call.getBool("isDark") ?? true
        let lang = call.getString("lang") ?? "he"
        let ymd = call.getString("ymd") ?? ""
        let civil = call.getBool("civil") ?? false
        let labels = call.getObject("labels") ?? [:]
        func l(_ k: String, _ d: String) -> String { (labels[k] as? String) ?? d }
        DispatchQueue.main.async {
            NativeCalendarBridge.activeController?.showNativeCalendar(
                rtl: rtl, isDark: isDark, lang: lang, ymd: ymd, civil: civil,
                hebrew: l("hebrew", "Hebrew"), civilLabel: l("civil", "Gregorian"),
                jump: l("jump", "Jump"), today: l("today", "Today"), ok: l("ok", "OK"), share: l("share", "Share"))
        }
        call.resolve()
    }

    @objc func hide(_ call: CAPPluginCall) {
        DispatchQueue.main.async { NativeCalendarBridge.activeController?.hideNativeCalendar() }
        call.resolve()
    }
}
