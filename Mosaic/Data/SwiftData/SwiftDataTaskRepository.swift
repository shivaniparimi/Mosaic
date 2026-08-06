import Foundation
import SwiftData

@MainActor
final class SwiftDataTaskRepository: TaskRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [TaskItem] {
        try context.fetch(FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    func fetchInbox() throws -> [TaskItem] {
        let predicate = #Predicate<TaskItem> { $0.capturedAt != nil && $0.isCompleted == false }
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func create(_ task: TaskItem) throws {
        context.insert(task)
        try save()
    }

    func createMany(_ tasks: [TaskItem]) throws {
        for task in tasks {
            context.insert(task)
        }
        try save()
    }

    func update(_ task: TaskItem) throws {
        try save()
    }

    func delete(_ task: TaskItem) throws {
        context.delete(task)
        try save()
    }

    func toggleCompletion(_ task: TaskItem) throws {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? .now : nil
        try save()
    }

    func addSubtask(_ subtask: Subtask, to task: TaskItem) throws {
        subtask.task = task
        task.subtasks.append(subtask)
        context.insert(subtask)
        try save()
    }

    func toggleSubtaskCompletion(_ subtask: Subtask) throws {
        subtask.isCompleted.toggle()
        try save()
    }

    func deleteSubtask(_ subtask: Subtask) throws {
        context.delete(subtask)
        try save()
    }

    func search(query: String) throws -> [TaskItem] {
        let predicate = #Predicate<TaskItem> { task in
            task.title.localizedStandardContains(query) ||
            task.notes?.localizedStandardContains(query) == true
        }
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func addAttachment(_ attachment: TaskAttachment, to task: TaskItem) throws {
        attachment.task = task
        task.attachments.append(attachment)
        context.insert(attachment)
        try save()
    }

    func deleteAttachment(_ attachment: TaskAttachment) throws {
        context.delete(attachment)
        try save()
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        NotificationCenter.default.post(name: .taskDataDidChange, object: nil)
    }
}
