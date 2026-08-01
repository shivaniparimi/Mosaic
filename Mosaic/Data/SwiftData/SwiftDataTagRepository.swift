import Foundation
import SwiftData

@MainActor
final class SwiftDataTagRepository: TagRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Tag] {
        try context.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)]))
    }

    func findOrCreate(name: String) throws -> Tag {
        let predicate = #Predicate<Tag> { $0.name == name }
        var descriptor = FetchDescriptor<Tag>(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let tag = Tag(name: name)
        context.insert(tag)
        try context.save()
        return tag
    }

    func delete(_ tag: Tag) throws {
        context.delete(tag)
        try context.save()
    }
}
