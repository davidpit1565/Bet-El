import Foundation

/// A compact solar-position calculation (sunrise/sunset/solar noon) for a
/// given date + lat/lon, using the standard NOAA solar-position equations
/// (a public-domain algorithm, independently implemented here - not a
/// copy of any bundled JS zmanim library). Good to within roughly a
/// minute, which is more than enough for "what's the next zman" on a
/// home-screen widget; it deliberately does NOT attempt the app's own,
/// more halachically nuanced zmanim (alot hashachar/tzeit/plag hamincha
/// etc.) - see docs/widget-spec.md for why that's out of scope for v1.
enum Solar {
    struct DayTimes {
        let sunrise: Date
        let solarNoon: Date
        let sunset: Date
    }

    /// `date` should be local midnight (any time on the target day works;
    /// only the calendar day is used). `zenith` is 90.833 for the
    /// standard sunrise/sunset definition (accounts for atmospheric
    /// refraction + the sun's apparent radius).
    static func times(for date: Date, latitude: Double, longitude: Double) -> DayTimes? {
        let zenith = 90.833
        guard
            let sunrise = calculate(date: date, latitude: latitude, longitude: longitude, zenith: zenith, isSunrise: true),
            let sunset = calculate(date: date, latitude: latitude, longitude: longitude, zenith: zenith, isSunrise: false)
        else { return nil }
        let noon = sunrise.addingTimeInterval(sunset.timeIntervalSince(sunrise) / 2)
        return DayTimes(sunrise: sunrise, solarNoon: noon, sunset: sunset)
    }

    private static func calculate(date: Date, latitude: Double, longitude: Double, zenith: Double, isSunrise: Bool) -> Date? {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        guard let dayOfYear = utcCal.ordinality(of: .day, in: .year, for: date) else { return nil }
        let n = Double(dayOfYear)

        let lngHour = longitude / 15
        let t = isSunrise ? n + ((6 - lngHour) / 24) : n + ((18 - lngHour) / 24)

        let m = (0.9856 * t) - 3.289
        var l = m + (1.916 * sinDeg(m)) + (0.020 * sinDeg(2 * m)) + 282.634
        l = normalize(l, 360)

        var ra = atanDeg(0.91764 * tanDeg(l))
        ra = normalize(ra, 360)
        let lQuadrant = floor(l / 90) * 90
        let raQuadrant = floor(ra / 90) * 90
        ra += (lQuadrant - raQuadrant)
        ra /= 15

        let sinDec = 0.39782 * sinDeg(l)
        let cosDec = cosDeg(asinDeg(sinDec))

        let cosH = (cosDeg(zenith) - (sinDec * sinDeg(latitude))) / (cosDec * cosDeg(latitude))
        if cosH > 1 || cosH < -1 { return nil } // sun never rises/sets that day at this latitude

        let h = isSunrise ? 360 - acosDeg(cosH) : acosDeg(cosH)
        let hHours = h / 15

        let localMeanTime = hHours + ra - (0.06571 * t) - 6.622
        let utcTime = normalize(localMeanTime - lngHour, 24)

        let hour = Int(utcTime)
        let minuteFraction = (utcTime - Double(hour)) * 60
        let minute = Int(minuteFraction)
        let second = Int((minuteFraction - Double(minute)) * 60)

        var comps = utcCal.dateComponents([.year, .month, .day], from: date)
        comps.timeZone = TimeZone(identifier: "UTC")
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        return utcCal.date(from: comps)
    }

    private static func normalize(_ value: Double, _ range: Double) -> Double {
        var v = value
        while v < 0 { v += range }
        while v >= range { v -= range }
        return v
    }
    private static func sinDeg(_ d: Double) -> Double { sin(d * .pi / 180) }
    private static func cosDeg(_ d: Double) -> Double { cos(d * .pi / 180) }
    private static func tanDeg(_ d: Double) -> Double { tan(d * .pi / 180) }
    private static func asinDeg(_ v: Double) -> Double { asin(v) * 180 / .pi }
    private static func atanDeg(_ v: Double) -> Double { atan(v) * 180 / .pi }
    private static func acosDeg(_ v: Double) -> Double { acos(v) * 180 / .pi }
}
