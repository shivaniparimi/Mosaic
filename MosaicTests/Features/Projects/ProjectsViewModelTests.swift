import Testing
import SwiftData
import Foundation
@testable import Mosaic

@MainActor
struct ProjectsViewModelTests {
    @Test func loadPopulatesProjectsFromRepository() async throws {
        let container = TestModelContainer.makeInMemory()
        let projectRepository = SwiftDataProjectRepository(context: container.mainContext)
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        try projectRepository.create(Project(name: "Website Redesign", colorHex: "#4C6EF5"))
        try projectRepository.create(Project(name: "Mobile App", colorHex: "#51CF66"))

        let viewModel = ProjectsViewModel(
            projectRepository: projectRepository,
            taskRepository: taskRepository,
            aiInsightService: StubAIInsightService(insight: nil)
        )
        await viewModel.load()

        #expect(viewModel.projects.map(\.name).sorted() == ["Mobile App", "Website Redesign"])
    }

    @Test func progressReturnsCompletedAndTotalFromProjectTasks() async throws {
        let container = TestModelContainer.makeInMemory()
        let projectRepository = SwiftDataProjectRepository(context: container.mainContext)
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let project = Project(name: "Website Redesign", colorHex: "#4C6EF5")
        try projectRepository.create(project)
        try taskRepository.create(TaskItem(title: "Task A", isCompleted: true, project: project))
        try taskRepository.create(TaskItem(title: "Task B", isCompleted: false, project: project))
        try taskRepository.create(TaskItem(title: "Task C", isCompleted: false, project: project))

        let viewModel = ProjectsViewModel(
            projectRepository: projectRepository,
            taskRepository: taskRepository,
            aiInsightService: StubAIInsightService(insight: nil)
        )
        await viewModel.load()
        let loadedProject = try #require(viewModel.projects.first)

        let result = viewModel.progress(for: loadedProject)

        #expect(result.completed == 1)
        #expect(result.total == 3)
    }

    @Test func progressReturnsZeroZeroForProjectWithNoTasks() async throws {
        let container = TestModelContainer.makeInMemory()
        let projectRepository = SwiftDataProjectRepository(context: container.mainContext)
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let project = Project(name: "Empty Project", colorHex: "#4C6EF5")
        try projectRepository.create(project)

        let viewModel = ProjectsViewModel(
            projectRepository: projectRepository,
            taskRepository: taskRepository,
            aiInsightService: StubAIInsightService(insight: nil)
        )
        await viewModel.load()
        let loadedProject = try #require(viewModel.projects.first)

        let result = viewModel.progress(for: loadedProject)

        #expect(result.completed == 0)
        #expect(result.total == 0)
    }

    @Test func loadComputesInsightFromOnlyIncompleteProjectAssignedTasks() async throws {
        let container = TestModelContainer.makeInMemory()
        let projectRepository = SwiftDataProjectRepository(context: container.mainContext)
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let project = Project(name: "Website Redesign", colorHex: "#4C6EF5")
        try projectRepository.create(project)
        try taskRepository.create(TaskItem(title: "In project, incomplete", project: project))
        try taskRepository.create(TaskItem(title: "In project, completed", isCompleted: true, project: project))
        try taskRepository.create(TaskItem(title: "No project"))

        let recordingService = RecordingAIInsightService()
        let viewModel = ProjectsViewModel(
            projectRepository: projectRepository,
            taskRepository: taskRepository,
            aiInsightService: recordingService
        )
        await viewModel.load()

        #expect(recordingService.lastTaskTitles == ["In project, incomplete"])
    }

    @Test func deleteRemovesProjectAndReloads() async throws {
        let container = TestModelContainer.makeInMemory()
        let projectRepository = SwiftDataProjectRepository(context: container.mainContext)
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let project = Project(name: "Temp Project", colorHex: "#4C6EF5")
        try projectRepository.create(project)

        let viewModel = ProjectsViewModel(
            projectRepository: projectRepository,
            taskRepository: taskRepository,
            aiInsightService: StubAIInsightService(insight: nil)
        )
        await viewModel.load()
        #expect(viewModel.projects.count == 1)

        await viewModel.delete(project)

        #expect(viewModel.projects.isEmpty)
        #expect(try projectRepository.fetchAll().isEmpty)
    }
}

private struct StubAIInsightService: AIInsightService {
    let insight: AIInsight?
    func generateInsight(for tasks: [TaskItem]) async -> AIInsight? { insight }
}

private final class RecordingAIInsightService: AIInsightService {
    private(set) var lastTaskTitles: [String]?

    func generateInsight(for tasks: [TaskItem]) async -> AIInsight? {
        lastTaskTitles = tasks.map(\.title)
        return nil
    }
}
