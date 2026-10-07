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
    let portions: [Portion]
    let loc: String?
    let zmanim: [Row]
    let shabbat: [Row]
}

// MARK: - Glass card

final class NCGlassCard: UIView {
    private let effectView: UIVisualEffectView

    override init(frame: CGRect) {
        if #available(iOS 26.0, *) {
            effectView = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        }
        super.init(frame: frame)
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.layer.cornerRadius = 26
        effectView.clipsToBounds = true
        addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Pins `view` inside the glass with the given insets.
    func embed(_ view: UIView, insets: UIEdgeInsets) {
        view.translatesAutoresizingMaskIntoConstraints = false
        effectView.contentView.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: effectView.contentView.topAnchor, constant: insets.top),
            view.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor, constant: -insets.bottom),
            view.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: insets.left),
            view.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -insets.right),
        ])
    }
}

// MARK: - One day's detail page

final class NCDayPage: UIView {
    var onPortion: ((Int, Int) -> Void)?
    var onShare: (() -> Void)?
    var tint: UIColor = .systemYellow { didSet { tintColor = tint } }

    private let card = NCGlassCard()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        card.embed(stack, insets: UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func label(_ text: String, style: UIFont.TextStyle, weight: UIFont.Weight = .regular,
                       color: UIColor = .label, align: NSTextAlignment = .natural) -> UILabel {
        let l = UILabel()
        l.text = text
        l.numberOfLines = 0
        l.textAlignment = align
        l.textColor = color
        let base = UIFont.preferredFont(forTextStyle: style)
        l.font = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
        l.adjustsFontForContentSizeCategory = true
        return l
    }

    private func pill(_ text: String) -> UIView {
        let l = label(text, style: .footnote, weight: .semibold, color: tint, align: .center)
        let box = UIView()
        box.backgroundColor = tint.withAlphaComponent(0.16)
        box.layer.cornerRadius = 12
        l.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(l)
        NSLayoutConstraint.activate([
            l.topAnchor.constraint(equalTo: box.topAnchor, constant: 6),
            l.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -6),
            l.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            l.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
        ])
        return box
    }

    private func infoBox(title: String, value: String) -> UIView {
        let t = label(title, style: .caption1, color: .secondaryLabel, align: .center)
        let v = label(value, style: .headline, weight: .semibold, align: .center)
        let s = UIStackView(arrangedSubviews: [t, v])
        s.axis = .vertical
        s.spacing = 2
        let box = UIView()
        box.backgroundColor = UIColor.secondarySystemFill
        box.layer.cornerRadius = 16
        s.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(s)
        NSLayoutConstraint.activate([
            s.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            s.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10),
            s.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 10),
            s.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -10),
        ])
        return box
    }

    private func timeRow(_ row: NCDayInfo.Row, highlight: Bool) -> UIView {
        let name = label(row.label, style: .body, color: highlight ? tint : .label)
        let time = label(row.time, style: .body, weight: highlight ? .bold : .regular,
                         color: highlight ? tint : .secondaryLabel)
        time.font = UIFont.monospacedDigitSystemFont(ofSize: time.font.pointSize, weight: highlight ? .bold : .regular)
        time.setContentHuggingPriority(.required, for: .horizontal)
        time.setContentCompressionResistancePriority(.required, for: .horizontal)
        let s = UIStackView(arrangedSubviews: [name, time])
        s.axis = .horizontal
        s.spacing = 8
        s.alignment = .firstBaseline
        return s
    }

    private func separator() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        return v
    }

    private func actionButton(title: String, symbol: String, action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) { config = UIButton.Configuration.glass() } else { config = UIButton.Configuration.tinted() }
        config.title = title
        config.image = UIImage(systemName: symbol)
        config.imagePadding = 8
        config.cornerStyle = .capsule
        config.baseForegroundColor = tint
        b.configuration = config
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return b
    }

    func configure(_ info: NCDayInfo?, shareTitle: String, rtl: Bool) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        stack.semanticContentAttribute = semanticContentAttribute
        guard let info = info else { return }

        stack.addArrangedSubview(label(info.title, style: .title2, weight: .bold, align: .center))
        stack.addArrangedSubview(label(info.greg, style: .subheadline, color: .secondaryLabel, align: .center))

        if !info.events.isEmpty {
            for e in info.events { stack.addArrangedSubview(pill(e)) }
        }
        if let pl = info.parashaLabel, let pv = info.parasha {
            stack.addArrangedSubview(infoBox(title: pl, value: pv))
        }
        if !info.portions.isEmpty {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            row.distribution = .fillEqually
            row.semanticContentAttribute = stack.semanticContentAttribute
            for p in info.portions {
                let box = infoBox(title: p.label, value: p.val)
                let tap = UITapGestureRecognizer(target: self, action: #selector(portionTapped(_:)))
                box.addGestureRecognizer(tap)
                box.tag = p.a * 1000 + p.b
                row.addArrangedSubview(box)
            }
            stack.addArrangedSubview(row)
        }
        if let loc = info.loc {
            stack.addArrangedSubview(label("📍 " + loc, style: .footnote, color: .secondaryLabel))
        }
        if !info.zmanim.isEmpty {
            stack.addArrangedSubview(separator())
            for z in info.zmanim { stack.addArrangedSubview(timeRow(z, highlight: z.next ?? false)) }
        }
        if !info.shabbat.isEmpty {
            stack.addArrangedSubview(separator())
            for z in info.shabbat { stack.addArrangedSubview(timeRow(z, highlight: true)) }
        }
        stack.addArrangedSubview(actionButton(title: shareTitle, symbol: "square.and.arrow.up") { [weak self] in self?.onShare?() })
    }

    @objc private func portionTapped(_ g: UITapGestureRecognizer) {
        guard let tag = g.view?.tag else { return }
        onPortion?(tag / 1000, tag % 1000)
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
    private let calendarCard = NCGlassCard()
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
        calendarCard.embed(calendarView, insets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
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
        tintColor = gold
        let attr: UISemanticContentAttribute = config.rtl ? .forceRightToLeft : .forceLeftToRight
        semanticContentAttribute = attr
        content.semanticContentAttribute = attr
        calendarView.semanticContentAttribute = attr
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
            p.onPortion = { [weak self] a, b in self?.fire?("window.NativeCalendarHost.openPortion(\(a),\(b))") }
            p.onShare = { [weak self] in
                guard let self = self else { return }
                self.fire?("window.NativeCalendarHost.share('\(self.ymd(self.selected))')")
            }
        }

        selected = date(fromYMD: config.ymd) ?? Date()
        calendarView.locale = Locale(identifier: config.lang == "he" ? "he_IL" : config.lang)
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

    private func applyCalendar() {
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
        if eventDays.contains(ymd(d)) { return UICalendarView.Decoration.default(color: gold, size: .small) }
        return nil
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
