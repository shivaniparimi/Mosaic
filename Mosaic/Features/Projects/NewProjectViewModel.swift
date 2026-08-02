import Foundation

@Observable
@MainActor
final class NewProjectViewModel {
    var name: String = ""
    private(set) var selectedColorHex: String = "#E8738A"
    private(set) var errorMessage: String?

    private let projectRepository: ProjectRepository

    init(projectRepository: ProjectRepository) {
        self.projectRepository = projectRepository
    }

    var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func selectColor(_ hex: String) {
        selectedColorHex = hex
    }

    func clearError() {
        errorMessage = nil
    }

    @discardableResult
    func createProject() -> Bool {
        guard canCreate else { return false }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = Project(name: trimmedName, colorHex: selectedColorHex)

        do {
            try projectRepository.create(project)
        } catch {
            errorMessage = "Couldn't create that project."
            return false
        }

        errorMessage = nil
        return true
    }
}
