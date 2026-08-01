import Testing
@testable import Mosaic

@MainActor
struct SwiftDataProjectRepositoryTests {
    @Test func createAndFetchAllReturnsCreatedProject() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataProjectRepository(context: container.mainContext)

        try repository.create(Project(name: "Website Redesign", colorHex: "#4C6EF5"))

        let projects = try repository.fetchAll()
        #expect(projects.count == 1)
        #expect(projects.first?.name == "Website Redesign")
    }

    @Test func deleteRemovesProject() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataProjectRepository(context: container.mainContext)
        let project = Project(name: "Temp", colorHex: "#000000")
        try repository.create(project)

        try repository.delete(project)

        #expect(try repository.fetchAll().isEmpty)
    }
}
