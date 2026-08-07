import Foundation

struct ReminderItem: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let dueDate: Date
    let hasTime: Bool
}

@MainActor
protocol ReminderSyncService {
    func requestAuthorization() async -> Bool
    func fetchReminders(from startDate: Date, to endDate: Date) async -> [ReminderItem]
}
