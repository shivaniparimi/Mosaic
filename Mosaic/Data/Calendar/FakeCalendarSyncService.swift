import Foundation

struct FakeCalendarSyncService: CalendarSyncService {
    func requestAuthorization() async -> Bool { true }

    func fetchEvents(from startDate: Date, to endDate: Date) async -> [CalendarEvent] {
        let calendar = Calendar.current
        return [
            CalendarEvent(
                id: "preview-event-1",
                title: "Design Review",
                startDate: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: startDate) ?? startDate,
                endDate: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: startDate) ?? startDate,
                isAllDay: false,
                location: "Conference Room A"
            )
        ]
    }

    func fetchAvailableCalendars() async -> [CalendarInfo] {
        [
            CalendarInfo(id: "preview-calendar-1", title: "Home", sourceName: "iCloud"),
            CalendarInfo(id: "preview-calendar-2", title: "Work", sourceName: "iCloud")
        ]
    }
}
