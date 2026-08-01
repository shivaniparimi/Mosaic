import Foundation
import SwiftData

@Model
final class Subtask {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var sortOrder: Int
    var task: TaskItem?

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.task = nil
    }
}
