import Foundation

@Observable
@MainActor
final class TodayViewModel {
    private(set) var morningTasks: [TaskItem] = []
    private(set) var afternoonTasks: [TaskItem] = []
    private(set) var anytimeTasks: [TaskItem] = []
    private(set) var completedTasks: [TaskItem] = []
    private(set) var insight: AIInsight?
    private(set) var isCompletedSectionExpanded = false
    private(set) var errorMessage: String?

    private let taskRepository: TaskRepository
    private let aiInsightService: AIInsightService
    private let recurringTaskTemplateRepository: RecurringTaskTemplateRepository
    private let recurringTaskGenerationService: RecurringTaskGenerationService
    private let locationReminderService: LocationReminderService

    init(
        taskRepository: TaskRepository,
        aiInsightService: AIInsightService,
        recurringTaskTemplateRepository: RecurringTaskTemplateRepository,
        recurringTaskGenerationService: RecurringTaskGenerationService,
        locationReminderService: LocationReminderService
    ) {
        self.taskRepository = taskRepository
        self.aiInsightService = aiInsightService
        self.recurringTaskTemplateRepository = recurringTaskTemplateRepository
        self.recurringTaskGenerationService = recurringTaskGenerationService
        self.locationReminderService = locationReminderService
    }

    var totalCount: Int {
        morningTasks.count + afternoonTasks.count + anytimeTasks.count + completedTasks.count
    }

    func load() async {
        // Best-effort: a top-up failure shouldn't block the rest of Today from
        // loading already-existing tasks.
        if let activeTemplates = try? recurringTaskTemplateRepository.fetchAllActive() {
            try? recurringTaskGenerationService.topUpIfNeeded(activeTemplates)
        }

        let allTasks: [TaskItem]
        do {
            allTasks = try taskRepository.fetchAll()
        } catch {
            errorMessage = "Couldn't load your tasks."
            return
        }

        let todayTasks = allTasks.filter { task in
            guard task.capturedAt == nil, let dueDate = task.dueDate else { return false }
            return Calendar.current.isDateInToday(dueDate)
        }

        let incomplete = todayTasks.filter { !$0.isCompleted }
        completedTasks = todayTasks.filter { $0.isCompleted }

        morningTasks = incomplete.filter { ($0.timeOfDay ?? .anytime) == .morning }.sorted(by: Self.byDueTime)
        afternoonTasks = incomplete.filter { ($0.timeOfDay ?? .anytime) == .afternoon }.sorted(by: Self.byDueTime)
        anytimeTasks = incomplete.filter { ($0.timeOfDay ?? .anytime) == .anytime }.sorted(by: Self.byDueTime)

        insight = await aiInsightService.generateInsight(for: incomplete)
        errorMessage = nil
    }

    func toggleCompletion(_ task: TaskItem) async {
        let wasCompleted = task.isCompleted
        do {
            try taskRepository.toggleCompletion(task)
        } catch {
            errorMessage = "Couldn't update that task."
            return
        }

        if let reminderID = task.locationReminder?.id {
            if !wasCompleted && task.isCompleted {
                await locationReminderService.stopMonitoring(id: reminderID)
            } else if wasCompleted && !task.isCompleted, let reminderInfo = LocationReminderInfo(task: task) {
                await locationReminderService.startMonitoring(for: reminderInfo)
            }
        }

        await load()
    }

    func stopRepeating(_ task: TaskItem) async {
        guard let template = task.recurringTemplate else { return }
        do {
            try recurringTaskTemplateRepository.deactivate(template)
        } catch {
            errorMessage = "Couldn't stop that recurring task."
            return
        }
        await load()
    }

    func toggleCompletedSectionExpanded() {
        isCompletedSectionExpanded.toggle()
    }

    private static func byDueTime(_ a: TaskItem, _ b: TaskItem) -> Bool {
        switch (a.dueTime, b.dueTime) {
        case let (lhs?, rhs?): return lhs < rhs
        case (nil, _?): return false
        case (_?, nil): return true
        case (nil, nil): return false
        }
    }
}
