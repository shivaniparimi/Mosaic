import Testing
import SwiftData
import Foundation
@testable import Mosaic

@MainActor
struct SearchViewModelTests {
    private func makeViewModel(context: ModelContext) -> SearchViewModel {
        SearchViewModel(
            taskRepository: SwiftDataTaskRepository(context: context),
            projectRepository: SwiftDataProjectRepository(context: context),
            tagRepository: SwiftDataTagRepository(context: context)
        )
    }

    @Test func applySearchReturnsMatchingTasksProjectsAndTags() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let projectRepository = SwiftDataProjectRepository(context: container.mainContext)
        let tagRepository = SwiftDataTagRepository(context: container.mainContext)

        try taskRepository.create(TaskItem(title: "Buy design supplies"))
        try taskRepository.create(TaskItem(title: "Unrelated task"))
        try projectRepository.create(Project(name: "Design Sprint", colorHex: "#4C6EF5"))
        try projectRepository.create(Project(name: "Marketing", colorHex: "#51CF66"))
        _ = try tagRepository.findOrCreate(name: "design")
        _ = try tagRepository.findOrCreate(name: "urgent")

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.applySearch(for: "design")

        #expect(viewModel.taskResults.map(\.title) == ["Buy design supplies"])
        #expect(viewModel.projectResults.map(\.name) == ["Design Sprint"])
        #expect(viewModel.tagResults.map(\.name) == ["design"])
    }

    @Test func applySearchMatchesTaskNotes() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        try taskRepository.create(TaskItem(title: "Team sync", notes: "Discuss the roadmap"))

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.applySearch(for: "roadmap")

        #expect(viewModel.taskResults.map(\.title) == ["Team sync"])
    }

    @Test func applySearchWithBlankQueryClearsAllResults() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        try taskRepository.create(TaskItem(title: "Design review"))

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.applySearch(for: "design")
        #expect(!viewModel.taskResults.isEmpty)

        await viewModel.applySearch(for: "   ")

        #expect(viewModel.taskResults.isEmpty)
        #expect(viewModel.projectResults.isEmpty)
        #expect(viewModel.tagResults.isEmpty)
    }

    @Test func selectProjectFilterNarrowsTaskResultsButNotProjectOrTagResults() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let projectRepository = SwiftDataProjectRepository(context: container.mainContext)

        let designProject = Project(name: "Design Sprint", colorHex: "#4C6EF5")
        let marketingProject = Project(name: "Design Marketing", colorHex: "#51CF66")
        try projectRepository.create(designProject)
        try projectRepository.create(marketingProject)
        try taskRepository.create(TaskItem(title: "Design task A", project: designProject))
        try taskRepository.create(TaskItem(title: "Design task B", project: marketingProject))

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.applySearch(for: "design")
        #expect(viewModel.taskResults.count == 2)
        #expect(viewModel.projectResults.count == 2)

        viewModel.query = "design"
        await viewModel.selectProjectFilter(designProject)

        #expect(viewModel.taskResults.map(\.title) == ["Design task A"])
        #expect(viewModel.projectResults.count == 2)
    }

    @Test func clearProjectFilterRestoresUnfilteredTaskResults() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let projectRepository = SwiftDataProjectRepository(context: container.mainContext)

        let designProject = Project(name: "Design Sprint", colorHex: "#4C6EF5")
        try projectRepository.create(designProject)
        try taskRepository.create(TaskItem(title: "Design task A", project: designProject))
        try taskRepository.create(TaskItem(title: "Design task B"))

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.applySearch(for: "design")
        viewModel.query = "design"
        await viewModel.selectProjectFilter(designProject)
        #expect(viewModel.taskResults.count == 1)

        await viewModel.clearProjectFilter()

        #expect(viewModel.taskResults.count == 2)
    }

    @Test func submitSearchAddsToRecentSearchesNewestFirst() {
        let container = TestModelContainer.makeInMemory()
        let viewModel = makeViewModel(context: container.mainContext)

        viewModel.query = "design"
        viewModel.submitSearch()
        viewModel.query = "marketing"
        viewModel.submitSearch()

        #expect(viewModel.recentSearches == ["marketing", "design"])
    }

    @Test func submitSearchMovesExistingEntryToFrontInsteadOfDuplicating() {
        let container = TestModelContainer.makeInMemory()
        let viewModel = makeViewModel(context: container.mainContext)

        viewModel.query = "design"
        viewModel.submitSearch()
        viewModel.query = "marketing"
        viewModel.submitSearch()
        viewModel.query = "design"
        viewModel.submitSearch()

        #expect(viewModel.recentSearches == ["design", "marketing"])
    }

    @Test func submitSearchCapsRecentSearchesAtTen() {
        let container = TestModelContainer.makeInMemory()
        let viewModel = makeViewModel(context: container.mainContext)

        for i in 1...11 {
            viewModel.query = "search \(i)"
            viewModel.submitSearch()
        }

        #expect(viewModel.recentSearches.count == 10)
        #expect(viewModel.recentSearches.first == "search 11")
        #expect(!viewModel.recentSearches.contains("search 1"))
    }

    @Test func submitSearchIsANoOpForBlankQuery() {
        let container = TestModelContainer.makeInMemory()
        let viewModel = makeViewModel(context: container.mainContext)

        viewModel.query = "   "
        viewModel.submitSearch()

        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test func selectRecentSearchSetsQueryAndPopulatesResults() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        try taskRepository.create(TaskItem(title: "Design review"))

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.selectRecentSearch("design")

        #expect(viewModel.query == "design")
        #expect(viewModel.taskResults.map(\.title) == ["Design review"])
    }
}
