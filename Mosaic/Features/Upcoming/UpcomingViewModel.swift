import Foundation

enum UpcomingItem: Identifiable {
    case task(TaskItem)
    case event(CalendarEvent)

    var id: AnyHashable {
        switch self {
        case .task(let task): task.id
        case .event(let event): event.id
        }
    }
}

struct UpcomingDaySection: Identifiable {
    let id: Date
    let date: Date
    let items: [UpcomingItem]
}

@Observable
@MainActor
final class UpcomingViewModel {
    private(set) var overdueTasks: [TaskItem] = []
    private(set) var daySections: [UpcomingDaySection] = []
    private(set) var errorMessage: String?

    private let taskRepository: TaskRepository
    private let locationReminderService: LocationReminderService
    private let calendarSyncService: CalendarSyncService
    private let userDefaults: UserDefaults

    private static let eventLookaheadDays = 90

    init(
        taskRepository: TaskRepository,
        locationReminderService: LocationReminderService,
        calendarSyncService: CalendarSyncService,
        userDefaults: UserDefaults = .standard
    ) {
        self.taskRepository = taskRepository
        self.locationReminderService = locationReminderService
        self.calendarSyncService = calendarSyncService
        self.userDefaults = userDefaults
    }

    func load() async {
        let allTasks: [TaskItem]
        do {
            allTasks = try taskRepository.fetchAll()
        } catch {
            errorMessage = "Couldn't load your upcoming tasks."
            return
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)

        let relevant = allTasks.filter { task in
            task.capturedAt == nil && task.dueDate != nil && !task.isCompleted
        }

        overdueTasks = relevant
            .filter { calendar.startOfDay(for: $0.dueDate!) < startOfToday }
            .sorted(by: Self.byDueDateThenTime)

        let upcomingTasks = relevant.filter { calendar.startOfDay(for: $0.dueDate!) >= startOfToday }

        let calendarSyncEnabled = (userDefaults.object(forKey: SettingsKeys.calendarSyncEnabled) as? Bool) ?? false
        var events: [CalendarEvent] = []
        if calendarSyncEnabled {
            let windowEnd = calendar.date(byAdding: .day, value: Self.eventLookaheadDays, to: startOfToday) ?? startOfToday
            events = await calendarSyncService.fetchEvents(from: startOfToday, to: windowEnd)
        }

        var itemsByDay: [Date: [UpcomingItem]] = [:]
        for task in upcomingTasks {
            let day = calendar.startOfDay(for: task.dueDate!)
            itemsByDay[day, default: []].append(.task(task))
        }
        for event in events {
            // Clamp instead of filter: EKEventStore's predicate matches events
            // that *overlap* the queried interval, not only ones that start
            // inside it, so a multi-day event that started before today can
            // still be returned with a past startDate. Such an in-progress
            // event should surface under today's section, not create a
            // stale section that sorts above today.
            let day = max(calendar.startOfDay(for: event.startDate), startOfToday)
            itemsByDay[day, default: []].append(.event(event))
        }

        daySections = itemsByDay.keys.sorted().map { day in
            UpcomingDaySection(id: day, date: day, items: itemsByDay[day]!.sorted(by: Self.byItemRank))
        }
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

        errorMessage = nil
        await load()
    }

    private enum ItemSortRank: Int, Comparable {
        case allDay = 0
        case timed = 1
        case untimed = 2

        static func < (lhs: ItemSortRank, rhs: ItemSortRank) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private static func rankKey(for item: UpcomingItem) -> (rank: ItemSortRank, time: Date?, title: String) {
        switch item {
        case .task(let task):
            if let time = task.dueTime { return (.timed, time, task.title) }
            return (.untimed, nil, task.title)
        case .event(let event):
            if event.isAllDay { return (.allDay, nil, event.title) }
            return (.timed, event.startDate, event.title)
        }
    }

    private static func byItemRank(_ a: UpcomingItem, _ b: UpcomingItem) -> Bool {
        let keyA = rankKey(for: a)
        let keyB = rankKey(for: b)
        if keyA.rank != keyB.rank { return keyA.rank < keyB.rank }
        if let timeA = keyA.time, let timeB = keyB.time, timeA != timeB { return timeA < timeB }
        return keyA.title < keyB.title
    }

    private static func byDueTime(_ a: TaskItem, _ b: TaskItem) -> Bool {
        switch (a.dueTime, b.dueTime) {
        case let (l?, r?): return l < r
        case (nil, nil): return a.title < b.title
        case (nil, _): return false
        case (_, nil): return true
        }
    }

    private static func byDueDateThenTime(_ a: TaskItem, _ b: TaskItem) -> Bool {
        guard let ad = a.dueDate, let bd = b.dueDate else { return false }
        if ad != bd { return ad < bd }
        return byDueTime(a, b)
    }
}
