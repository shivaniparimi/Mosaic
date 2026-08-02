import Foundation

@Observable
@MainActor
final class SearchViewModel {
    var query: String = ""
    private(set) var selectedProjectFilter: Project?
    private(set) var taskResults: [TaskItem] = []
    private(set) var projectResults: [Project] = []
    private(set) var tagResults: [Tag] = []
    private(set) var recentSearches: [String] = []
    private(set) var errorMessage: String?

    private let taskRepository: TaskRepository
    private let projectRepository: ProjectRepository
    private let tagRepository: TagRepository
    private var searchTask: Task<Void, Never>?

    init(taskRepository: TaskRepository, projectRepository: ProjectRepository, tagRepository: TagRepository) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.tagRepository = tagRepository
    }

    var availableProjectFilters: [Project] {
        (try? projectRepository.fetchAll()) ?? []
    }

    var hasResults: Bool {
        !taskResults.isEmpty || !projectResults.isEmpty || !tagResults.isEmpty
    }

    func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled, let self else { return }
            // Read `query` when the debounce FIRES, not when it was scheduled —
            // same reasoning as TaskCreationViewModel.scheduleParse(): a dropped
            // .onChange under rapid typing must not leave a stale, truncated query.
            await self.applySearch(for: self.query)
        }
    }

    func applySearch(for text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            taskResults = []
            projectResults = []
            tagResults = []
            errorMessage = nil
            return
        }

        do {
            let matchedTasks = try taskRepository.search(query: trimmed)
            if let selectedProjectFilter {
                taskResults = matchedTasks.filter { $0.project?.id == selectedProjectFilter.id }
            } else {
                taskResults = matchedTasks
            }
        } catch {
            errorMessage = "Couldn't search your tasks."
            taskResults = []
            projectResults = []
            tagResults = []
            return
        }

        let allProjects = (try? projectRepository.fetchAll()) ?? []
        projectResults = allProjects.filter { $0.name.localizedStandardContains(trimmed) }

        let allTags = (try? tagRepository.fetchAll()) ?? []
        tagResults = allTags.filter { $0.name.localizedStandardContains(trimmed) }

        errorMessage = nil
    }

    func submitSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 10 {
            recentSearches.removeLast(recentSearches.count - 10)
        }
    }

    func selectProjectFilter(_ project: Project) async {
        selectedProjectFilter = project
        searchTask?.cancel()
        await applySearch(for: query)
    }

    func clearProjectFilter() async {
        selectedProjectFilter = nil
        searchTask?.cancel()
        await applySearch(for: query)
    }

    func selectRecentSearch(_ text: String) async {
        query = text
        searchTask?.cancel()
        await applySearch(for: text)
    }
}
