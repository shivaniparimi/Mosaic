@MainActor
protocol AIInsightService {
    func generateInsight(for tasks: [TaskItem]) async -> AIInsight?
}

struct AIInsight: Equatable {
    let message: String
}
