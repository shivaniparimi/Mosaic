import Foundation
import UserNotifications

@MainActor
final class UserNotificationService: NotificationService {
    private let center: UNUserNotificationCenter
    private let userDefaults: UserDefaults

    init(center: UNUserNotificationCenter = .current(), userDefaults: UserDefaults = .standard) {
        self.center = center
        self.userDefaults = userDefaults
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func scheduleReminder(for reminder: TaskReminderInfo) async {
        let notificationsEnabled = (userDefaults.object(forKey: SettingsKeys.notificationsEnabled) as? Bool) ?? false

        guard Self.shouldSchedule(reminder: reminder, notificationsEnabled: notificationsEnabled),
              let dueDate = reminder.dueDate,
              let dueTime = reminder.dueTime else {
            await cancelReminder(id: reminder.id)
            return
        }

        let fireDate = Self.combine(date: dueDate, time: dueTime)

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.sound = .default

        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        try? await center.add(request)
    }

    func cancelReminder(id: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    func cancelAllReminders() async {
        center.removeAllPendingNotificationRequests()
    }

    func postLocationAlert(identifier: String, title: String, body: String) async {
        let notificationsEnabled = (userDefaults.object(forKey: SettingsKeys.notificationsEnabled) as? Bool) ?? false
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // A very short interval trigger rather than nil — nil/zero-interval
        // triggers have inconsistent delivery behavior across iOS versions;
        // 1 second is effectively immediate and reliable.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try? await center.add(request)
    }

    nonisolated static func shouldSchedule(reminder: TaskReminderInfo, notificationsEnabled: Bool) -> Bool {
        notificationsEnabled && reminder.hasReminder && reminder.dueDate != nil && reminder.dueTime != nil
    }

    private nonisolated static func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        return calendar.date(from: components) ?? date
    }
}
