import SwiftUI

// MARK: - Calendar Event

struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let meetingLink: String?
    var color: Color
    let calendarName: String
    var linkedEmailId: String?
    var accountEmail: String?       // Which account this event belongs to
    var organizerEmail: String?     // Who organized the event

    var duration: String {
        let interval = endDate.timeIntervalSince(startDate)
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 { return "\(hours) hour\(hours > 1 ? "s" : "")" }
        return "\(hours)h \(remainingMinutes)m"
    }

    var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    var startTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    var meetingPlatform: String? {
        guard let link = meetingLink else { return nil }
        if link.contains("meet.google") { return "Google Meet" }
        if link.contains("zoom") { return "Zoom" }
        if link.contains("teams") { return "Teams" }
        return "Video Call"
    }
}

// MARK: - Calendar Day

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    var events: [CalendarEvent]

    var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }
}

