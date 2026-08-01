import Foundation
import SwiftData

@Model
final class RecurringTaskTemplate {
    @Attribute(.unique) var id: UUID
    var title: String
    var weekdays: [Int]
    var startHour: Int?
    var startMinute: Int?
    var endHour: Int?
    var endMinute: Int?
    var createdAt: Date
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.recurringTemplate) var occurrences: [TaskItem]

    init(
        id: UUID = UUID(),
        title: String,
        weekdays: [Int],
        startHour: Int? = nil,
        startMinute: Int? = nil,
        endHour: Int? = nil,
        endMinute: Int? = nil,
        createdAt: Date = .now,
        isActive: Bool = true
    ) {
        self.id = id
        self.title = title
        self.weekdays = weekdays
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.createdAt = createdAt
        self.isActive = isActive
        self.occurrences = []
    }
}
