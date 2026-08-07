import Foundation

struct CalendarEvent: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
}

struct CalendarInfo: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let sourceName: String
}

@MainActor
protocol CalendarSyncService {
    func requestAuthorization() async -> Bool
    func fetchEvents(from startDate: Date, to endDate: Date) async -> [CalendarEvent]
    func fetchAvailableCalendars() async -> [CalendarInfo]
}
