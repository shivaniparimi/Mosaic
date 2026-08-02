import Testing
import SwiftData
import Foundation
@testable import Mosaic

@MainActor
struct NewProjectViewModelTests {
    @Test func canCreateReflectsWhetherNameIsNonBlank() {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataProjectRepository(context: container.mainContext)
        let viewModel = NewProjectViewModel(projectRepository: repository)

        #expect(!viewModel.canCreate)
        viewModel.name = "   "
        #expect(!viewModel.canCreate)
        viewModel.name = "Website Redesign"
        #expect(viewModel.canCreate)
    }

    @Test func createProjectCreatesProjectWithTrimmedNameAndSelectedColor() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataProjectRepository(context: container.mainContext)
        let viewModel = NewProjectViewModel(projectRepository: repository)
        viewModel.name = "  Website Redesign  "
        viewModel.selectColor("#51CF66")

        let created = viewModel.createProject()

        #expect(created)
        let projects = try repository.fetchAll()
        #expect(projects.map(\.name) == ["Website Redesign"])
        #expect(projects.first?.colorHex == "#51CF66")
    }

    @Test func createProjectIsANoOpForBlankName() throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataProjectRepository(context: container.mainContext)
        let viewModel = NewProjectViewModel(projectRepository: repository)
        viewModel.name = "   "

        let created = viewModel.createProject()

        #expect(!created)
        #expect(try repository.fetchAll().isEmpty)
    }

    @Test func selectColorUpdatesSelectedColorHex() {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataProjectRepository(context: container.mainContext)
        let viewModel = NewProjectViewModel(projectRepository: repository)

        viewModel.selectColor("#FF6B6B")

        #expect(viewModel.selectedColorHex == "#FF6B6B")
    }

    @Test func defaultSelectedColorHexMatchesFirstPaletteEntry() {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataProjectRepository(context: container.mainContext)
        let viewModel = NewProjectViewModel(projectRepository: repository)

        #expect(viewModel.selectedColorHex == ColorSwatchPicker.palette[0])
    }
}
