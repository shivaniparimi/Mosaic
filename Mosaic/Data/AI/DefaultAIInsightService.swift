import Foundation

struct DefaultAIInsightService: AIInsightService {
    func generateInsight(for tasks: [TaskItem]) async -> AIInsight? {
        let remaining = tasks.filter { !$0.isCompleted }
        guard !remaining.isEmpty else { return nil }

        let remainingCount = remaining.count
        let taskWord = remainingCount == 1 ? "task" : "tasks"
        var message = "\(remainingCount) \(taskWord) remaining."

        let nextTask = remaining
            .filter { $0.dueTime != nil }
            .sorted { $0.dueTime! < $1.dueTime! }
            .first

        if let nextTask, let dueTime = nextTask.dueTime {
            message += " \(nextTask.title) at \(Self.timeFormatter.string(from: dueTime)) is your next priority."
        }

        return AIInsight(message: message)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
