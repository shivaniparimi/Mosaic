import Testing
import SwiftData
import Foundation
@testable import Mosaic

@MainActor
struct SearchViewModelTests {
    private func makeViewModel(context: ModelContext) -> SearchViewModel {
        SearchViewModel(
            taskRepository: SwiftDataTaskRepository(context: context),
            tagRepository: SwiftDataTagRepository(context: context)
        )
    }

    @Test func applySearchReturnsMatchingTasksAndTags() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let tagRepository = SwiftDataTagRepository(context: container.mainContext)

        try taskRepository.create(TaskItem(title: "Buy design supplies"))
        try taskRepository.create(TaskItem(title: "Unrelated task"))
        _ = try tagRepository.findOrCreate(name: "design")
        _ = try tagRepository.findOrCreate(name: "urgent")

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.applySearch(for: "design")

        #expect(viewModel.taskResults.map(\.title) == ["Buy design supplies"])
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
        #expect(viewModel.tagResults.isEmpty)
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
