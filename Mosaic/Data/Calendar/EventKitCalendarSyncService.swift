import Foundation
@preconcurrency import EventKit

@MainActor
final class EventKitCalendarSyncService: CalendarSyncService {
    private let store: EKEventStore
    private let userDefaults: UserDefaults

    init(store: EKEventStore = EKEventStore(), userDefaults: UserDefaults = .standard) {
        self.store = store
        self.userDefaults = userDefaults
    }

    func requestAuthorization() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .denied, .restricted, .writeOnly:
            return false
        default:
            break
        }
        return (try? await store.requestFullAccessToEvents()) ?? false
    }

    func fetchEvents(from startDate: Date, to endDate: Date) async -> [CalendarEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }

        // nil means the user has never visited the calendar picker — every
        // non-birthday calendar syncs by default, matching the toggle's
        // original all-or-nothing behavior until they narrow it down.
        let selectedIdentifiers = userDefaults.stringArray(forKey: SettingsKeys.selectedCalendarIdentifiers).map(Set.init)

        // store.events(matching:) is a blocking, synchronous EventKit call
        // that can take a while to expand recurrence rules across every
        // calendar over a 90-day window. Both this type and the
        // CalendarSyncService protocol are @MainActor (callers need that),
        // so the blocking work is hopped onto a detached task here to keep
        // it off the main thread; only the already-Sendable [CalendarEvent]
        // result crosses back.
        let store = self.store
        return await Task.detached {
            let realCalendars = Self.syncableCalendars(from: store, selectedIdentifiers: selectedIdentifiers)
            let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: realCalendars)
            return store.events(matching: predicate).map { event in
                CalendarEvent(
                    id: event.eventIdentifier,
                    title: event.title ?? "Untitled Event",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location
                )
            }
        }.value
    }

    func fetchAvailableCalendars() async -> [CalendarInfo] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }

        let store = self.store
        return await Task.detached {
            Self.syncableCalendars(from: store, selectedIdentifiers: nil).map { calendar in
                CalendarInfo(id: calendar.calendarIdentifier, title: calendar.title, sourceName: calendar.source.title)
            }
        }.value
    }

    // Excludes only the `.birthday` calendar type — the single calendar
    // EventKit always synthesizes from Contacts rather than one the user
    // created or subscribed to themselves. `.subscription` is deliberately
    // NOT excluded: it also covers legitimate subscribed calendars (shared
    // work/team calendars added via a link), not just Apple's built-in
    // Holidays calendar, so filtering it out would hide real events.
    //
    // `selectedIdentifiers`, when non-nil, additionally narrows this down to
    // the user's explicit picker choice.
    nonisolated private static func syncableCalendars(from store: EKEventStore, selectedIdentifiers: Set<String>?) -> [EKCalendar] {
        let nonBirthdayCalendars = store.calendars(for: .event).filter { $0.type != .birthday }
        guard let selectedIdentifiers else { return nonBirthdayCalendars }
        return nonBirthdayCalendars.filter { selectedIdentifiers.contains($0.calendarIdentifier) }
    }
}
