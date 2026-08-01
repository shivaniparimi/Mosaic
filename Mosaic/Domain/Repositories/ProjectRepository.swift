@MainActor
protocol ProjectRepository {
    func fetchAll() throws -> [Project]
    func create(_ project: Project) throws
    func update(_ project: Project) throws
    func delete(_ project: Project) throws
}
