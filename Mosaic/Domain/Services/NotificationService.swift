import Foundation

struct TaskReminderInfo: Sendable {
    let id: UUID
    let title: String
    let hasReminder: Bool
    let dueDate: Date?
    let dueTime: Date?

    init(id: UUID, title: String, hasReminder: Bool, dueDate: Date?, dueTime: Date?) {
        self.id = id
        self.title = title
        self.hasReminder = hasReminder
        self.dueDate = dueDate
        self.dueTime = dueTime
    }

    @MainActor
    init(task: TaskItem) {
        self.id = task.id
        self.title = task.title
        self.hasReminder = task.hasReminder
        self.dueDate = task.dueDate
        self.dueTime = task.dueTime
    }
}

@MainActor
protocol NotificationService {
    func requestAuthorization() async -> Bool
    func scheduleReminder(for reminder: TaskReminderInfo) async
    func cancelReminder(id: UUID) async
    func cancelAllReminders() async
    func postLocationAlert(identifier: String, title: String, body: String) async
}
