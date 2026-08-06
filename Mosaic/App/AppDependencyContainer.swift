import SwiftData

@MainActor
final class AppDependencyContainer {
    let modelContainer: ModelContainer
    let taskRepository: TaskRepository
    let projectRepository: ProjectRepository
    let tagRepository: TagRepository
    let recurringTaskTemplateRepository: RecurringTaskTemplateRepository
    let aiInsightService: AIInsightService
    let naturalLanguageParsingService: NaturalLanguageParsingService
    let recurringTaskGenerationService: RecurringTaskGenerationService
    let notificationService: NotificationService
    let locationReminderService: LocationReminderService
    let attachmentStorageService: AttachmentStorageService

    init(
        modelContainer: ModelContainer,
        taskRepository: TaskRepository,
        projectRepository: ProjectRepository,
        tagRepository: TagRepository,
        recurringTaskTemplateRepository: RecurringTaskTemplateRepository,
        aiInsightService: AIInsightService,
        naturalLanguageParsingService: NaturalLanguageParsingService,
        recurringTaskGenerationService: RecurringTaskGenerationService,
        notificationService: NotificationService,
        locationReminderService: LocationReminderService,
        attachmentStorageService: AttachmentStorageService
    ) {
        self.modelContainer = modelContainer
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.tagRepository = tagRepository
        self.recurringTaskTemplateRepository = recurringTaskTemplateRepository
        self.aiInsightService = aiInsightService
        self.naturalLanguageParsingService = naturalLanguageParsingService
        self.recurringTaskGenerationService = recurringTaskGenerationService
        self.notificationService = notificationService
        self.locationReminderService = locationReminderService
        self.attachmentStorageService = attachmentStorageService
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

        return AppDependencyContainer(
            modelContainer: container,
            taskRepository: taskRepository,
            projectRepository: SwiftDataProjectRepository(context: context),
            tagRepository: SwiftDataTagRepository(context: context),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: context),
            aiInsightService: DefaultAIInsightService(),
            naturalLanguageParsingService: DefaultNaturalLanguageParsingService(),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            notificationService: notificationService,
            locationReminderService: CLLocationReminderService(taskRepository: taskRepository, notificationService: notificationService),
            attachmentStorageService: attachmentStorageService
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

        return AppDependencyContainer(
            modelContainer: container,
            taskRepository: taskRepository,
            projectRepository: SwiftDataProjectRepository(context: context),
            tagRepository: SwiftDataTagRepository(context: context),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: context),
            aiInsightService: DefaultAIInsightService(),
            naturalLanguageParsingService: DefaultNaturalLanguageParsingService(),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository),
            notificationService: notificationService,
            locationReminderService: CLLocationReminderService(taskRepository: taskRepository, notificationService: notificationService),
            attachmentStorageService: attachmentStorageService
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
            projectRepository: projectRepository,
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

    func makeProjectsViewModel() -> ProjectsViewModel {
        ProjectsViewModel(projectRepository: projectRepository, taskRepository: taskRepository, aiInsightService: aiInsightService)
    }

    func makeNewProjectViewModel() -> NewProjectViewModel {
        NewProjectViewModel(projectRepository: projectRepository)
    }

    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(taskRepository: taskRepository, projectRepository: projectRepository, tagRepository: tagRepository)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(notificationService: notificationService, taskRepository: taskRepository)
    }

    func makeTaskDetailViewModel(task: TaskItem) -> TaskDetailViewModel {
        TaskDetailViewModel(task: task, taskRepository: taskRepository, projectRepository: projectRepository, tagRepository: tagRepository, notificationService: notificationService, locationReminderService: locationReminderService, attachmentStorageService: attachmentStorageService)
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
