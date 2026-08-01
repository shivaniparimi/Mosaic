import Testing
import SwiftData
import Foundation
@testable import Mosaic

@MainActor
struct SwiftDataTaskRepositoryTests {
    @Test func createAndFetchAllReturnsCreatedTask() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)

        try repository.create(TaskItem(title: "Buy milk"))

        let tasks = try repository.fetchAll()
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Buy milk")
    }

    @Test func fetchInboxReturnsOnlyCapturedUncompletedTasks() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)

        try repository.create(TaskItem(title: "Inbox item", capturedAt: .now))
        try repository.create(TaskItem(title: "Scheduled item", dueDate: .now))

        let inboxTasks = try repository.fetchInbox()
        #expect(inboxTasks.count == 1)
        #expect(inboxTasks.first?.title == "Inbox item")
    }

    @Test func toggleCompletionSetsCompletedAt() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Finish plan")
        try repository.create(task)

        try repository.toggleCompletion(task)

        #expect(task.isCompleted)
        #expect(task.completedAt != nil)
    }

    @Test func deleteRemovesTask() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Temporary")
        try repository.create(task)

        try repository.delete(task)

        #expect(try repository.fetchAll().isEmpty)
    }

    @Test func searchMatchesTitleCaseInsensitively() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        try repository.create(TaskItem(title: "Review Q3 design system"))
        try repository.create(TaskItem(title: "Pick up prescription"))

        let results = try repository.search(query: "design")
        #expect(results.count == 1)
        #expect(results.first?.title == "Review Q3 design system")
    }

    @Test func searchMatchesNotesWhenTitleDoesNotMatch() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        try repository.create(TaskItem(title: "Weekly review", notes: "Audit the design system tokens"))
        try repository.create(TaskItem(title: "Pick up prescription"))

        let results = try repository.search(query: "design")
        #expect(results.count == 1)
        #expect(results.first?.title == "Weekly review")
    }

    @Test func fetchInboxExcludesCompletedCapturedTasks() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)

        try repository.create(TaskItem(title: "Inbox item", capturedAt: .now))
        try repository.create(
            TaskItem(title: "Completed capture", isCompleted: true, completedAt: .now, capturedAt: .now)
        )

        let inboxTasks = try repository.fetchInbox()
        #expect(inboxTasks.count == 1)
        #expect(inboxTasks.first?.title == "Inbox item")
    }

    @Test func createPostsTaskDataDidChangeNotification() async {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)

        await confirmation { confirmed in
            let observer = NotificationCenter.default.addObserver(
                forName: .taskDataDidChange,
                object: nil,
                queue: nil
            ) { _ in confirmed() }
            defer { NotificationCenter.default.removeObserver(observer) }

            try? repository.create(TaskItem(title: "Notify me"))
        }
    }

    @Test func createManyPostsExactlyOneNotificationForABatch() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)

        final class Counter: @unchecked Sendable {
            var value = 0
        }
        let counter = Counter()
        let observer = NotificationCenter.default.addObserver(
            forName: .taskDataDidChange,
            object: nil,
            queue: nil
        ) { _ in counter.value += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        try repository.createMany([
            TaskItem(title: "First"),
            TaskItem(title: "Second"),
            TaskItem(title: "Third")
        ])

        #expect(counter.value == 1)
        #expect(try repository.fetchAll().count == 3)
    }
}
