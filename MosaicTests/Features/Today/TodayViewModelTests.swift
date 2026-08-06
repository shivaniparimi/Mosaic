import Testing
import SwiftData
import Foundation
@testable import Mosaic

@MainActor
struct TodayViewModelTests {
    private func makeViewModel(
        context: ModelContext,
        taskRepository: TaskRepository,
        aiInsightService: AIInsightService,
        locationReminderService: LocationReminderService = RecordingLocationReminderService()
    ) -> TodayViewModel {
        TodayViewModel(
            taskRepository: taskRepository,
            aiInsightService: aiInsightService,
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: context),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(
                taskRepository: SwiftDataTaskRepository(context: context)
            ),
            locationReminderService: locationReminderService
        )
    }

    @Test func loadGroupsIncompleteTodayTasksByTimeOfDay() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let today = Date.now

        try repository.create(TaskItem(title: "Morning task", dueDate: today, timeOfDay: .morning))
        try repository.create(TaskItem(title: "Afternoon task", dueDate: today, timeOfDay: .afternoon))
        try repository.create(TaskItem(title: "Anytime task", dueDate: today, timeOfDay: .anytime))

        let viewModel = makeViewModel(
            context: container.mainContext,
            taskRepository: repository,
            aiInsightService: StubAIInsightService(insight: nil)
        )
        await viewModel.load()

        #expect(viewModel.morningTasks.map(\.title) == ["Morning task"])
        #expect(viewModel.afternoonTasks.map(\.title) == ["Afternoon task"])
        #expect(viewModel.anytimeTasks.map(\.title) == ["Anytime task"])
    }

    @Test func loadExcludesInboxAndNonTodayTasks() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let today = Date.now
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        try repository.create(TaskItem(title: "Inbox item", capturedAt: .now))
        try repository.create(TaskItem(title: "Tomorrow's task", dueDate: tomorrow))
        try repository.create(TaskItem(title: "Today's task", dueDate: today))

        let viewModel = makeViewModel(
            context: container.mainContext,
            taskRepository: repository,
            aiInsightService: StubAIInsightService(insight: nil)
        )
        await viewModel.load()

        #expect(viewModel.totalCount == 1)
        #expect(viewModel.anytimeTasks.map(\.title) == ["Today's task"])
    }

    @Test func loadExcludesCapturedTasksEvenWithTodayDueDate() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let today = Date.now

        try repository.create(TaskItem(title: "Captured but dated today", capturedAt: .now, dueDate: today))

        let viewModel = makeViewModel(
            context: container.mainContext,
            taskRepository: repository,
            aiInsightService: StubAIInsightService(insight: nil)
        )
        await viewModel.load()

        #expect(viewModel.totalCount == 0)
    }

    @Test func loadSeparatesCompletedTasksFromActiveSections() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let today = Date.now

        try repository.create(TaskItem(title: "Done", isCompleted: true, dueDate: today))
        try repository.create(TaskItem(title: "Not done", dueDate: today))

        let viewModel = makeViewModel(
            context: container.mainContext,
            taskRepository: repository,
            aiInsightService: StubAIInsightService(insight: nil)
        )
        await viewModel.load()

        #expect(viewModel.completedTasks.map(\.title) == ["Done"])
        #expect(viewModel.anytimeTasks.map(\.title) == ["Not done"])
    }

    @Test func toggleCompletionMovesTaskIntoCompletedSectionAndReloads() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let today = Date.now
        let task = TaskItem(title: "Finish plan", dueDate: today)
        try repository.create(task)

        let viewModel = makeViewModel(
            context: container.mainContext,
            taskRepository: repository,
            aiInsightService: StubAIInsightService(insight: nil)
        )
        await viewModel.load()
        #expect(viewModel.anytimeTasks.count == 1)

        await viewModel.toggleCompletion(task)

        #expect(viewModel.anytimeTasks.isEmpty)
        #expect(viewModel.completedTasks.map(\.title) == ["Finish plan"])
    }

    @Test func loadStoresInsightFromService() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        try repository.create(TaskItem(title: "Task", dueDate: .now))

        let stubInsight = AIInsight(message: "Stub message")
        let viewModel = makeViewModel(
            context: container.mainContext,
            taskRepository: repository,
            aiInsightService: StubAIInsightService(insight: stubInsight)
        )
        await viewModel.load()

        #expect(viewModel.insight == stubInsight)
    }

    @Test func toggleCompletedSectionExpandedFlipsState() {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = makeViewModel(
            context: container.mainContext,
            taskRepository: repository,
            aiInsightService: StubAIInsightService(insight: nil)
        )

        #expect(!viewModel.isCompletedSectionExpanded)
        viewModel.toggleCompletedSectionExpanded()
        #expect(viewModel.isCompletedSectionExpanded)
    }

    @Test func sectionsSortTasksByDueTimeAscending() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let today = Date.now
        let calendar = Calendar.current
        let laterTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!
        let earlierTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!

        try repository.create(TaskItem(title: "Later", dueDate: today, dueTime: laterTime, timeOfDay: .anytime))
        try repository.create(TaskItem(title: "Earlier", dueDate: today, dueTime: earlierTime, timeOfDay: .anytime))

        let viewModel = makeViewModel(
            context: container.mainContext,
            taskRepository: repository,
            aiInsightService: StubAIInsightService(insight: nil)
        )
        await viewModel.load()

        #expect(viewModel.anytimeTasks.map(\.title) == ["Earlier", "Later"])
    }

    @Test func toggleCompletionRecomputesInsightFromUpdatedTaskList() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let today = Date.now
        let task = TaskItem(title: "Task", dueDate: today)
        try repository.create(task)

        let recordingService = RecordingAIInsightService()
        let viewModel = makeViewModel(
            context: container.mainContext,
            taskRepository: repository,
            aiInsightService: recordingService
        )
        await viewModel.load()
        #expect(viewModel.insight?.message == "1 remaining")

        await viewModel.toggleCompletion(task)

        #expect(viewModel.insight?.message == "0 remaining")
    }

    @Test func loadGeneratesRecurringOccurrencesWhenTopUpIsNeeded() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let recurringTaskTemplateRepository = SwiftDataRecurringTaskTemplateRepository(context: container.mainContext)
        let generationService = DefaultRecurringTaskGenerationService(taskRepository: repository)

        let today = Calendar.current.startOfDay(for: .now)
        let todayWeekday = Calendar.current.component(.weekday, from: today)
        let template = RecurringTaskTemplate(title: "Hot yoga", weekdays: [todayWeekday], startHour: 19, startMinute: 0)
        try recurringTaskTemplateRepository.create(template)
        // No occurrences generated yet — load() should top this up before fetching.

        let viewModel = TodayViewModel(
            taskRepository: repository,
            aiInsightService: StubAIInsightService(insight: nil),
            recurringTaskTemplateRepository: recurringTaskTemplateRepository,
            recurringTaskGenerationService: generationService,
            locationReminderService: RecordingLocationReminderService()
        )
        await viewModel.load()

        #expect(viewModel.totalCount == 1)
        #expect(viewModel.anytimeTasks.first?.title == "Hot yoga" || viewModel.afternoonTasks.first?.title == "Hot yoga")
    }

    @Test func stopRepeatingDeactivatesTemplateAndStopsFurtherTopUp() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let templateRepository = SwiftDataRecurringTaskTemplateRepository(context: container.mainContext)
        let generationService = DefaultRecurringTaskGenerationService(taskRepository: repository)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let todayWeekday = calendar.component(.weekday, from: today)
        let template = RecurringTaskTemplate(title: "Hot yoga", weekdays: [todayWeekday], startHour: 19, startMinute: 0)
        try templateRepository.create(template)

        let viewModel = TodayViewModel(
            taskRepository: repository,
            aiInsightService: StubAIInsightService(insight: nil),
            recurringTaskTemplateRepository: templateRepository,
            recurringTaskGenerationService: generationService,
            locationReminderService: RecordingLocationReminderService()
        )
        await viewModel.load()
        let occurrence = try #require(
            (viewModel.anytimeTasks + viewModel.afternoonTasks + viewModel.morningTasks).first
        )
        #expect(try templateRepository.fetchAllActive().count == 1)

        await viewModel.stopRepeating(occurrence)

        #expect(!template.isActive)
        #expect(try templateRepository.fetchAllActive().isEmpty)

        // Delete every generated occurrence, so an active template would
        // certainly be topped back up on the next load.
        for task in try repository.fetchAll() {
            try repository.delete(task)
        }
        await viewModel.load()
        #expect(try repository.fetchAll().isEmpty)
        #expect(viewModel.totalCount == 0)
    }

    @Test func stopRepeatingIsANoOpForNonRecurringTasks() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "One-off", dueDate: .now)
        try repository.create(task)

        let viewModel = makeViewModel(
            context: container.mainContext,
            taskRepository: repository,
            aiInsightService: StubAIInsightService(insight: nil)
        )
        await viewModel.load()

        await viewModel.stopRepeating(task)

        #expect(viewModel.errorMessage == nil)
        #expect(try repository.fetchAll().count == 1)
    }

    @Test func toggleCompletionStopsLocationMonitoringWhenCompletingATaskWithALocationReminder() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let reminder = LocationReminder(name: "Home", address: "123 Main St", latitude: 37.0, longitude: -122.0, trigger: .arriving)
        let task = TaskItem(title: "Water plants", dueDate: .now)
        task.locationReminder = reminder
        try repository.create(task)

        let locationService = RecordingLocationReminderService()
        let viewModel = makeViewModel(
            context: container.mainContext,
            taskRepository: repository,
            aiInsightService: StubAIInsightService(insight: nil),
            locationReminderService: locationService
        )
        await viewModel.load()

        await viewModel.toggleCompletion(task)

        #expect(locationService.stoppedReminderIDs == [reminder.id])
    }

    @Test func toggleCompletionResumesLocationMonitoringWhenUncompletingATaskWithALocationReminder() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let reminder = LocationReminder(name: "Home", address: "123 Main St", latitude: 37.0, longitude: -122.0, trigger: .arriving)
        let task = TaskItem(title: "Water plants", isCompleted: true, dueDate: .now)
        task.locationReminder = reminder
        try repository.create(task)

        let locationService = RecordingLocationReminderService()
        let viewModel = makeViewModel(
            context: container.mainContext,
            taskRepository: repository,
            aiInsightService: StubAIInsightService(insight: nil),
            locationReminderService: locationService
        )
        await viewModel.load()

        await viewModel.toggleCompletion(task)

        #expect(locationService.startedReminderIDs == [reminder.id])
    }
}

private struct StubAIInsightService: AIInsightService {
    let insight: AIInsight?
    func generateInsight(for tasks: [TaskItem]) async -> AIInsight? { insight }
}

private final class RecordingAIInsightService: AIInsightService {
    private(set) var lastTaskCount: Int?

    func generateInsight(for tasks: [TaskItem]) async -> AIInsight? {
        lastTaskCount = tasks.count
        return AIInsight(message: "\(tasks.count) remaining")
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
