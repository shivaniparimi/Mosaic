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
        try save()
    }

    func update(_ project: Project) throws {
        try save()
    }

    func delete(_ project: Project) throws {
        context.delete(project)
        try save()
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        NotificationCenter.default.post(name: .taskDataDidChange, object: nil)
    }
}
