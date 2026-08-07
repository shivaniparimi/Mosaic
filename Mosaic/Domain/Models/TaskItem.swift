import Foundation
import SwiftData

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date
    var capturedAt: Date?
    var dueDate: Date?
    var dueTime: Date?
    var timeOfDay: TimeOfDay?
    var priority: Priority
    var hasReminder: Bool
    var reminderOffsetMinutes: Int?
    var origin: TaskOrigin
    var sortOrder: Int

    @Relationship(inverse: \Tag.tasks) var tags: [Tag]
    @Relationship(deleteRule: .cascade, inverse: \Subtask.task) var subtasks: [Subtask]
    @Relationship(deleteRule: .cascade, inverse: \TaskAttachment.task) var attachments: [TaskAttachment]
    @Relationship(deleteRule: .cascade) var locationReminder: LocationReminder?
    var recurringTemplate: RecurringTaskTemplate?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        capturedAt: Date? = nil,
        dueDate: Date? = nil,
        dueTime: Date? = nil,
        timeOfDay: TimeOfDay? = nil,
        priority: Priority = .none,
        hasReminder: Bool = false,
        reminderOffsetMinutes: Int? = nil,
        origin: TaskOrigin = .manual,
        sortOrder: Int = 0,
        recurringTemplate: RecurringTaskTemplate? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.capturedAt = capturedAt
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.timeOfDay = timeOfDay
        self.priority = priority
        self.hasReminder = hasReminder
        self.reminderOffsetMinutes = reminderOffsetMinutes
        self.origin = origin
        self.sortOrder = sortOrder
        self.tags = []
        self.subtasks = []
        self.attachments = []
        self.locationReminder = nil
        self.recurringTemplate = recurringTemplate
    }
}
