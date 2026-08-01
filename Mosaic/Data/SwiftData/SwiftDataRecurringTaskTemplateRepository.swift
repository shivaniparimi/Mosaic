import Foundation
import SwiftData

@MainActor
final class SwiftDataRecurringTaskTemplateRepository: RecurringTaskTemplateRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAllActive() throws -> [RecurringTaskTemplate] {
        let predicate = #Predicate<RecurringTaskTemplate> { $0.isActive == true }
        return try context.fetch(FetchDescriptor<RecurringTaskTemplate>(predicate: predicate))
    }

    func create(_ template: RecurringTaskTemplate) throws {
        context.insert(template)
        try context.save()
    }

    func deactivate(_ template: RecurringTaskTemplate) throws {
        template.isActive = false
        try context.save()
    }
}
