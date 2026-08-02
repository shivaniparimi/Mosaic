import Testing
import SwiftData
import Foundation
@testable import Mosaic

@MainActor
struct InboxViewModelTests {
    @Test func loadReturnsOnlyCapturedIncompleteTasks() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        try repository.create(TaskItem(title: "Captured", capturedAt: .now))
        try repository.create(TaskItem(title: "Scheduled", dueDate: .now))
        try repository.create(TaskItem(title: "Captured but done", isCompleted: true, capturedAt: .now))

        let viewModel = InboxViewModel(taskRepository: repository)
        await viewModel.load()

        #expect(viewModel.items.map(\.title) == ["Captured"])
    }

    @Test func loadReturnsInboxItemsSortedNewestFirst() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let olderDate = Date.now.addingTimeInterval(-3600)
        try repository.create(TaskItem(title: "Older task", createdAt: olderDate, capturedAt: olderDate))
        try repository.create(TaskItem(title: "Newer task", createdAt: .now, capturedAt: .now))

        let viewModel = InboxViewModel(taskRepository: repository)
        await viewModel.load()

        #expect(viewModel.items.map(\.title) == ["Newer task", "Older task"])
    }

    @Test func captureCreatesQuickCaptureTaskAndClearsInput() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = InboxViewModel(taskRepository: repository)
        viewModel.captureText = "  Buy milk  "

        await viewModel.capture()

        #expect(viewModel.captureText.isEmpty)
        #expect(viewModel.items.map(\.title) == ["Buy milk"])
        let created = try #require(viewModel.items.first)
        #expect(created.capturedAt != nil)
        #expect(created.origin == .quickCapture)
        #expect(created.dueDate == nil)
    }

    @Test func captureIsANoOpForBlankText() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = InboxViewModel(taskRepository: repository)
        viewModel.captureText = "   "

        await viewModel.capture()

        #expect(try repository.fetchAll().isEmpty)
        #expect(viewModel.items.isEmpty)
    }

    @Test func canCaptureReflectsWhetherInputIsNonBlank() {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = InboxViewModel(taskRepository: repository)

        #expect(!viewModel.canCapture)
        viewModel.captureText = "  "
        #expect(!viewModel.canCapture)
        viewModel.captureText = "Water the plants"
        #expect(viewModel.canCapture)
    }

    @Test func moveToTodayClearsCapturedAtAndSchedulesForToday() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Call plumber", capturedAt: .now)
        try repository.create(task)

        let viewModel = InboxViewModel(taskRepository: repository)
        await viewModel.load()
        #expect(viewModel.items.count == 1)

        await viewModel.moveToToday(task)

        #expect(viewModel.items.isEmpty)
        #expect(task.capturedAt == nil)
        #expect(task.timeOfDay == .anytime)
        let dueDate = try #require(task.dueDate)
        #expect(Calendar.current.isDateInToday(dueDate))
    }

    @Test func toggleCompletionMarksTaskDoneAndRemovesFromInbox() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Read chapter 3", capturedAt: .now)
        try repository.create(task)

        let viewModel = InboxViewModel(taskRepository: repository)
        await viewModel.load()

        await viewModel.toggleCompletion(task)

        #expect(viewModel.items.isEmpty)
        #expect(task.isCompleted)
    }
}
