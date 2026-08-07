import SwiftData

@MainActor
final class AppDependencyContainer {
    let modelContainer: ModelContainer
    let taskRepository: TaskRepository
    let tagRepository: TagRepository
    let recurringTaskTemplateRepository: RecurringTaskTemplateRepository
    let aiInsightService: AIInsightService
    let naturalLanguageParsingService: NaturalLanguageParsingService
    let recurringTaskGenerationService: RecurringTaskGenerationService
    let notificationService: NotificationService
    let locationReminderService: LocationReminderService
    let attachmentStorageService: AttachmentStorageService
    let calendarSyncService: CalendarSyncService

    init(
        modelContainer: ModelContainer,
        taskRepository: TaskRepository,
        tagRepository: TagRepository,
        recurringTaskTemplateRepository: RecurringTaskTemplateRepository,
        aiInsightService: AIInsightService,
        naturalLanguageParsingService: NaturalLanguageParsingService,
        recurringTaskGenerationService: RecurringTaskGenerationService,
        notificationService: NotificationService,
        locationReminderService: LocationReminderService,
        attachmentStorageService: AttachmentStorageService,
        calendarSyncService: CalendarSyncService
    ) {
        self.modelContainer = modelContainer
        self.taskRepository = taskRepository
        self.tagRepository = tagRepository
        self.recurringTaskTemplateRepository = recurringTaskTemplateRepository
        self.aiInsightService = aiInsightService
        self.naturalLanguageParsingService = naturalLanguageParsingService
        self.recurringTaskGenerationService = recurringTaskGenerationService
        self.notificationService = notificationService
        self.locationReminderService = locationReminderService
        self.attachmentStorageService = attachmentStorageService
        self.calendarSyncService = calendarSyncService
    }

    static func live() -> AppDependencyContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, migrationPlan: MosaicMigrationPlan.self)
        } catch {
            fatalError("Failed to open Mosaic store: \(error)")
        }
        let context = container.mainContext
        let taskRepository = SwiftDataTaskRepository(context: context)
        let notificationService = UserNotificationService()
        let attachmentStorageService = FileManagerAttachmentStorageService()
        let calendarSyncService = EventKitCalendarSyncService()

        return AppDependencyContainer(
            modelContainer: container,
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: context),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: context),
            aiInsightService: DefaultAIInsightService(),
            naturalLanguageParsingService: DefaultNaturalLanguageParsingService(),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            notificationService: notificationService,
            locationReminderService: CLLocationReminderService(taskRepository: taskRepository, notificationService: notificationService),
            attachmentStorageService: attachmentStorageService,
            calendarSyncService: calendarSyncService
        )
    }

    static func preview() -> AppDependencyContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: schema,
            migrationPlan: MosaicMigrationPlan.self,
            configurations: configuration
        )
        let context = container.mainContext
        let taskRepository = SwiftDataTaskRepository(context: context)
        let notificationService = UserNotificationService()
        let attachmentStorageService = FileManagerAttachmentStorageService()
        let calendarSyncService = FakeCalendarSyncService()

        return AppDependencyContainer(
            modelContainer: container,
            taskRepository: taskRepository,
            tagRepository: SwiftDataTagRepository(context: context),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: context),
            aiInsightService: DefaultAIInsightService(),
            naturalLanguageParsingService: DefaultNaturalLanguageParsingService(),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            notificationService: notificationService,
            locationReminderService: CLLocationReminderService(taskRepository: taskRepository, notificationService: notificationService),
            attachmentStorageService: attachmentStorageService,
            calendarSyncService: calendarSyncService
        )
    }

    func makeTodayViewModel() -> TodayViewModel {
        TodayViewModel(
            taskRepository: taskRepository,
            aiInsightService: aiInsightService,
            recurringTaskTemplateRepository: recurringTaskTemplateRepository,
            recurringTaskGenerationService: recurringTaskGenerationService,
            locationReminderService: locationReminderService
        )
    }

    func makeTaskCreationViewModel(capturesToInbox: Bool = false) -> TaskCreationViewModel {
        TaskCreationViewModel(
            taskRepository: taskRepository,
            tagRepository: tagRepository,
            recurringTaskTemplateRepository: recurringTaskTemplateRepository,
            recurringTaskGenerationService: recurringTaskGenerationService,
            parsingService: naturalLanguageParsingService,
            notificationService: notificationService,
            capturesToInbox: capturesToInbox
        )
    }

    func makeInboxViewModel() -> InboxViewModel {
        InboxViewModel(taskRepository: taskRepository, locationReminderService: locationReminderService)
    }

    func makeUpcomingViewModel() -> UpcomingViewModel {
        UpcomingViewModel(taskRepository: taskRepository, locationReminderService: locationReminderService, calendarSyncService: calendarSyncService)
    }

    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(taskRepository: taskRepository, tagRepository: tagRepository)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(notificationService: notificationService, taskRepository: taskRepository, calendarSyncService: calendarSyncService)
    }

    func makeCalendarPickerViewModel() -> CalendarPickerViewModel {
        CalendarPickerViewModel(calendarSyncService: calendarSyncService)
    }

    func makeTaskDetailViewModel(task: TaskItem) -> TaskDetailViewModel {
        TaskDetailViewModel(task: task, taskRepository: taskRepository, tagRepository: tagRepository, notificationService: notificationService, locationReminderService: locationReminderService, attachmentStorageService: attachmentStorageService)
    }

    func reregisterLocationReminders() async {
        let tasks = (try? taskRepository.fetchAll()) ?? []
        await locationReminderService.reregisterAll(reminders: Self.eligibleLocationReminders(from: tasks))
    }

    // Completing a task already stops its monitoring (TodayViewModel/
    // InboxViewModel.toggleCompletion). Without this filter, a completed
    // task's region gets silently re-registered on every launch — the
    // user gets an arrival/departure alert for a task they already
    // finished, and it occupies a slot against iOS's 20-region cap.
    static func eligibleLocationReminders(from tasks: [TaskItem]) -> [LocationReminderInfo] {
        tasks.filter { !$0.isCompleted }.compactMap { LocationReminderInfo(task: $0) }
    }
}
