import Foundation

@Observable
@MainActor
final class ProjectsViewModel {
    private(set) var projects: [Project] = []
    private(set) var insight: AIInsight?
    private(set) var errorMessage: String?

    private let projectRepository: ProjectRepository
    private let taskRepository: TaskRepository
    private let aiInsightService: AIInsightService

    init(projectRepository: ProjectRepository, taskRepository: TaskRepository, aiInsightService: AIInsightService) {
        self.projectRepository = projectRepository
        self.taskRepository = taskRepository
        self.aiInsightService = aiInsightService
    }

    func load() async {
        do {
            projects = try projectRepository.fetchAll()
        } catch {
            errorMessage = "Couldn't load your projects."
            return
        }

        let allTasks = (try? taskRepository.fetchAll()) ?? []
        let projectTasks = allTasks.filter { $0.project != nil && !$0.isCompleted }
        insight = await aiInsightService.generateInsight(for: projectTasks)
        errorMessage = nil
    }

    func delete(_ project: Project) async {
        do {
            try projectRepository.delete(project)
        } catch {
            errorMessage = "Couldn't delete that project."
            return
        }

        projects.removeAll { $0.persistentModelID == project.persistentModelID }
        errorMessage = nil
        await load()
    }

    func progress(for project: Project) -> (completed: Int, total: Int) {
        let completed = project.tasks.filter(\.isCompleted).count
        return (completed, project.tasks.count)
    }
}
