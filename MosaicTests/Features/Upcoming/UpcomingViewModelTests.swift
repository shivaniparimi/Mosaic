import Testing
import SwiftData
import Foundation
@testable import Mosaic

@MainActor
struct UpcomingViewModelTests {
    private func makeViewModel(
        context: ModelContext,
        locationReminderService: LocationReminderService = RecordingLocationReminderService(),
        calendarSyncService: CalendarSyncService = StubCalendarSyncService(),
        userDefaults: UserDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    ) -> UpcomingViewModel {
        UpcomingViewModel(
            taskRepository: SwiftDataTaskRepository(context: context),
            locationReminderService: locationReminderService,
            calendarSyncService: calendarSyncService,
            userDefaults: userDefaults
        )
    }

    private func titles(_ items: [UpcomingItem]) -> [String] {
        items.map { item in
            switch item {
            case .task(let task): task.title
            case .event(let event): event.title
            }
        }
    }

    @Test func loadPutsPastDueIncompleteTasksInOverdueNotDaySections() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))!

        try repository.create(TaskItem(title: "Overdue task", dueDate: yesterday))

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.load()

        #expect(viewModel.overdueTasks.map(\.title) == ["Overdue task"])
        #expect(viewModel.daySections.isEmpty)
    }

    @Test func loadGroupsTasksDueTodayOrLaterIntoDaySections() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        try repository.create(TaskItem(title: "Today task", dueDate: today))
        try repository.create(TaskItem(title: "Tomorrow task", dueDate: tomorrow))

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.load()

        #expect(viewModel.overdueTasks.isEmpty)
        #expect(viewModel.daySections.count == 2)
        #expect(titles(viewModel.daySections[0].items) == ["Today task"])
        #expect(titles(viewModel.daySections[1].items) == ["Tomorrow task"])
    }

    @Test func loadProducesNoSectionForDaysWithNoTasks() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let inFiveDays = calendar.date(byAdding: .day, value: 5, to: today)!

        try repository.create(TaskItem(title: "Today task", dueDate: today))
        try repository.create(TaskItem(title: "Five days out", dueDate: inFiveDays))

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.load()

        #expect(viewModel.daySections.count == 2, "only the two days with actual tasks should produce sections")
    }

    @Test func loadSortsTasksWithinADayByDueTimeAscending() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let laterTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!
        let earlierTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!

        try repository.create(TaskItem(title: "Later", dueDate: today, dueTime: laterTime))
        try repository.create(TaskItem(title: "Earlier", dueDate: today, dueTime: earlierTime))

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.load()

        #expect(titles(viewModel.daySections.first?.items ?? []) == ["Earlier", "Later"])
    }

    @Test func loadExcludesCapturedInboxTasks() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let today = Calendar.current.startOfDay(for: .now)

        try repository.create(TaskItem(title: "Inbox item", capturedAt: .now, dueDate: today))

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.load()

        #expect(viewModel.overdueTasks.isEmpty)
        #expect(viewModel.daySections.isEmpty)
    }

    @Test func loadExcludesCompletedTasks() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))!
        let today = calendar.startOfDay(for: .now)

        try repository.create(TaskItem(title: "Completed overdue", isCompleted: true, dueDate: yesterday))
        try repository.create(TaskItem(title: "Completed today", isCompleted: true, dueDate: today))

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.load()

        #expect(viewModel.overdueTasks.isEmpty)
        #expect(viewModel.daySections.isEmpty)
    }

    @Test func loadExcludesTasksWithNoDueDate() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)

        try repository.create(TaskItem(title: "No due date"))

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.load()

        #expect(viewModel.overdueTasks.isEmpty)
        #expect(viewModel.daySections.isEmpty)
    }

    @Test func toggleCompletionRemovesTaskFromView() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let today = Calendar.current.startOfDay(for: .now)
        let task = TaskItem(title: "Finish plan", dueDate: today)
        try repository.create(task)

        let viewModel = makeViewModel(context: container.mainContext)
        await viewModel.load()
        #expect(viewModel.daySections.count == 1)

        await viewModel.toggleCompletion(task)

        #expect(viewModel.daySections.isEmpty)
    }

    @Test func toggleCompletionStopsLocationMonitoringWhenCompletingATaskWithALocationReminder() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let reminder = LocationReminder(name: "Home", address: "123 Main St", latitude: 37.0, longitude: -122.0, trigger: .arriving)
        let today = Calendar.current.startOfDay(for: .now)
        let task = TaskItem(title: "Water plants", dueDate: today)
        task.locationReminder = reminder
        try repository.create(task)

        let locationService = RecordingLocationReminderService()
        let viewModel = makeViewModel(context: container.mainContext, locationReminderService: locationService)
        await viewModel.load()

        await viewModel.toggleCompletion(task)

        #expect(locationService.stoppedReminderIDs == [reminder.id])
    }

    @Test func loadExcludesCalendarEventsWhenSyncDisabled() async throws {
        let container = TestModelContainer.makeInMemory()
        let today = Calendar.current.startOfDay(for: .now)
        let event = CalendarEvent(id: "e1", title: "Standup", startDate: today, endDate: today, isAllDay: false, location: nil)
        let calendarSyncService = StubCalendarSyncService(events: [event])
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!

        let viewModel = makeViewModel(context: container.mainContext, calendarSyncService: calendarSyncService, userDefaults: userDefaults)
        await viewModel.load()

        #expect(viewModel.daySections.isEmpty)
        #expect(calendarSyncService.fetchCallCount == 0)
    }

    @Test func loadIncludesCalendarEventsWhenSyncEnabled() async throws {
        let container = TestModelContainer.makeInMemory()
        let today = Calendar.current.startOfDay(for: .now)
        let event = CalendarEvent(id: "e1", title: "Standup", startDate: today, endDate: today, isAllDay: false, location: nil)
        let calendarSyncService = StubCalendarSyncService(events: [event])
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        userDefaults.set(true, forKey: SettingsKeys.calendarSyncEnabled)

        let viewModel = makeViewModel(context: container.mainContext, calendarSyncService: calendarSyncService, userDefaults: userDefaults)
        await viewModel.load()

        #expect(viewModel.daySections.count == 1)
        #expect(titles(viewModel.daySections[0].items) == ["Standup"])
        #expect(calendarSyncService.fetchCallCount == 1)
    }

    @Test func loadFetchesEventsForA90DayWindowFromToday() async throws {
        let container = TestModelContainer.makeInMemory()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let calendarSyncService = StubCalendarSyncService()
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        userDefaults.set(true, forKey: SettingsKeys.calendarSyncEnabled)

        let viewModel = makeViewModel(context: container.mainContext, calendarSyncService: calendarSyncService, userDefaults: userDefaults)
        await viewModel.load()

        let expectedEnd = calendar.date(byAdding: .day, value: 90, to: today)!
        #expect(calendarSyncService.lastFetchRange?.start == today)
        #expect(calendarSyncService.lastFetchRange?.end == expectedEnd)
    }

    @Test func loadClampsOverlappingMultiDayEventsToTodayNotAPastSection() async throws {
        let container = TestModelContainer.makeInMemory()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // EKEventStore's predicate matches events that *overlap* the queried
        // range, not only ones that start inside it, so a multi-day event
        // that began yesterday can still be returned today with a past
        // startDate.
        let multiDayEvent = CalendarEvent(id: "e1", title: "Conference", startDate: yesterday, endDate: today, isAllDay: false, location: nil)
        let calendarSyncService = StubCalendarSyncService(events: [multiDayEvent])
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        userDefaults.set(true, forKey: SettingsKeys.calendarSyncEnabled)

        let viewModel = makeViewModel(context: container.mainContext, calendarSyncService: calendarSyncService, userDefaults: userDefaults)
        await viewModel.load()

        #expect(viewModel.daySections.count == 1)
        #expect(viewModel.daySections[0].date == today)
        #expect(titles(viewModel.daySections[0].items) == ["Conference"])
    }

    @Test func loadSortsAllDayEventsBeforeTimedItemsWithinADay() async throws {
        let container = TestModelContainer.makeInMemory()
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let morningTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!

        try repository.create(TaskItem(title: "Timed task", dueDate: today, dueTime: morningTime))
        try repository.create(TaskItem(title: "Untimed task", dueDate: today))

        let timedEvent = CalendarEvent(id: "e1", title: "Timed event", startDate: morningTime, endDate: morningTime, isAllDay: false, location: nil)
        let allDayEvent = CalendarEvent(id: "e2", title: "All-day event", startDate: today, endDate: today, isAllDay: true, location: nil)
        let calendarSyncService = StubCalendarSyncService(events: [timedEvent, allDayEvent])
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        userDefaults.set(true, forKey: SettingsKeys.calendarSyncEnabled)

        let viewModel = makeViewModel(context: container.mainContext, calendarSyncService: calendarSyncService, userDefaults: userDefaults)
        await viewModel.load()

        #expect(titles(viewModel.daySections[0].items) == ["All-day event", "Timed event", "Timed task", "Untimed task"])
    }
}

private final class RecordingLocationReminderService: LocationReminderService {
    private(set) var startedReminderIDs: [UUID] = []
    private(set) var stoppedReminderIDs: [UUID] = []

    func requestAuthorization() async -> Bool { true }

    func startMonitoring(for reminder: LocationReminderInfo) async {
        startedReminderIDs.append(reminder.reminderID)
    }

    func stopMonitoring(id: UUID) async {
        stoppedReminderIDs.append(id)
    }

    func reregisterAll(reminders: [LocationReminderInfo]) async {
        for reminder in reminders { startedReminderIDs.append(reminder.reminderID) }
    }
}

private final class StubCalendarSyncService: CalendarSyncService {
    private let events: [CalendarEvent]
    private(set) var fetchCallCount = 0
    private(set) var lastFetchRange: (start: Date, end: Date)?

    init(events: [CalendarEvent] = []) {
        self.events = events
    }

    func requestAuthorization() async -> Bool { true }

    func fetchEvents(from startDate: Date, to endDate: Date) async -> [CalendarEvent] {
        fetchCallCount += 1
        lastFetchRange = (startDate, endDate)
        return events
    }

    func fetchAvailableCalendars() async -> [CalendarInfo] { [] }
}
