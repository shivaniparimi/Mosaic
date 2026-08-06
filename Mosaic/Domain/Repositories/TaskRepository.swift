import Foundation

extension Notification.Name {
    static let taskDataDidChange = Notification.Name("taskDataDidChange")
}

@MainActor
protocol TaskRepository {
    func fetchAll() throws -> [TaskItem]
    func fetchInbox() throws -> [TaskItem]
    func create(_ task: TaskItem) throws
    func createMany(_ tasks: [TaskItem]) throws
    func update(_ task: TaskItem) throws
    func delete(_ task: TaskItem) throws
    func toggleCompletion(_ task: TaskItem) throws
    func search(query: String) throws -> [TaskItem]
    func addSubtask(_ subtask: Subtask, to task: TaskItem) throws
    func toggleSubtaskCompletion(_ subtask: Subtask) throws
    func deleteSubtask(_ subtask: Subtask) throws
    func addAttachment(_ attachment: TaskAttachment, to task: TaskItem) throws
    func deleteAttachment(_ attachment: TaskAttachment) throws
}
