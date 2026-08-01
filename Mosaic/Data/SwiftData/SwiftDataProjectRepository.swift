import Foundation
import SwiftData

@MainActor
final class SwiftDataProjectRepository: ProjectRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Project] {
        try context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    func create(_ project: Project) throws {
        context.insert(project)
        try context.save()
    }

    func update(_ project: Project) throws {
        try context.save()
    }

    func delete(_ project: Project) throws {
        context.delete(project)
        try context.save()
    }
}
