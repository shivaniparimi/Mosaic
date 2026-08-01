import Testing
import SwiftData
import Foundation
@testable import Mosaic

@MainActor
struct RecurringTaskTemplateModelTests {
    @Test func savingTemplateWithOccurrencesPersistsRelationship() throws {
        let container = TestModelContainer.makeInMemory()
        let context = container.mainContext

        let template = RecurringTaskTemplate(title: "Hot yoga", weekdays: [2, 4, 6], startHour: 19, startMinute: 0)
        let occurrence = TaskItem(title: "Hot yoga", dueDate: .now, recurringTemplate: template)
        template.occurrences = [occurrence]

        context.insert(template)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RecurringTaskTemplate>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.occurrences.count == 1)
        #expect(fetched.first?.occurrences.first?.recurringTemplate?.title == "Hot yoga")
    }

    @Test func deletingTemplateCascadesToOccurrences() throws {
        let container = TestModelContainer.makeInMemory()
        let context = container.mainContext

        let template = RecurringTaskTemplate(title: "Hot yoga", weekdays: [2, 4, 6], startHour: 19, startMinute: 0)
        let occurrence = TaskItem(title: "Hot yoga", dueDate: .now, recurringTemplate: template)
        template.occurrences = [occurrence]

        context.insert(template)
        try context.save()

        context.delete(template)
        try context.save()

        let remainingOccurrences = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(remainingOccurrences.isEmpty)
    }

    @Test func templateDefaultsToActiveOnCreation() {
        let template = RecurringTaskTemplate(title: "Hot yoga", weekdays: [2, 4, 6], startHour: 19, startMinute: 0)
        #expect(template.isActive)
    }

    @Test func templateDefaultsToNoStartTimeWhenOmitted() {
        let template = RecurringTaskTemplate(title: "Walk dog", weekdays: [2, 4, 6])
        #expect(template.startHour == nil)
        #expect(template.startMinute == nil)
    }

    /// Exercises the real SchemaV1 -> SchemaV2 lightweight migration against a
    /// file-backed store, so the migration machinery actually runs instead of
    /// being bypassed by an in-memory container.
    @Test func migratesV1StoreToV2Successfully() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID()).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        do {
            let v1Schema = Schema(versionedSchema: SchemaV1.self)
            let v1Config = ModelConfiguration(schema: v1Schema, url: tempURL)
            let v1Container = try ModelContainer(for: v1Schema, configurations: v1Config)
            let context = v1Container.mainContext
            context.insert(TaskItem(title: "Pre-migration task"))
            try context.save()
        }

        // Guards against the store silently falling back to in-memory, which
        // would bypass the migration machinery this test exists to exercise.
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        let v2Schema = Schema(versionedSchema: SchemaV2.self)
        let v2Config = ModelConfiguration(schema: v2Schema, url: tempURL)
        let migratedContainer = try ModelContainer(
            for: v2Schema,
            migrationPlan: MosaicMigrationPlan.self,
            configurations: v2Config
        )
        let migratedContext = migratedContainer.mainContext

        let tasks = try migratedContext.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Pre-migration task")

        let template = RecurringTaskTemplate(title: "Test", weekdays: [2], startHour: 9, startMinute: 0)
        migratedContext.insert(template)
        try migratedContext.save()
        let templates = try migratedContext.fetch(FetchDescriptor<RecurringTaskTemplate>())
        #expect(templates.count == 1)
    }
}
