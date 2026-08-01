@MainActor
protocol TagRepository {
    func fetchAll() throws -> [Tag]
    func findOrCreate(name: String) throws -> Tag
    func delete(_ tag: Tag) throws
}
