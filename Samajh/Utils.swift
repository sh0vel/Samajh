import Foundation

enum DateFormatting {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func relative(from isoString: String?) -> String {
        guard let isoString else { return "" }
        let date = iso.date(from: isoString) ?? isoNoFrac.date(from: isoString)
        guard let date else { return "" }

        let now = Date()
        let diff = now.timeIntervalSince(date)
        let mins = Int(diff / 60)
        let hours = Int(diff / 3600)
        let days = Int(diff / 86400)

        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        if hours < 24 { return "\(hours)h ago" }
        if days < 7 { return "\(days)d ago" }

        let formatter = DateFormatter()
        let cal = Calendar.current
        if cal.component(.year, from: date) == cal.component(.year, from: now) {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }
}
