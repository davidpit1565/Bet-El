import WidgetKit
import SwiftUI

// MARK: - Direction of prayer (Jerusalem / the Temple Mount)

/// A home-screen widget cannot read the phone's live heading (WidgetKit has no access to the compass sensor), so this
/// widget shows the FIXED bearing from the user's saved location to Jerusalem: a dial with north at the top and the
/// gold needle pointing the way to Jerusalem, the angle in degrees, the compass direction and the distance.
/// A tap opens the app's live compass (`betel://compass` -> `kotelCompass`).
enum JerusalemBearing {
    static let lat = 31.7780   // Temple Mount
    static let lon = 35.2354

    /// Initial great-circle bearing in degrees clockwise from true north (0...360).
    static func degrees(fromLat: Double, fromLon: Double) -> Double {
        let p1 = fromLat * .pi / 180, p2 = lat * .pi / 180
        let dl = (lon - fromLon) * .pi / 180
        let y = sin(dl) * cos(p2)
        let x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)
        let d = atan2(y, x) * 180 / .pi
        return (d + 360).truncatingRemainder(dividingBy: 360)
    }

    static func distanceKm(fromLat: Double, fromLon: Double) -> Double {
        let r = 6371.0
        let p1 = fromLat * .pi / 180, p2 = lat * .pi / 180
        let dp = p2 - p1, dl = (lon - fromLon) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }

    private static let names: [String: [String]] = [
        "he": ["צָפוֹן", "צָפוֹן־מִזְרָח", "מִזְרָח", "דָּרוֹם־מִזְרָח", "דָּרוֹם", "דָּרוֹם־מַעֲרָב", "מַעֲרָב", "צָפוֹן־מַעֲרָב"],
        "en": ["North", "North-east", "East", "South-east", "South", "South-west", "West", "North-west"],
        "fr": ["Nord", "Nord-est", "Est", "Sud-est", "Sud", "Sud-ouest", "Ouest", "Nord-ouest"],
        "ru": ["Север", "Северо-восток", "Восток", "Юго-восток", "Юг", "Юго-запад", "Запад", "Северо-запад"],
        "ka": ["ჩრდილოეთი", "ჩრდილო-აღმოსავლეთი", "აღმოსავლეთი", "სამხრეთ-აღმოსავლეთი", "სამხრეთი", "სამხრეთ-დასავლეთი", "დასავლეთი", "ჩრდილო-დასავლეთი"],
    ]

    static func cardinal(_ deg: Double, lang: String) -> String {
        let list = names[lang] ?? names["en"]!
        return list[Int(((deg + 22.5).truncatingRemainder(dividingBy: 360)) / 45) % 8]
    }

    static func title(lang: String) -> String {
        switch lang {
        case "he": return "כִּוּוּן תְּפִלָּה"
        case "fr": return "Direction de la prière"
        case "ru": return "Направление молитвы"
        case "ka": return "ლოცვის მიმართულება"
        default: return "Prayer direction"
        }
    }

    static func jerusalem(lang: String) -> String {
        switch lang {
        case "he": return "יְרוּשָׁלַיִם"
        case "fr": return "Jérusalem"
        case "ru": return "Иерусалим"
        case "ka": return "იერუსალიმი"
        default: return "Jerusalem"
        }
    }
}

// MARK: - Views

private struct CompassDial: View {
    let bearing: Double
    let palette: BetElTheme.Palette
    var showLetters = true

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().strokeBorder(palette.line, lineWidth: 2)
                Circle().fill(palette.gold.opacity(0.07))
                ForEach(0..<24, id: \.self) { i in
                    Rectangle()
                        .fill(i % 6 == 0 ? palette.goldBright : palette.gold.opacity(0.55))
                        .frame(width: i % 6 == 0 ? 2.4 : 1.2, height: s * (i % 6 == 0 ? 0.075 : 0.045))
                        .offset(y: -s * 0.5 + s * (i % 6 == 0 ? 0.06 : 0.04))
                        .rotationEffect(.degrees(Double(i) * 15))
                }
                if showLetters {
                    Text("N").font(.system(size: s * 0.12, weight: .heavy, design: .rounded)).foregroundColor(palette.goldBright)
                        .offset(y: -s * 0.30)
                }
                // the needle: points to Jerusalem
                ZStack {
                    Capsule().fill(LinearGradient(colors: [palette.goldBright, palette.gold], startPoint: .top, endPoint: .bottom))
                        .frame(width: s * 0.07, height: s * 0.34).offset(y: -s * 0.17)
                    Capsule().fill(palette.inkSoft.opacity(0.45))
                        .frame(width: s * 0.07, height: s * 0.20).offset(y: s * 0.10)
                    Image(systemName: "star.of.david.fill")
                        .font(.system(size: s * 0.15, weight: .bold))
                        .foregroundColor(palette.goldBright)
                        .offset(y: -s * 0.38)
                }
                .rotationEffect(.degrees(bearing))
                Circle().fill(palette.ink).frame(width: s * 0.08, height: s * 0.08)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

private struct CompassWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: BetElEntry

    private var bearing: Double { JerusalemBearing.degrees(fromLat: entry.latitude, fromLon: entry.longitude) }
    private var km: Int { Int(JerusalemBearing.distanceKm(fromLat: entry.latitude, fromLon: entry.longitude).rounded()) }

    var body: some View {
        let palette = BetElTheme.palette(for: entry.theme)
        let deg = Int(bearing.rounded()) % 360
        let dir = JerusalemBearing.cardinal(bearing, lang: entry.lang)
        Group {
            if #available(iOS 16.0, *), family == .accessoryCircular {
                CompassDial(bearing: bearing, palette: palette, showLetters: false).padding(2)
            } else if family == .systemMedium {
                HStack(spacing: 14) {
                    CompassDial(bearing: bearing, palette: palette).frame(maxWidth: 132)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(JerusalemBearing.title(lang: entry.lang)).font(.system(size: 13, weight: .semibold)).foregroundColor(palette.gold)
                        Text(JerusalemBearing.jerusalem(lang: entry.lang)).font(.system(size: 22, weight: .heavy)).foregroundColor(palette.ink).lineLimit(1).minimumScaleFactor(0.6)
                        Text("\(deg)° · \(dir)").font(.system(size: 16, weight: .semibold)).foregroundColor(palette.goldBright).lineLimit(1).minimumScaleFactor(0.6)
                        Text("\(km.formatted()) km").font(.system(size: 13, weight: .medium)).foregroundColor(palette.inkSoft)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
            } else {
                VStack(spacing: 6) {
                    CompassDial(bearing: bearing, palette: palette)
                    Text("\(deg)° · \(dir)").font(.system(size: 13, weight: .bold)).foregroundColor(palette.goldBright).lineLimit(1).minimumScaleFactor(0.5)
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.layoutDirection, .leftToRight)
        .widgetURL(entry.link("compass"))
        .widgetBackground(palette: palette)
    }
}

struct BetElCompassWidget: Widget {
    let kind: String = "BetElCompassWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BetElProvider()) { entry in
            SystemTheme { (theme: String) -> CompassWidgetView in
                var e = entry
                e.theme = theme
                return CompassWidgetView(entry: e)
            }
        }
        .configurationDisplayName("כִּוּוּן תְּפִלָּה")
        .description("הַכִּוּוּן לִירוּשָׁלַיִם מִמְּקוֹמְךָ")
        .supportedFamilies(Self.families)
    }
    private static var families: [WidgetFamily] {
        var f: [WidgetFamily] = [.systemSmall, .systemMedium]
        if #available(iOS 16.0, *) { f.append(.accessoryCircular) }
        return f
    }
}
