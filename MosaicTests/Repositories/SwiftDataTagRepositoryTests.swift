import Testing
@testable import Mosaic

@MainActor
struct SwiftDataTagRepositoryTests {
    @Test func findOrCreateReturnsSameTagOnSecondCall() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTagRepository(context: container.mainContext)

        let first = try repository.findOrCreate(name: "urgent")
        let second = try repository.findOrCreate(name: "urgent")

        #expect(first.name == second.name)
        #expect(try repository.fetchAll().count == 1)
    }
}
