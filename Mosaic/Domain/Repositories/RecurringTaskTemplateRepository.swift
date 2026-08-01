@MainActor
protocol RecurringTaskTemplateRepository {
    func fetchAllActive() throws -> [RecurringTaskTemplate]
    func create(_ template: RecurringTaskTemplate) throws
    func deactivate(_ template: RecurringTaskTemplate) throws
}
