import Foundation

@Observable
@MainActor
final class TaskCreationViewModel {
    var inputText: String = ""
    private(set) var draft: ParsedTaskDraft?
    private(set) var errorMessage: String?

    private let taskRepository: TaskRepository
    private let tagRepository: TagRepository
    private let recurringTaskTemplateRepository: RecurringTaskTemplateRepository
    private let recurringTaskGenerationService: RecurringTaskGenerationService
    private let parsingService: NaturalLanguageParsingService
    private let notificationService: NotificationService
    // When true, a one-off task created with no explicit date parsed from
    // `inputText` becomes an Inbox capture (`capturedAt` set, no due date)
    // instead of defaulting to today — matching what tapping "+" while
    // looking at Inbox implies. An explicit date in the input (e.g. "buy
    // milk tomorrow") always wins over this default.
    private let capturesToInbox: Bool
    private var parseTask: Task<Void, Never>?
    private var lastParsedText: String?

    init(
        taskRepository: TaskRepository,
        tagRepository: TagRepository,
        recurringTaskTemplateRepository: RecurringTaskTemplateRepository,
        recurringTaskGenerationService: RecurringTaskGenerationService,
        parsingService: NaturalLanguageParsingService,
        notificationService: NotificationService,
        capturesToInbox: Bool = false
    ) {
        self.taskRepository = taskRepository
        self.tagRepository = tagRepository
        self.recurringTaskTemplateRepository = recurringTaskTemplateRepository
        self.recurringTaskGenerationService = recurringTaskGenerationService
        self.parsingService = parsingService
        self.notificationService = notificationService
        self.capturesToInbox = capturesToInbox
    }

    var canCreate: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func scheduleParse() {
        parseTask?.cancel()
        parseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled, let self else { return }
            await self.applyParse(for: self.inputText)
        }
    }

    private func applyParse(for text: String) async {
        lastParsedText = text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            draft = nil
            return
        }

        draft = parsingService.parse(text)
    }

    func clearDate() {
        draft?.date = nil
    }

    func clearTime() {
        draft?.timeComponents = nil
    }

    func clearTag() {
        draft?.tagName = nil
    }

    func clearReminder() {
        draft?.hasReminder = false
    }

    func clearRecurringWeekdays() {
        draft?.recurringWeekdays = nil
    }

    func clearTimeRange() {
        draft?.timeRangeComponents = nil
    }

    func clearError() {
        errorMessage = nil
    }

    @discardableResult
    func createTask() async -> Bool {
        guard canCreate else { return false }

        parseTask?.cancel()
        if inputText != lastParsedText {
            await applyParse(for: inputText)
        }

        if let weekdays = draft?.recurringWeekdays, weekdays.count >= 2 {
            return createRecurringTask(weekdays: weekdays)
        }

        return createSingleTask()
    }

    private func createRecurringTask(weekdays: Set<Int>) -> Bool {
        let startHour = draft?.timeRangeComponents?.start.hour ?? draft?.timeComponents?.hour
        let startMinute = draft?.timeRangeComponents?.start.minute ?? draft?.timeComponents?.minute
        let endHour = draft?.timeRangeComponents?.end.hour
        let endMinute = draft?.timeRangeComponents?.end.minute

        let template = RecurringTaskTemplate(
            title: draft?.cleanedTitle ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines),
            weekdays: Array(weekdays),
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute
        )

        do {
            try recurringTaskTemplateRepository.create(template)
            try recurringTaskGenerationService.generateInitialOccurrences(for: template)
        } catch {
            errorMessage = "Couldn't create that recurring task."
            return false
        }

        errorMessage = nil
        return true
    }

    private func createSingleTask() -> Bool {
        let calendar = Calendar.current
        let isInboxCapture = capturesToInbox && draft?.date == nil
        let dueDate = isInboxCapture ? nil : (draft?.date ?? calendar.startOfDay(for: .now))
        let dueTime = dueDate.flatMap { date in
            draft?.timeComponents.flatMap {
                calendar.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: date)
            }
        }

        let task = TaskItem(
            title: draft?.cleanedTitle ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines),
            capturedAt: isInboxCapture ? .now : nil,
            dueDate: dueDate,
            dueTime: dueTime,
            timeOfDay: dueDate == nil ? nil : Self.timeOfDay(forHour: draft?.timeComponents?.hour),
            hasReminder: draft?.hasReminder ?? false,
            origin: isInboxCapture ? .quickCapture : .manual
        )

        if let tagName = draft?.tagName, let tag = try? tagRepository.findOrCreate(name: tagName) {
            task.tags = [tag]
        }

        do {
            try taskRepository.create(task)
        } catch {
            errorMessage = "Couldn't create that task."
            return false
        }

        let reminder = TaskReminderInfo(task: task)
        Task { await notificationService.scheduleReminder(for: reminder) }

        errorMessage = nil
        return true
    }

    private static func timeOfDay(forHour hour: Int?) -> TimeOfDay {
        guard let hour else { return .anytime }
        return hour < 12 ? .morning : .afternoon
    }
}
