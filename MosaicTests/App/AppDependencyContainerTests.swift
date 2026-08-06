import Testing
import SwiftUI
@testable import Mosaic

@MainActor
struct AppDependencyContainerTests {
    @Test func previewContainerWiresWorkingTaskRepository() throws {
        let container = AppDependencyContainer.preview()

        try container.taskRepository.create(TaskItem(title: "Smoke test"))

        let tasks = try container.taskRepository.fetchAll()
        #expect(tasks.count == 1)
    }

    @Test func previewContainerWiresWorkingProjectAndTagRepositories() throws {
        let container = AppDependencyContainer.preview()

        try container.projectRepository.create(Project(name: "Test Project", colorHex: "#000000"))
        _ = try container.tagRepository.findOrCreate(name: "test")

        #expect(try container.projectRepository.fetchAll().count == 1)
        #expect(try container.tagRepository.fetchAll().count == 1)
    }

    @Test func previewContainerWiresAIInsightService() {
        let container = AppDependencyContainer.preview()
        #expect(container.aiInsightService is DefaultAIInsightService)
    }

    @Test func makeTodayViewModelBuildsWorkingViewModel() async throws {
        let container = AppDependencyContainer.preview()
        try container.taskRepository.create(TaskItem(title: "Smoke", dueDate: .now))

        let viewModel = container.makeTodayViewModel()
        await viewModel.load()

        #expect(viewModel.totalCount == 1)
    }

    @Test func environmentDefaultValueResolvesWithoutTrapping() {
        let values = EnvironmentValues()
        let container = values.dependencies
        #expect(container.taskRepository is SwiftDataTaskRepository)
    }

    @Test func previewContainerWiresRecurringTaskDependencies() throws {
        let container = AppDependencyContainer.preview()
        #expect(container.recurringTaskTemplateRepository is SwiftDataRecurringTaskTemplateRepository)
        #expect(container.recurringTaskGenerationService is DefaultRecurringTaskGenerationService)
    }

    @Test func makeTaskCreationViewModelBuildsWorkingRecurringPath() async throws {
        let container = AppDependencyContainer.preview()

        let viewModel = container.makeTaskCreationViewModel()
        viewModel.inputText = "hot yoga 7-8pm mon wed fri"
        let created = await viewModel.createTask()

        #expect(created)
        let templates = try container.recurringTaskTemplateRepository.fetchAllActive()
        #expect(templates.count == 1)
    }

    @Test func makeInboxViewModelBuildsWorkingViewModel() async throws {
        let container = AppDependencyContainer.preview()
        try container.taskRepository.create(TaskItem(title: "Smoke", capturedAt: .now))

        let viewModel = container.makeInboxViewModel()
        await viewModel.load()

        #expect(viewModel.items.count == 1)
    }

    @Test func makeProjectsViewModelBuildsWorkingViewModel() async throws {
        let container = AppDependencyContainer.preview()
        try container.projectRepository.create(Project(name: "Smoke", colorHex: "#4C6EF5"))

        let viewModel = container.makeProjectsViewModel()
        await viewModel.load()

        #expect(viewModel.projects.count == 1)
    }

    @Test func makeNewProjectViewModelBuildsWorkingViewModel() throws {
        let container = AppDependencyContainer.preview()

        let viewModel = container.makeNewProjectViewModel()
        viewModel.name = "Smoke Project"
        let created = viewModel.createProject()

        #expect(created)
        #expect(try container.projectRepository.fetchAll().count == 1)
    }

    @Test func makeSearchViewModelBuildsWorkingViewModel() async throws {
        let container = AppDependencyContainer.preview()
        try container.taskRepository.create(TaskItem(title: "Design review"))

        let viewModel = container.makeSearchViewModel()
        await viewModel.applySearch(for: "design")

        #expect(viewModel.taskResults.count == 1)
    }

    @Test func makeTaskDetailViewModelBuildsWorkingViewModel() throws {
        let container = AppDependencyContainer.preview()
        let task = TaskItem(title: "Smoke")
        try container.taskRepository.create(task)

        let viewModel = container.makeTaskDetailViewModel(task: task)
        viewModel.setPriority(.high)

        #expect(task.priority == .high)
    }

    @Test func makeSettingsViewModelBuildsWorkingViewModel() {
        let container = AppDependencyContainer.preview()
        UserDefaults.standard.removeObject(forKey: SettingsKeys.theme)

        let viewModel = container.makeSettingsViewModel()

        #expect(viewModel.theme == .system)
    }

    @Test func previewContainerWiresNotificationService() {
        let container = AppDependencyContainer.preview()
        #expect(container.notificationService is UserNotificationService)
    }

    @Test func previewContainerWiresLocationReminderService() {
        let container = AppDependencyContainer.preview()
        #expect(container.locationReminderService is CLLocationReminderService)
    }

    @Test func eligibleLocationRemindersExcludesCompletedTasks() {
        let activeReminder = LocationReminder(name: "Home", address: "123 Main St", latitude: 37.0, longitude: -122.0, trigger: .arriving)
        let activeTask = TaskItem(title: "Water plants")
        activeTask.locationReminder = activeReminder

        let completedReminder = LocationReminder(name: "Office", address: "456 Elm St", latitude: 37.1, longitude: -122.1, trigger: .leaving)
        let completedTask = TaskItem(title: "Submit report", isCompleted: true)
        completedTask.locationReminder = completedReminder

        let reminders = AppDependencyContainer.eligibleLocationReminders(from: [activeTask, completedTask])

        #expect(reminders.map(\.reminderID) == [activeReminder.id])
    }

    @Test func previewContainerWiresAttachmentStorageService() {
        let container = AppDependencyContainer.preview()
        #expect(container.attachmentStorageService is FileManagerAttachmentStorageService)
    }
}
