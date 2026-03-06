import Foundation
import SwiftUI

// MARK: - Google Calendar Service
// Interfaces with Google Calendar REST API using OAuth tokens from GoogleAuthService.
// All calls are real production API calls — no demo data.

@MainActor
class GoogleCalendarService: ObservableObject {
    static let shared = GoogleCalendarService()

    private let baseURL = "https://www.googleapis.com/calendar/v3"
    private let auth = GoogleAuthService.shared

    @Published var events: [CalendarEvent] = []
    @Published var monthEvents: [CalendarEvent] = []  // All events for the visible month
    @Published var isLoading = false
    @Published var selectedDate = Date()

    // MARK: - Calendar API Response Models

    struct CalendarEventsResponse: Codable {
        let kind: String?
        let summary: String?
        let timeZone: String?
        let items: [CalendarEventItem]?
        let nextPageToken: String?
    }

    struct CalendarEventItem: Codable {
        let id: String?
        let summary: String?
        let description: String?
        let location: String?
        let start: EventDateTime?
        let end: EventDateTime?
        let hangoutLink: String?
        let conferenceData: ConferenceData?
        let colorId: String?
        let status: String?
        let htmlLink: String?
        let organizer: EventPerson?
        let attendees: [EventPerson]?
    }

    struct EventDateTime: Codable {
        let dateTime: String?
        let date: String?
        let timeZone: String?
    }

    struct ConferenceData: Codable {
        let entryPoints: [EntryPoint]?

        struct EntryPoint: Codable {
            let entryPointType: String?
            let uri: String?
            let label: String?
        }
    }

    struct EventPerson: Codable {
        let email: String?
        let displayName: String?
        let self_: Bool?

        enum CodingKeys: String, CodingKey {
            case email
            case displayName
            case self_ = "self"
        }
    }

    struct CreateEventAttendee: Codable {
        let email: String
    }

    struct CreateConferenceRequest: Codable {
        let createRequest: CreateRequest?

        struct CreateRequest: Codable {
            let requestId: String
            let conferenceSolutionKey: ConferenceSolutionKey

            struct ConferenceSolutionKey: Codable {
                let type: String
            }
        }
    }

    struct CreateEventRequest: Codable {
        let summary: String
        let start: EventDateTime
        let end: EventDateTime
        let conferenceData: CreateConferenceRequest?
        let location: String?
        let attendees: [CreateEventAttendee]?
    }

    // MARK: - Fetch Events

    func fetchEvents(for date: Date) async {
        isLoading = true

        guard let token = await auth.getAccessToken() else {
            isLoading = false
            return
        }

        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                isLoading = false
                return
            }

            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]
            let timeMin = isoFormatter.string(from: startOfDay)
            let timeMax = isoFormatter.string(from: endOfDay)

            let encodedTimeMin = timeMin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timeMin
            let encodedTimeMax = timeMax.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timeMax

            let urlString = "\(baseURL)/calendars/primary/events?timeMin=\(encodedTimeMin)&timeMax=\(encodedTimeMax)&singleEvents=true&orderBy=startTime"

            guard let url = URL(string: urlString) else {
                isLoading = false
                return
            }

            var request = URLRequest(url: url)
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            // Handle 401 — try token refresh
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 401 {
                if let newToken = await auth.refreshAccessToken() {
                    request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    let (retryData, _) = try await URLSession.shared.data(for: request)
                    let retryResponse = try JSONDecoder().decode(CalendarEventsResponse.self, from: retryData)
                    events = (retryResponse.items ?? []).compactMap { parseCalendarEvent($0) }
                }
                isLoading = false
                return
            }

            let calResponse = try JSONDecoder().decode(CalendarEventsResponse.self, from: data)
            events = (calResponse.items ?? []).compactMap { parseCalendarEvent($0) }
        } catch {
            print("[GoogleCalendarService] fetchEvents error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Fetch Events for Entire Month (for dot indicators)

    func fetchMonthEvents(for month: Date) async {
        guard let token = await auth.getAccessToken() else { return }

        do {
            let calendar = Calendar.current
            guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
                  let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else { return }

            // Extend range to cover prev/next month overflow days visible in the grid
            let rangeStart = calendar.date(byAdding: .day, value: -7, to: startOfMonth) ?? startOfMonth
            let rangeEnd = calendar.date(byAdding: .day, value: 7, to: endOfMonth) ?? endOfMonth

            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]
            let timeMin = isoFormatter.string(from: rangeStart)
            let timeMax = isoFormatter.string(from: rangeEnd)

            let encodedTimeMin = timeMin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timeMin
            let encodedTimeMax = timeMax.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timeMax

            let urlString = "\(baseURL)/calendars/primary/events?timeMin=\(encodedTimeMin)&timeMax=\(encodedTimeMax)&singleEvents=true&orderBy=startTime&maxResults=250"

            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: request)
            let calResponse = try JSONDecoder().decode(CalendarEventsResponse.self, from: data)
            monthEvents = (calResponse.items ?? []).compactMap { parseCalendarEvent($0) }
        } catch {
            print("[GoogleCalendarService] fetchMonthEvents error: \(error.localizedDescription)")
        }
    }

    // MARK: - Events for Date (from month cache for dot indicators)

    func monthEvents(on date: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        return monthEvents.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }

    // MARK: - Events for Date (from selected day)

    func events(on date: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        return events.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }

    // MARK: - Create Event

    func createEvent(title: String, start: Date, end: Date, meetingLink: String? = nil, addGoogleMeet: Bool = false, attendees: [String] = []) async -> Bool {
        guard let token = await auth.getAccessToken() else { return false }

        do {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]

            let conferenceData: CreateConferenceRequest? = addGoogleMeet ? CreateConferenceRequest(
                createRequest: CreateConferenceRequest.CreateRequest(
                    requestId: UUID().uuidString,
                    conferenceSolutionKey: CreateConferenceRequest.CreateRequest.ConferenceSolutionKey(type: "hangoutsMeet")
                )
            ) : nil

            let attendeesList: [CreateEventAttendee]? = attendees.isEmpty ? nil : attendees.map { CreateEventAttendee(email: $0) }

            let createBody = CreateEventRequest(
                summary: title,
                start: EventDateTime(dateTime: isoFormatter.string(from: start), date: nil, timeZone: nil),
                end: EventDateTime(dateTime: isoFormatter.string(from: end), date: nil, timeZone: nil),
                conferenceData: conferenceData,
                location: nil,
                attendees: attendeesList
            )

            let jsonData = try JSONEncoder().encode(createBody)

            var urlString = "\(baseURL)/calendars/primary/events"
            if addGoogleMeet {
                urlString += "?conferenceDataVersion=1"
            }
            guard let url = URL(string: urlString) else { return false }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let (responseData, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            if statusCode == 200 || statusCode == 201 {
                let createdItem = try JSONDecoder().decode(CalendarEventItem.self, from: responseData)
                if let calEvent = parseCalendarEvent(createdItem) {
                    events.append(calEvent)
                }
                return true
            } else {
                print("[GoogleCalendarService] createEvent failed with status \(statusCode)")
                return false
            }
        } catch {
            print("[GoogleCalendarService] createEvent error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Parse Calendar API Event

    private func parseCalendarEvent(_ item: CalendarEventItem) -> CalendarEvent? {
        guard let id = item.id else { return nil }

        let title = item.summary ?? "(No Title)"

        let startDate = parseEventDate(item.start)
        let endDate = parseEventDate(item.end)

        guard let start = startDate, let end = endDate else { return nil }

        var meetLink: String? = item.hangoutLink
        if meetLink == nil, let entryPoints = item.conferenceData?.entryPoints {
            meetLink = entryPoints.first(where: { $0.entryPointType == "video" })?.uri
        }

        // Determine event color from the organizer's account color
        let organizerEmail = item.organizer?.email
        let activeAccountEmail = auth.currentUser?.email
        let eventColor = colorForEvent(organizerEmail: organizerEmail, activeAccountEmail: activeAccountEmail)

        return CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: end,
            location: item.location,
            meetingLink: meetLink,
            color: eventColor,
            calendarName: "Work",
            accountEmail: activeAccountEmail,
            organizerEmail: organizerEmail
        )
    }

    // MARK: - Map Event to Account Color

    /// Matches organizer email against connected accounts to determine the dot color.
    /// If the organizer is a connected account, that account's color is used.
    /// If the organizer is external but the event is in your calendar, uses the active account's color.
    private func colorForEvent(organizerEmail: String?, activeAccountEmail: String?) -> Color {
        let accounts = auth.accounts

        // Try to match organizer email to an account
        if let orgEmail = organizerEmail,
           let matchedAccount = accounts.first(where: { $0.email.lowercased() == orgEmail.lowercased() }) {
            return matchedAccount.colorTag.color
        }

        // Fallback: use the active account's color (the calendar it was fetched from)
        if let activeEmail = activeAccountEmail,
           let matchedAccount = accounts.first(where: { $0.email.lowercased() == activeEmail.lowercased() }) {
            return matchedAccount.colorTag.color
        }

        // Default fallback
        return .accentSkyBlue
    }

    // MARK: - Parse Event Date/Time

    private func parseEventDate(_ eventDT: EventDateTime?) -> Date? {
        guard let eventDT = eventDT else { return nil }

        if let dateTimeString = eventDT.dateTime {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateTimeString) { return date }

            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateTimeString) { return date }
        }

        if let dateString = eventDT.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter.date(from: dateString)
        }

        return nil
    }
}
