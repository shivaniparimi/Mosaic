import Foundation

@Observable
@MainActor
final class SearchViewModel {
    var query: String = ""
    private(set) var taskResults: [TaskItem] = []
    private(set) var tagResults: [Tag] = []
    private(set) var recentSearches: [String] = []
    private(set) var errorMessage: String?

    private let taskRepository: TaskRepository
    private let tagRepository: TagRepository
    private var searchTask: Task<Void, Never>?

    init(taskRepository: TaskRepository, tagRepository: TagRepository) {
        self.taskRepository = taskRepository
        self.tagRepository = tagRepository
    }

    var hasResults: Bool {
        !taskResults.isEmpty || !tagResults.isEmpty
    }

    func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled, let self else { return }
            await self.applySearch(for: self.query)
        }
    }

    func applySearch(for text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            taskResults = []
            tagResults = []
            errorMessage = nil
            return
        }

        do {
            taskResults = try taskRepository.search(query: trimmed)
        } catch {
            errorMessage = "Couldn't search your tasks."
            taskResults = []
            tagResults = []
            return
        }

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

    func selectRecentSearch(_ text: String) async {
        query = text
        searchTask?.cancel()
        await applySearch(for: text)
    }
}
