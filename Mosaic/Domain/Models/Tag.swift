import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var name: String
    var tasks: [TaskItem]

    init(name: String) {
        self.name = name
        self.tasks = []
    }
}
