import Testing
import SwiftData
import Foundation
@testable import Mosaic

@MainActor
struct TaskItemModelTests {
    @Test func savingTaskWithSubtaskAndTagPersistsRelationships() throws {
        let container = TestModelContainer.makeInMemory()
        let context = container.mainContext

        let tag = Tag(name: "urgent")
        let task = TaskItem(title: "Write report")
        let subtask = Subtask(title: "Draft outline")
        subtask.task = task
        task.subtasks = [subtask]
        task.tags = [tag]

        context.insert(task)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.subtasks.count == 1)
        #expect(fetched.first?.tags.first?.name == "urgent")
    }

    @Test func deletingTaskCascadesToSubtasks() throws {
        let container = TestModelContainer.makeInMemory()
        let context = container.mainContext

        let task = TaskItem(title: "Plan trip")
        let subtask = Subtask(title: "Book flights")
        subtask.task = task
        task.subtasks = [subtask]

        context.insert(task)
        try context.save()

        context.delete(task)
        try context.save()

        let remainingSubtasks = try context.fetch(FetchDescriptor<Subtask>())
        #expect(remainingSubtasks.isEmpty)
    }

    @Test func deletingTaskCascadesToAttachments() throws {
        let container = TestModelContainer.makeInMemory()
        let context = container.mainContext

        let task = TaskItem(title: "Submit expenses")
        let attachment = TaskAttachment(
            kind: .pdf,
            filename: "receipt.pdf",
            fileSizeBytes: 1024,
            localURL: URL(fileURLWithPath: "/tmp/receipt.pdf")
        )
        attachment.task = task
        task.attachments = [attachment]

        context.insert(task)
        try context.save()

        context.delete(task)
        try context.save()

        let remainingAttachments = try context.fetch(FetchDescriptor<TaskAttachment>())
        #expect(remainingAttachments.isEmpty)
    }

    @Test func deletingTaskCascadesToLocationReminder() throws {
        let container = TestModelContainer.makeInMemory()
        let context = container.mainContext

        let task = TaskItem(title: "Pick up dry cleaning")
        let reminder = LocationReminder(
            name: "Dry Cleaner",
            address: "123 Main St",
            latitude: 37.7749,
            longitude: -122.4194,
            trigger: .arriving
        )
        task.locationReminder = reminder

        context.insert(task)
        try context.save()

        context.delete(task)
        try context.save()

        let remainingReminders = try context.fetch(FetchDescriptor<LocationReminder>())
        #expect(remainingReminders.isEmpty)
    }
}
