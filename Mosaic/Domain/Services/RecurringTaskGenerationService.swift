@MainActor
protocol RecurringTaskGenerationService {
    func generateInitialOccurrences(for template: RecurringTaskTemplate) throws
    func topUpIfNeeded(_ templates: [RecurringTaskTemplate]) throws
}
