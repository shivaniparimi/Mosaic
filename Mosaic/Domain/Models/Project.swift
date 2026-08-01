import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.project) var tasks: [TaskItem]

    init(id: UUID = UUID(), name: String, colorHex: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.tasks = []
    }
}
