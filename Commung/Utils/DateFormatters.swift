import Foundation

enum DateFormatters {
    static let iso8601Full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

func parseDate(_ dateString: String) -> Date? {
    // Try ISO8601 with fractional seconds first
    if let date = DateFormatters.iso8601Full.date(from: dateString) {
        return date
    }

    // Try ISO8601 without fractional seconds
    if let date = DateFormatters.iso8601.date(from: dateString) {
        return date
    }

    return nil
}

func formatRelativeTime(_ dateString: String) -> String {
    guard let date = parseDate(dateString) else {
        return dateString
    }

    let now = Date()
    let interval = now.timeIntervalSince(date)

    if interval < 60 {
        return "just now"
    } else if interval < 3600 {
        let minutes = Int(interval / 60)
        return "\(minutes)m ago"
    } else if interval < 86400 {
        let hours = Int(interval / 3600)
        return "\(hours)h ago"
    } else {
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }
}

func formatFullDate(_ dateString: String) -> String {
    guard let date = parseDate(dateString) else {
        return dateString
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short

    return dateFormatter.string(from: date)
}
