import Foundation

@Observable
@MainActor
final class TaskCreationViewModel {
    var inputText: String = ""
    private(set) var draft: ParsedTaskDraft?
    private(set) var errorMessage: String?

    private let taskRepository: TaskRepository
    private let projectRepository: ProjectRepository
    private let tagRepository: TagRepository
    private let recurringTaskTemplateRepository: RecurringTaskTemplateRepository
    private let recurringTaskGenerationService: RecurringTaskGenerationService
    private let parsingService: NaturalLanguageParsingService
    private var parseTask: Task<Void, Never>?
    private var lastParsedText: String?

    init(
        taskRepository: TaskRepository,
        projectRepository: ProjectRepository,
        tagRepository: TagRepository,
        recurringTaskTemplateRepository: RecurringTaskTemplateRepository,
        recurringTaskGenerationService: RecurringTaskGenerationService,
        parsingService: NaturalLanguageParsingService
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.tagRepository = tagRepository
        self.recurringTaskTemplateRepository = recurringTaskTemplateRepository
        self.recurringTaskGenerationService = recurringTaskGenerationService
        self.parsingService = parsingService
    }

    var canCreate: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func scheduleParse() {
        parseTask?.cancel()
        parseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled, let self else { return }
            // Read `inputText` when the debounce FIRES, not when it was
            // scheduled. SwiftUI does not guarantee that `.onChange`'s action
            // runs for every mutation: under rapid successive keystrokes it
            // re-evaluates `body` with the new value but drops some `onChange`
            // invocations. Capturing the text at schedule time meant the final
            // keystrokes could have no `scheduleParse()` of their own, leaving
            // the last surviving timer to apply a permanently truncated parse
            // ("hot yoga 7-8pm mon wed f" for a fully typed "...mon wed fri").
            // Reading the current value here makes a dropped `onChange`
            // harmless: whichever timer survives parses whatever the user has
            // actually typed by the time the pause elapses.
            await self.applyParse(for: self.inputText)
        }
    }

    private func applyParse(for text: String) async {
        lastParsedText = text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            draft = nil
            return
        }

        var parsed = parsingService.parse(text)
        if let projectName = parsed.projectName {
            parsed.projectName = resolveProject(named: projectName)?.name
        }
        draft = parsed
    }

    private func resolveProject(named name: String) -> Project? {
        let projects = (try? projectRepository.fetchAll()) ?? []
        return projects.first {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    func clearDate() {
        draft?.date = nil
    }

    func clearTime() {
        draft?.timeComponents = nil
    }

    func clearProject() {
        draft?.projectName = nil
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
        // The debounced parse (scheduleParse) may not have settled yet for the
        // current inputText — either because it was never triggered, or because
        // the user edited the text and hit "create" before the 420ms debounce
        // fired. In either case `draft` would reflect stale (or no) input.
        // Re-parse synchronously whenever inputText has diverged from whatever
        // was last actually parsed, so `draft` is guaranteed fresh at creation
        // time. When inputText matches what was last parsed, skip re-parsing so
        // any manual clearDate()/clearTime()/clearProject()/clearTag()/
        // clearReminder() edits the user made to `draft` are preserved.
        if inputText != lastParsedText {
            await applyParse(for: inputText)
        }

        if let weekdays = draft?.recurringWeekdays, weekdays.count >= 2 {
            return createRecurringTask(weekdays: weekdays)
        }

        return createSingleTask()
    }

    private func createRecurringTask(weekdays: Set<Int>) -> Bool {
        // No fallback: if the user typed no time at all, the template carries no
        // start time and its occurrences land in "Anytime", mirroring the one-off
        // path. Guessing 9:00 AM would invent data the user never supplied.
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
        let dueDate = draft?.date ?? calendar.startOfDay(for: .now)
        let dueTime = draft?.timeComponents.flatMap {
            calendar.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: dueDate)
        }

        let matchedProject = draft?.projectName.flatMap { resolveProject(named: $0) }

        let task = TaskItem(
            title: draft?.cleanedTitle ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            dueTime: dueTime,
            timeOfDay: Self.timeOfDay(forHour: draft?.timeComponents?.hour),
            hasReminder: draft?.hasReminder ?? false,
            project: matchedProject
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

        errorMessage = nil
        return true
    }

    private static func timeOfDay(forHour hour: Int?) -> TimeOfDay {
        guard let hour else { return .anytime }
        return hour < 12 ? .morning : .afternoon
    }
}
