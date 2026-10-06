import EventKit
import Foundation

/// A single calendar event, reduced to what Clockio renders. Read from the macOS Calendar
/// store via EventKit — which surfaces Google calendars the user has added in
/// System Settings → Internet Accounts, so "Google Calendar integration" needs no OAuth.
struct CalendarEvent: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool

    /// `HH:mm` start label, or nil for all-day events.
    var timeText: String? {
        guard !isAllDay else { return nil }
        return CalendarEvent.timeFormatter.string(from: start)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

/// Thin EventKit wrapper: requests read access once and fetches today's events. Reading events
/// requires *full* access on macOS 14+ (write-only access cannot read), so that's what we ask for.
@MainActor
final class CalendarProvider {
    enum Access {
        case notDetermined
        case granted
        case denied
    }

    private let store = EKEventStore()

    var access: Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return .granted
        case .notDetermined:
            return .notDetermined
        default:
            // .denied, .restricted, and .writeOnly all mean we cannot read events.
            return .denied
        }
    }

    /// Prompts for full calendar access if needed. Returns whether reading is now allowed.
    func requestAccess() async -> Bool {
        if access == .granted { return true }
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    /// Today's events (midnight → midnight), all calendars, sorted with all-day first then by start.
    func todaysEvents(now: Date = Date()) -> [CalendarEvent] {
        guard access == .granted else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { $0.status != .canceled }
            .map { event in
                CalendarEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: (event.title?.isEmpty == false ? event.title : nil) ?? "Untitled event",
                    start: event.startDate ?? start,
                    end: event.endDate ?? start,
                    isAllDay: event.isAllDay
                )
            }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay && !rhs.isAllDay }
                return lhs.start < rhs.start
            }
    }
}
