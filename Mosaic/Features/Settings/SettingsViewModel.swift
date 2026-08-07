import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    var theme: AppTheme {
        didSet { userDefaults.set(theme.rawValue, forKey: SettingsKeys.theme) }
    }
    var notificationsEnabled: Bool {
        didSet { userDefaults.set(notificationsEnabled, forKey: SettingsKeys.notificationsEnabled) }
    }
    var aiInsightsEnabled: Bool {
        didSet { userDefaults.set(aiInsightsEnabled, forKey: SettingsKeys.aiInsightsEnabled) }
    }
    var calendarSyncEnabled: Bool {
        didSet { userDefaults.set(calendarSyncEnabled, forKey: SettingsKeys.calendarSyncEnabled) }
    }
    var reminderSyncEnabled: Bool {
        didSet { userDefaults.set(reminderSyncEnabled, forKey: SettingsKeys.reminderSyncEnabled) }
    }

    let appVersion: String
    let buildNumber: String

    private let userDefaults: UserDefaults
    private let notificationService: NotificationService
    private let taskRepository: TaskRepository
    private let calendarSyncService: CalendarSyncService
    private let reminderSyncService: ReminderSyncService
    // Tracks the last `notificationsEnabled` value this method has actually
    // acted on. `handleNotificationsToggleChanged()` reverting the toggle on
    // denial mutates `notificationsEnabled` itself, which re-triggers
    // SettingsView's `.onChange` and schedules a second, redundant call. This
    // guard makes that second call a no-op instead of spuriously firing
    // `cancelAllReminders()` — the value is updated synchronously alongside
    // the revert, before any suspension point, so there's no race window.
    private var lastHandledNotificationsEnabled: Bool?
    private var lastHandledCalendarSyncEnabled: Bool?
    // Same re-entrancy guard as lastHandledCalendarSyncEnabled, for the
    // Reminders sync toggle.
    private var lastHandledReminderSyncEnabled: Bool?

    init(
        userDefaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        notificationService: NotificationService,
        taskRepository: TaskRepository,
        calendarSyncService: CalendarSyncService,
        reminderSyncService: ReminderSyncService
    ) {
        self.userDefaults = userDefaults
        self.theme = AppTheme(rawValue: userDefaults.string(forKey: SettingsKeys.theme) ?? "") ?? .light
        self.notificationsEnabled = (userDefaults.object(forKey: SettingsKeys.notificationsEnabled) as? Bool) ?? false
        self.aiInsightsEnabled = (userDefaults.object(forKey: SettingsKeys.aiInsightsEnabled) as? Bool) ?? true
        self.calendarSyncEnabled = (userDefaults.object(forKey: SettingsKeys.calendarSyncEnabled) as? Bool) ?? false
        self.reminderSyncEnabled = (userDefaults.object(forKey: SettingsKeys.reminderSyncEnabled) as? Bool) ?? false
        self.appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.buildNumber = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        self.notificationService = notificationService
        self.taskRepository = taskRepository
        self.calendarSyncService = calendarSyncService
        self.reminderSyncService = reminderSyncService
    }

    func handleNotificationsToggleChanged() async {
        let currentValue = notificationsEnabled
        guard lastHandledNotificationsEnabled != currentValue else { return }

        guard currentValue else {
            lastHandledNotificationsEnabled = false
            await notificationService.cancelAllReminders()
            return
        }

        let granted = await notificationService.requestAuthorization()
        guard granted else {
            notificationsEnabled = false
            lastHandledNotificationsEnabled = false
            return
        }

        lastHandledNotificationsEnabled = true
        await rescheduleAllReminders()
    }

    func handleCalendarSyncToggleChanged() async {
        let currentValue = calendarSyncEnabled
        guard lastHandledCalendarSyncEnabled != currentValue else { return }

        guard currentValue else {
            lastHandledCalendarSyncEnabled = false
            return
        }

        let granted = await calendarSyncService.requestAuthorization()
        guard granted else {
            calendarSyncEnabled = false
            lastHandledCalendarSyncEnabled = false
            return
        }

        lastHandledCalendarSyncEnabled = true
    }

    func handleReminderSyncToggleChanged() async {
        let currentValue = reminderSyncEnabled
        guard lastHandledReminderSyncEnabled != currentValue else { return }

        guard currentValue else {
            lastHandledReminderSyncEnabled = false
            return
        }

        let granted = await reminderSyncService.requestAuthorization()
        guard granted else {
            reminderSyncEnabled = false
            lastHandledReminderSyncEnabled = false
            return
        }

        lastHandledReminderSyncEnabled = true
    }

    // Every existing task's reminder was cancelled the last time this toggle
    // went off (handleNotificationsToggleChanged's cancelAllReminders call).
    // Turning it back on has to re-establish them, or a user who ever
    // toggles it off then on again silently loses every reminder for good.
    // scheduleReminder(for:) already re-derives whether each task is
    // actually eligible, so this can call it unconditionally per task rather
    // than duplicating that gate here.
    private func rescheduleAllReminders() async {
        guard let tasks = try? taskRepository.fetchAll() else { return }
        for task in tasks {
            let reminder = TaskReminderInfo(task: task)
            await notificationService.scheduleReminder(for: reminder)
        }
    }
}
