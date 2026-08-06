import Testing
import Foundation
@testable import Mosaic

struct UserNotificationServiceTests {
    @Test func shouldScheduleRequiresReminderEnabled() {
        let reminder = TaskReminderInfo(id: UUID(), title: "Task", hasReminder: false, dueDate: .now, dueTime: .now)
        #expect(!UserNotificationService.shouldSchedule(reminder: reminder, notificationsEnabled: true))
    }

    @Test func shouldScheduleRequiresDueDate() {
        let reminder = TaskReminderInfo(id: UUID(), title: "Task", hasReminder: true, dueDate: nil, dueTime: .now)
        #expect(!UserNotificationService.shouldSchedule(reminder: reminder, notificationsEnabled: true))
    }

    @Test func shouldScheduleRequiresDueTime() {
        let reminder = TaskReminderInfo(id: UUID(), title: "Task", hasReminder: true, dueDate: .now, dueTime: nil)
        #expect(!UserNotificationService.shouldSchedule(reminder: reminder, notificationsEnabled: true))
    }

    @Test func shouldScheduleRequiresNotificationsEnabled() {
        let reminder = TaskReminderInfo(id: UUID(), title: "Task", hasReminder: true, dueDate: .now, dueTime: .now)
        #expect(!UserNotificationService.shouldSchedule(reminder: reminder, notificationsEnabled: false))
    }

    @Test func shouldScheduleReturnsTrueWhenAllConditionsMet() {
        let reminder = TaskReminderInfo(id: UUID(), title: "Task", hasReminder: true, dueDate: .now, dueTime: .now)
        #expect(UserNotificationService.shouldSchedule(reminder: reminder, notificationsEnabled: true))
    }
}
