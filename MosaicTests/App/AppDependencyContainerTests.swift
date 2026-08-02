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
}
