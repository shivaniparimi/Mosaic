import Testing
@testable import Mosaic

@MainActor
struct SwiftDataRecurringTaskTemplateRepositoryTests {
    @Test func createAndFetchAllActiveReturnsCreatedTemplate() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataRecurringTaskTemplateRepository(context: container.mainContext)

        try repository.create(RecurringTaskTemplate(title: "Hot yoga", weekdays: [2, 4, 6], startHour: 19, startMinute: 0))

        let templates = try repository.fetchAllActive()
        #expect(templates.count == 1)
        #expect(templates.first?.title == "Hot yoga")
    }

    @Test func fetchAllActiveExcludesInactiveTemplates() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataRecurringTaskTemplateRepository(context: container.mainContext)

        try repository.create(RecurringTaskTemplate(
            title: "Inactive class",
            weekdays: [2],
            startHour: 19,
            startMinute: 0,
            isActive: false
        ))

        let templates = try repository.fetchAllActive()
        #expect(templates.isEmpty)
    }

    @Test func deactivateMarksTemplateInactiveAndExcludesItFromFetchAllActive() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataRecurringTaskTemplateRepository(context: container.mainContext)

        let template = RecurringTaskTemplate(title: "Hot yoga", weekdays: [2, 4, 6], startHour: 19, startMinute: 0)
        try repository.create(template)
        #expect(try repository.fetchAllActive().count == 1)

        try repository.deactivate(template)

        #expect(!template.isActive)
        #expect(try repository.fetchAllActive().isEmpty)
    }
}
