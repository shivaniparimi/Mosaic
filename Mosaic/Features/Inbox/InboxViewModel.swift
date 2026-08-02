import Foundation

@Observable
@MainActor
final class InboxViewModel {
    private(set) var items: [TaskItem] = []
    var captureText: String = ""
    private(set) var errorMessage: String?

    private let taskRepository: TaskRepository

    init(taskRepository: TaskRepository) {
        self.taskRepository = taskRepository
    }

    var canCapture: Bool {
        !captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load() async {
        do {
            items = try taskRepository.fetchInbox()
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load your inbox."
        }
    }

    func capture() async {
        guard canCapture else { return }
        let title = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        let task = TaskItem(title: title, capturedAt: .now, origin: .quickCapture)

        do {
            try taskRepository.create(task)
        } catch {
            errorMessage = "Couldn't capture that task."
            return
        }

        captureText = ""
        errorMessage = nil
        await load()
    }

    func moveToToday(_ task: TaskItem) async {
        task.capturedAt = nil
        task.dueDate = Calendar.current.startOfDay(for: .now)
        task.timeOfDay = .anytime

        do {
            try taskRepository.update(task)
        } catch {
            errorMessage = "Couldn't move that task to Today."
            await load()
            return
        }

        errorMessage = nil
        await load()
    }

    func toggleCompletion(_ task: TaskItem) async {
        do {
            try taskRepository.toggleCompletion(task)
        } catch {
            errorMessage = "Couldn't update that task."
            return
        }

        errorMessage = nil
        await load()
    }
}
