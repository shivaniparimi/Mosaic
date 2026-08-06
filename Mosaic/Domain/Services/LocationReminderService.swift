import Foundation

// A Sendable snapshot of exactly what CLLocationManager needs to register or
// re-register a region — never the live TaskItem. See this plan's Global
// Constraints: handing a live SwiftData model across an async boundary
// (especially into a fire-and-forget Task {}) crashed the Notifications
// feature's test suite earlier in this project.
struct LocationReminderInfo: Sendable {
    let reminderID: UUID
    let latitude: Double
    let longitude: Double
    let trigger: LocationTrigger

    @MainActor
    init?(task: TaskItem) {
        guard let reminder = task.locationReminder else { return nil }
        self.reminderID = reminder.id
        self.latitude = reminder.latitude
        self.longitude = reminder.longitude
        self.trigger = reminder.trigger
    }
}

@MainActor
protocol LocationReminderService {
    func requestAuthorization() async -> Bool
    func startMonitoring(for reminder: LocationReminderInfo) async
    func stopMonitoring(id: UUID) async
    func reregisterAll(reminders: [LocationReminderInfo]) async
}
