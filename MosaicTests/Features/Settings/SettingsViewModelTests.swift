import Testing
import Foundation
@testable import Mosaic

@MainActor
struct SettingsViewModelTests {
    private func makeIsolatedDefaults() -> (defaults: UserDefaults, cleanup: () -> Void) {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, { defaults.removePersistentDomain(forName: suiteName) })
    }

    @Test func defaultValuesOnFirstLaunch() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let viewModel = SettingsViewModel(userDefaults: defaults, notificationService: RecordingNotificationService(authorizationGranted: true), taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))

        #expect(viewModel.theme == .system)
        #expect(viewModel.notificationsEnabled == false)
        #expect(viewModel.aiInsightsEnabled == true)
        #expect(viewModel.defaultRemindersEnabled == false)
    }

    @Test func settingThemePersistsAndIsPickedUpByAFreshViewModel() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let viewModel = SettingsViewModel(userDefaults: defaults, notificationService: RecordingNotificationService(authorizationGranted: true), taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))

        viewModel.theme = .dark

        let reloaded = SettingsViewModel(userDefaults: defaults, notificationService: RecordingNotificationService(authorizationGranted: true), taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))
        #expect(reloaded.theme == .dark)
        #expect(defaults.string(forKey: SettingsKeys.theme) == "dark")
    }

    @Test func settingNotificationsEnabledPersists() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let viewModel = SettingsViewModel(userDefaults: defaults, notificationService: RecordingNotificationService(authorizationGranted: true), taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))

        viewModel.notificationsEnabled = true

        let reloaded = SettingsViewModel(userDefaults: defaults, notificationService: RecordingNotificationService(authorizationGranted: true), taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))
        #expect(reloaded.notificationsEnabled == true)
    }

    @Test func settingAIInsightsEnabledPersists() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let viewModel = SettingsViewModel(userDefaults: defaults, notificationService: RecordingNotificationService(authorizationGranted: true), taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))

        viewModel.aiInsightsEnabled = false

        let reloaded = SettingsViewModel(userDefaults: defaults, notificationService: RecordingNotificationService(authorizationGranted: true), taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))
        #expect(reloaded.aiInsightsEnabled == false)
    }

    @Test func settingDefaultRemindersEnabledPersists() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let viewModel = SettingsViewModel(userDefaults: defaults, notificationService: RecordingNotificationService(authorizationGranted: true), taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))

        viewModel.defaultRemindersEnabled = true

        let reloaded = SettingsViewModel(userDefaults: defaults, notificationService: RecordingNotificationService(authorizationGranted: true), taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))
        #expect(reloaded.defaultRemindersEnabled == true)
    }

    @Test func appVersionAndBuildNumberReflectInjectedBundle() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let viewModel = SettingsViewModel(userDefaults: defaults, bundle: .main, notificationService: RecordingNotificationService(authorizationGranted: true), taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))

        let expectedVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let expectedBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        #expect(viewModel.appVersion == expectedVersion)
        #expect(viewModel.buildNumber == expectedBuild)
    }

    @Test func handleNotificationsToggleChangedRequestsAuthorizationWhenTurnedOn() async {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let notificationService = RecordingNotificationService(authorizationGranted: true)
        let viewModel = SettingsViewModel(userDefaults: defaults, notificationService: notificationService, taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))

        viewModel.notificationsEnabled = true
        await viewModel.handleNotificationsToggleChanged()

        #expect(notificationService.authorizationRequested)
        #expect(viewModel.notificationsEnabled)
    }

    @Test func handleNotificationsToggleChangedRevertsToggleWhenPermissionDenied() async {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let notificationService = RecordingNotificationService(authorizationGranted: false)
        let viewModel = SettingsViewModel(userDefaults: defaults, notificationService: notificationService, taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))

        viewModel.notificationsEnabled = true
        await viewModel.handleNotificationsToggleChanged()

        #expect(!viewModel.notificationsEnabled)
    }

    @Test func handleNotificationsToggleChangedCancelsAllWhenTurnedOff() async {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let notificationService = RecordingNotificationService(authorizationGranted: true)
        let viewModel = SettingsViewModel(userDefaults: defaults, notificationService: notificationService, taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))

        viewModel.notificationsEnabled = false
        await viewModel.handleNotificationsToggleChanged()

        #expect(notificationService.cancelAllCalled)
        #expect(!notificationService.authorizationRequested)
    }

    @Test func handleCalendarSyncToggleChangedRequestsAuthorizationWhenTurnedOn() async {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let calendarSyncService = RecordingCalendarSyncService(authorizationGranted: true)
        let viewModel = SettingsViewModel(userDefaults: defaults, notificationService: RecordingNotificationService(authorizationGranted: true), taskRepository: StubTaskRepository(), calendarSyncService: calendarSyncService)

        viewModel.calendarSyncEnabled = true
        await viewModel.handleCalendarSyncToggleChanged()

        #expect(calendarSyncService.authorizationRequested)
        #expect(viewModel.calendarSyncEnabled)
    }

    @Test func handleCalendarSyncToggleChangedRevertsToggleWhenPermissionDenied() async {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let calendarSyncService = RecordingCalendarSyncService(authorizationGranted: false)
        let viewModel = SettingsViewModel(userDefaults: defaults, notificationService: RecordingNotificationService(authorizationGranted: true), taskRepository: StubTaskRepository(), calendarSyncService: calendarSyncService)

        viewModel.calendarSyncEnabled = true
        await viewModel.handleCalendarSyncToggleChanged()

        #expect(!viewModel.calendarSyncEnabled)
    }

    @Test func handleCalendarSyncToggleChangedDoesNotRequestAuthorizationWhenTurnedOff() async {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let calendarSyncService = RecordingCalendarSyncService(authorizationGranted: true)
        let viewModel = SettingsViewModel(userDefaults: defaults, notificationService: RecordingNotificationService(authorizationGranted: true), taskRepository: StubTaskRepository(), calendarSyncService: calendarSyncService)

        viewModel.calendarSyncEnabled = false
        await viewModel.handleCalendarSyncToggleChanged()

        #expect(!calendarSyncService.authorizationRequested)
    }

    @Test func handleNotificationsToggleChangedReschedulesExistingRemindersWhenTurnedOn() async throws {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let notificationService = RecordingNotificationService(authorizationGranted: true)
        let taskWithReminder = TaskItem(title: "Water plants", dueDate: .now, dueTime: .now, hasReminder: true)
        let taskWithoutReminder = TaskItem(title: "No reminder", hasReminder: false)
        let taskRepository = StubTaskRepository(tasks: [taskWithReminder, taskWithoutReminder])
        let viewModel = SettingsViewModel(userDefaults: defaults, notificationService: notificationService, taskRepository: taskRepository, calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))

        viewModel.notificationsEnabled = true
        await viewModel.handleNotificationsToggleChanged()

        #expect(notificationService.scheduledTaskIDs == [taskWithReminder.id, taskWithoutReminder.id])
    }

    @Test func handleNotificationsToggleChangedIsANoOpWhenCalledAgainWithoutAChange() async {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let notificationService = RecordingNotificationService(authorizationGranted: false)
        let viewModel = SettingsViewModel(userDefaults: defaults, notificationService: notificationService, taskRepository: StubTaskRepository(), calendarSyncService: RecordingCalendarSyncService(authorizationGranted: true))

        viewModel.notificationsEnabled = true
        await viewModel.handleNotificationsToggleChanged()
        #expect(notificationService.cancelAllCalled == false)

        // Simulates SettingsView's .onChange re-firing because the revert
        // above (notificationsEnabled = false) is itself an observed
        // mutation. Without the re-entrancy guard this second call would
        // spuriously wipe every pending reminder.
        await viewModel.handleNotificationsToggleChanged()
        #expect(notificationService.cancelAllCalled == false)
    }
}

private final class RecordingNotificationService: NotificationService {
    private let authorizationGranted: Bool
    private(set) var authorizationRequested = false
    private(set) var cancelAllCalled = false
    private(set) var scheduledTaskIDs: [UUID] = []

    init(authorizationGranted: Bool) {
        self.authorizationGranted = authorizationGranted
    }

    func requestAuthorization() async -> Bool {
        authorizationRequested = true
        return authorizationGranted
    }

    func scheduleReminder(for reminder: TaskReminderInfo) async {
        scheduledTaskIDs.append(reminder.id)
    }

    func cancelReminder(id: UUID) async {}

    func cancelAllReminders() async {
        cancelAllCalled = true
    }

    func postLocationAlert(identifier: String, title: String, body: String) async {}
}

private final class RecordingCalendarSyncService: CalendarSyncService {
    private let authorizationGranted: Bool
    private(set) var authorizationRequested = false

    init(authorizationGranted: Bool) {
        self.authorizationGranted = authorizationGranted
    }

    func requestAuthorization() async -> Bool {
        authorizationRequested = true
        return authorizationGranted
    }

    func fetchEvents(from startDate: Date, to endDate: Date) async -> [CalendarEvent] { [] }
    func fetchAvailableCalendars() async -> [CalendarInfo] { [] }
}

private final class StubTaskRepository: TaskRepository {
    private let tasks: [TaskItem]

    init(tasks: [TaskItem] = []) {
        self.tasks = tasks
    }

    func fetchAll() throws -> [TaskItem] { tasks }
    func fetchInbox() throws -> [TaskItem] { [] }
    func create(_ task: TaskItem) throws {}
    func createMany(_ tasks: [TaskItem]) throws {}
    func update(_ task: TaskItem) throws {}
    func delete(_ task: TaskItem) throws {}
    func toggleCompletion(_ task: TaskItem) throws {}
    func search(query: String) throws -> [TaskItem] { [] }
    func addSubtask(_ subtask: Subtask, to task: TaskItem) throws {}
    func toggleSubtaskCompletion(_ subtask: Subtask) throws {}
    func deleteSubtask(_ subtask: Subtask) throws {}
    func addAttachment(_ attachment: TaskAttachment, to task: TaskItem) throws {}
    func deleteAttachment(_ attachment: TaskAttachment) throws {}
}
