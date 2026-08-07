import Foundation

struct FakeReminderSyncService: ReminderSyncService {
    func requestAuthorization() async -> Bool { true }

    func fetchReminders(from startDate: Date, to endDate: Date) async -> [ReminderItem] {
        let calendar = Calendar.current
        return [
            ReminderItem(
                id: "preview-reminder-1",
                title: "Pick up dry cleaning",
                dueDate: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: startDate) ?? startDate,
                hasTime: true
            )
        ]
    }
}
