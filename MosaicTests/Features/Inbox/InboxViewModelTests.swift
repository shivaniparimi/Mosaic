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

        let viewModel = InboxViewModel(taskRepository: repository, locationReminderService: RecordingLocationReminderService())
        await viewModel.load()

        #expect(viewModel.items.map(\.title) == ["Captured"])
    }

    @Test func loadReturnsInboxItemsSortedNewestFirst() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let olderDate = Date.now.addingTimeInterval(-3600)
        try repository.create(TaskItem(title: "Older task", createdAt: olderDate, capturedAt: olderDate))
        try repository.create(TaskItem(title: "Newer task", createdAt: .now, capturedAt: .now))

        let viewModel = InboxViewModel(taskRepository: repository, locationReminderService: RecordingLocationReminderService())
        await viewModel.load()

        #expect(viewModel.items.map(\.title) == ["Newer task", "Older task"])
    }

    @Test func captureCreatesQuickCaptureTaskAndClearsInput() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = InboxViewModel(taskRepository: repository, locationReminderService: RecordingLocationReminderService())
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
        let viewModel = InboxViewModel(taskRepository: repository, locationReminderService: RecordingLocationReminderService())
        viewModel.captureText = "   "

        await viewModel.capture()

        #expect(try repository.fetchAll().isEmpty)
        #expect(viewModel.items.isEmpty)
    }

    @Test func canCaptureReflectsWhetherInputIsNonBlank() {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = InboxViewModel(taskRepository: repository, locationReminderService: RecordingLocationReminderService())

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

        let viewModel = InboxViewModel(taskRepository: repository, locationReminderService: RecordingLocationReminderService())
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

        let viewModel = InboxViewModel(taskRepository: repository, locationReminderService: RecordingLocationReminderService())
        await viewModel.load()

        await viewModel.toggleCompletion(task)

        #expect(viewModel.items.isEmpty)
        #expect(task.isCompleted)
    }

    @Test func toggleCompletionStopsLocationMonitoringWhenCompletingATaskWithALocationReminder() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let reminder = LocationReminder(name: "Home", address: "123 Main St", latitude: 37.0, longitude: -122.0, trigger: .arriving)
        let task = TaskItem(title: "Water plants", capturedAt: .now)
        task.locationReminder = reminder
        try repository.create(task)

        let locationService = RecordingLocationReminderService()
        let viewModel = InboxViewModel(taskRepository: repository, locationReminderService: locationService)
        await viewModel.load()

        await viewModel.toggleCompletion(task)

        #expect(locationService.stoppedReminderIDs == [reminder.id])
    }

    @Test func toggleCompletionResumesLocationMonitoringWhenUncompletingATaskWithALocationReminder() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let reminder = LocationReminder(name: "Home", address: "123 Main St", latitude: 37.0, longitude: -122.0, trigger: .arriving)
        let task = TaskItem(title: "Water plants", isCompleted: true, capturedAt: .now)
        task.locationReminder = reminder
        try repository.create(task)

        let locationService = RecordingLocationReminderService()
        let viewModel = InboxViewModel(taskRepository: repository, locationReminderService: locationService)

        await viewModel.toggleCompletion(task)

        #expect(locationService.startedReminderIDs == [reminder.id])
    }
}

private final class RecordingLocationReminderService: LocationReminderService {
    private(set) var startedReminderIDs: [UUID] = []
    private(set) var stoppedReminderIDs: [UUID] = []

    func requestAuthorization() async -> Bool { true }

    func startMonitoring(for reminder: LocationReminderInfo) async {
        startedReminderIDs.append(reminder.reminderID)
    }

    func stopMonitoring(id: UUID) async {
        stoppedReminderIDs.append(id)
    }

    func reregisterAll(reminders: [LocationReminderInfo]) async {
        for reminder in reminders { startedReminderIDs.append(reminder.reminderID) }
    }
}
