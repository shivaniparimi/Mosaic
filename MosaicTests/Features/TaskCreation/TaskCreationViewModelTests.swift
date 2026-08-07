import Testing
import SwiftData
import Foundation
@testable import Mosaic

@MainActor
struct TaskCreationViewModelTests {
    private func makeViewModel(context: ModelContext) -> TaskCreationViewModel {
        TaskCreationViewModel(
            taskRepository: SwiftDataTaskRepository(context: context),
            tagRepository: SwiftDataTagRepository(context: context),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: context),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(
                taskRepository: SwiftDataTaskRepository(context: context)
            ),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService()
        )
    }

    @Test func canCreateIsFalseForEmptyOrWhitespaceInput() {
        let container = TestModelContainer.makeInMemory()
        let viewModel = makeViewModel(context: container.mainContext)

        #expect(!viewModel.canCreate)
        viewModel.inputText = "   "
        #expect(!viewModel.canCreate)
        viewModel.inputText = "buy milk"
        #expect(viewModel.canCreate)
    }

    @Test func scheduleParseDebouncesBeforeUpdatingDraft() async throws {
        let container = TestModelContainer.makeInMemory()
        let viewModel = makeViewModel(context: container.mainContext)

        viewModel.inputText = "buy milk today"
        viewModel.scheduleParse()

        #expect(viewModel.draft == nil)

        try await Task.sleep(for: .milliseconds(600))

        #expect(viewModel.draft?.date != nil)
    }

    @Test func createTaskAnchorsDueTimeToResolvedDueDateNotNow() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = TaskCreationViewModel(
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: container.mainContext),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService()
        )

        viewModel.inputText = "email Haley tomorrow at 2 PM"
        viewModel.scheduleParse()
        try await Task.sleep(for: .milliseconds(600))

        let created = await viewModel.createTask()
        #expect(created)

        let tasks = try taskRepository.fetchAll()
        let task = try #require(tasks.first)
        let dueDate = try #require(task.dueDate)
        let dueTime = try #require(task.dueTime)
        #expect(Calendar.current.isDate(dueDate, inSameDayAs: dueTime))
    }

    @Test func createTaskDefaultsToTodayWhenNoDateDetected() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = TaskCreationViewModel(
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: container.mainContext),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService()
        )

        viewModel.inputText = "remind me call dentist"
        let created = await viewModel.createTask()
        #expect(created)

        let tasks = try taskRepository.fetchAll()
        let task = try #require(tasks.first)
        #expect(Calendar.current.isDateInToday(task.dueDate!))
        #expect(task.hasReminder == true)
    }

    @Test func createTaskCapturesToInboxWhenNoDateDetectedAndCapturesToInboxIsTrue() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = TaskCreationViewModel(
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: container.mainContext),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService(),
            capturesToInbox: true
        )

        viewModel.inputText = "call dentist"
        let created = await viewModel.createTask()
        #expect(created)

        let tasks = try taskRepository.fetchAll()
        let task = try #require(tasks.first)
        #expect(task.capturedAt != nil)
        #expect(task.dueDate == nil)
        #expect(task.origin == .quickCapture)
    }

    @Test func createTaskRespectsExplicitDateEvenWhenCapturesToInboxIsTrue() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = TaskCreationViewModel(
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: container.mainContext),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService(),
            capturesToInbox: true
        )

        viewModel.inputText = "call dentist tomorrow"
        let created = await viewModel.createTask()
        #expect(created)

        let tasks = try taskRepository.fetchAll()
        let task = try #require(tasks.first)
        #expect(task.dueDate != nil)
        #expect(task.capturedAt == nil)
    }

    @Test func createTaskDerivesMorningBucketForEarlyTime() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = TaskCreationViewModel(
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: container.mainContext),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService()
        )

        viewModel.inputText = "standup at 9 AM"
        viewModel.scheduleParse()
        try await Task.sleep(for: .milliseconds(600))
        await viewModel.createTask()

        let tasks = try taskRepository.fetchAll()
        #expect(tasks.first?.timeOfDay == .morning)
    }

    @Test func createTaskDerivesAnytimeBucketWhenNoTimeDetected() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = TaskCreationViewModel(
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: container.mainContext),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService()
        )

        viewModel.inputText = "buy milk"
        let created = await viewModel.createTask()
        #expect(created)

        let tasks = try taskRepository.fetchAll()
        #expect(tasks.first?.timeOfDay == .anytime)
    }

    @Test func clearMethodsRemoveOnlyTheirOwnField() async throws {
        let container = TestModelContainer.makeInMemory()
        let viewModel = makeViewModel(context: container.mainContext)

        viewModel.inputText = "design review at 9 AM #urgent"
        viewModel.scheduleParse()
        try await Task.sleep(for: .milliseconds(600))

        let draftBefore = try #require(viewModel.draft)
        #expect(draftBefore.timeComponents != nil)
        #expect(draftBefore.tagName != nil)

        viewModel.clearTime()

        #expect(viewModel.draft?.timeComponents == nil)
        #expect(viewModel.draft?.tagName != nil)
    }

    @Test func createTaskUsesFreshDraftWhenCreatedBeforeDebounceSettles() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = TaskCreationViewModel(
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: container.mainContext),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService()
        )

        viewModel.inputText = "buy milk"
        viewModel.scheduleParse()
        try await Task.sleep(for: .milliseconds(600))
        #expect(viewModel.draft?.date == nil)

        // Edit the text and immediately try to create, without waiting for the
        // new 420ms debounce to settle. `draft` still reflects the stale
        // "buy milk" parse at this point.
        viewModel.inputText = "buy milk tomorrow"
        viewModel.scheduleParse()

        let created = await viewModel.createTask()
        #expect(created)

        let tasks = try taskRepository.fetchAll()
        let task = try #require(tasks.first)
        let dueDate = try #require(task.dueDate)
        let calendar = Calendar.current
        let expectedTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))
        #expect(calendar.isDate(dueDate, inSameDayAs: try #require(expectedTomorrow)))
    }

    /// Regression test for the "permanently stuck partial parse" bug.
    ///
    /// SwiftUI does not guarantee that `.onChange`'s action runs for every
    /// mutation of the observed value: under rapid successive keystrokes it
    /// re-evaluates `body` with the new text but drops some `onChange`
    /// invocations. That leaves the last surviving debounce timer as the only
    /// one that will fire, so it must parse the text as it stands when the
    /// pause elapses — not the snapshot taken when it was scheduled.
    ///
    /// Simulated here by typing the whole phrase but calling `scheduleParse()`
    /// only for a truncated prefix, exactly as a dropped `onChange` would.
    @Test func debouncedParseUsesLatestInputTextWhenOnChangeCallbacksAreDropped() async throws {
        let container = TestModelContainer.makeInMemory()
        let viewModel = makeViewModel(context: container.mainContext)

        // The last `onChange` that actually fired saw the truncated text...
        viewModel.inputText = "hot yoga 7-8pm mon wed f"
        viewModel.scheduleParse()
        // ...and the final two keystrokes landed without one.
        viewModel.inputText = "hot yoga 7-8pm mon wed fri"

        try await Task.sleep(for: .milliseconds(700))

        #expect(viewModel.draft?.cleanedTitle == "hot yoga")
        #expect(viewModel.draft?.recurringWeekdays == [2, 4, 6])
    }

    @Test func createTaskOmitsStartTimeForRecurringInputWithNoTime() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let recurringTaskTemplateRepository = SwiftDataRecurringTaskTemplateRepository(context: container.mainContext)
        let viewModel = TaskCreationViewModel(
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: recurringTaskTemplateRepository,
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService()
        )

        viewModel.inputText = "walk dog mon wed fri"
        #expect(await viewModel.createTask())

        let template = try #require(try recurringTaskTemplateRepository.fetchAllActive().first)
        #expect(template.startHour == nil)
        #expect(template.startMinute == nil)

        let occurrences = try taskRepository.fetchAll()
        #expect(!occurrences.isEmpty)
        #expect(occurrences.allSatisfy { $0.dueTime == nil })
        #expect(occurrences.allSatisfy { $0.timeOfDay == .anytime })
    }

    @Test func clearRecurringWeekdaysAndClearTimeRangeRemoveOnlyTheirOwnField() async throws {
        let container = TestModelContainer.makeInMemory()
        let viewModel = makeViewModel(context: container.mainContext)

        viewModel.inputText = "hot yoga 7-8pm mon wed fri"
        viewModel.scheduleParse()
        try await Task.sleep(for: .milliseconds(600))

        #expect(viewModel.draft?.recurringWeekdays == [2, 4, 6])
        #expect(viewModel.draft?.timeRangeComponents != nil)

        viewModel.clearTimeRange()
        #expect(viewModel.draft?.timeRangeComponents == nil)
        #expect(viewModel.draft?.recurringWeekdays == [2, 4, 6])

        viewModel.clearRecurringWeekdays()
        #expect(viewModel.draft?.recurringWeekdays == nil)
    }

    @Test func createTaskSetsErrorMessageOnFailure() async {
        let container = TestModelContainer.makeInMemory()
        let viewModel = TaskCreationViewModel(
            taskRepository: AlwaysFailingTaskRepository(),
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: container.mainContext),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(
                taskRepository: SwiftDataTaskRepository(context: container.mainContext)
            ),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService()
        )

        viewModel.inputText = "buy milk"
        let created = await viewModel.createTask()

        #expect(!created)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func createTaskClearsErrorMessageOnSuccess() async {
        let container = TestModelContainer.makeInMemory()
        let failingViewModel = TaskCreationViewModel(
            taskRepository: AlwaysFailingTaskRepository(),
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: container.mainContext),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(
                taskRepository: SwiftDataTaskRepository(context: container.mainContext)
            ),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService()
        )
        failingViewModel.inputText = "buy milk"
        _ = await failingViewModel.createTask()
        #expect(failingViewModel.errorMessage != nil)

        let viewModel = makeViewModel(context: container.mainContext)
        viewModel.inputText = "buy milk"
        let created = await viewModel.createTask()

        #expect(created)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func createTaskStoresCleanedTitleWithoutParsedTokens() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let viewModel = TaskCreationViewModel(
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: container.mainContext),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService()
        )

        viewModel.inputText = "email Haley tomorrow at 2 PM"
        let created = await viewModel.createTask()
        #expect(created)

        let tasks = try taskRepository.fetchAll()
        #expect(tasks.first?.title == "email Haley")
    }

    @Test func createTaskRoutesToRecurringTemplateWhenTwoOrMoreWeekdaysDetected() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let recurringTaskTemplateRepository = SwiftDataRecurringTaskTemplateRepository(context: container.mainContext)
        let viewModel = TaskCreationViewModel(
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: recurringTaskTemplateRepository,
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService()
        )

        viewModel.inputText = "hot yoga 7-8pm mon wed fri"
        let created = await viewModel.createTask()

        #expect(created)
        let templates = try recurringTaskTemplateRepository.fetchAllActive()
        #expect(templates.count == 1)
        #expect(templates.first?.title == "hot yoga")
        #expect(Set(templates.first?.weekdays ?? []) == [2, 4, 6])

        let generatedTasks = try taskRepository.fetchAll()
        #expect(!generatedTasks.isEmpty)
        #expect(generatedTasks.allSatisfy { $0.recurringTemplate != nil })
    }

    @Test func createTaskSingleWeekdayStillUsesOneOffPath() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let recurringTaskTemplateRepository = SwiftDataRecurringTaskTemplateRepository(context: container.mainContext)
        let viewModel = TaskCreationViewModel(
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: recurringTaskTemplateRepository,
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: RecordingNotificationService()
        )

        viewModel.inputText = "dentist appointment monday"
        let created = await viewModel.createTask()

        #expect(created)
        let templates = try recurringTaskTemplateRepository.fetchAllActive()
        #expect(templates.isEmpty)

        let tasks = try taskRepository.fetchAll()
        #expect(tasks.count == 1)
        #expect(tasks.first?.recurringTemplate == nil)
    }

    @Test func createTaskSchedulesReminderWhenTaskHasOne() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let notificationService = RecordingNotificationService()
        let viewModel = TaskCreationViewModel(
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: container.mainContext),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            parsingService: DefaultNaturalLanguageParsingService(),
            notificationService: notificationService
        )

        viewModel.inputText = "call mom tomorrow at 9am"
        let created = await viewModel.createTask()
        #expect(created)

        try await Task.sleep(for: .milliseconds(50))

        let tasks = try taskRepository.fetchAll()
        let createdTask = try #require(tasks.first)
        #expect(notificationService.scheduledTaskIDs == [createdTask.id])
    }
}

@MainActor
private struct AlwaysFailingTaskRepository: TaskRepository {
    func fetchAll() throws -> [TaskItem] { [] }
    func fetchInbox() throws -> [TaskItem] { [] }
    func create(_ task: TaskItem) throws { throw NSError(domain: "test", code: 1) }
    func createMany(_ tasks: [TaskItem]) throws { throw NSError(domain: "test", code: 1) }
    func update(_ task: TaskItem) throws { }
    func delete(_ task: TaskItem) throws { }
    func toggleCompletion(_ task: TaskItem) throws { }
    func search(query: String) throws -> [TaskItem] { [] }
    func addSubtask(_ subtask: Subtask, to task: TaskItem) throws { }
    func toggleSubtaskCompletion(_ subtask: Subtask) throws { }
    func deleteSubtask(_ subtask: Subtask) throws { }
    func addAttachment(_ attachment: TaskAttachment, to task: TaskItem) throws { }
    func deleteAttachment(_ attachment: TaskAttachment) throws { }
}

private final class RecordingNotificationService: NotificationService {
    private(set) var scheduledTaskIDs: [UUID] = []
    private(set) var cancelledTaskIDs: [UUID] = []

    func requestAuthorization() async -> Bool { true }

    func scheduleReminder(for reminder: TaskReminderInfo) async {
        scheduledTaskIDs.append(reminder.id)
    }

    func cancelReminder(id: UUID) async {
        cancelledTaskIDs.append(id)
    }

    func cancelAllReminders() async {}

    func postLocationAlert(identifier: String, title: String, body: String) async {}
}
