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

    init(
        modelContainer: ModelContainer,
        taskRepository: TaskRepository,
        projectRepository: ProjectRepository,
        tagRepository: TagRepository,
        recurringTaskTemplateRepository: RecurringTaskTemplateRepository,
        aiInsightService: AIInsightService,
        naturalLanguageParsingService: NaturalLanguageParsingService,
        recurringTaskGenerationService: RecurringTaskGenerationService
    ) {
        self.modelContainer = modelContainer
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.tagRepository = tagRepository
        self.recurringTaskTemplateRepository = recurringTaskTemplateRepository
        self.aiInsightService = aiInsightService
        self.naturalLanguageParsingService = naturalLanguageParsingService
        self.recurringTaskGenerationService = recurringTaskGenerationService
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

        return AppDependencyContainer(
            modelContainer: container,
            taskRepository: taskRepository,
            projectRepository: SwiftDataProjectRepository(context: context),
            tagRepository: SwiftDataTagRepository(context: context),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: context),
            aiInsightService: DefaultAIInsightService(),
            naturalLanguageParsingService: DefaultNaturalLanguageParsingService(),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository)
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

        return AppDependencyContainer(
            modelContainer: container,
            taskRepository: taskRepository,
            projectRepository: SwiftDataProjectRepository(context: context),
            tagRepository: SwiftDataTagRepository(context: context),
            recurringTaskTemplateRepository: SwiftDataRecurringTaskTemplateRepository(context: context),
            aiInsightService: DefaultAIInsightService(),
            naturalLanguageParsingService: DefaultNaturalLanguageParsingService(),
            recurringTaskGenerationService: DefaultRecurringTaskGenerationService(taskRepository: taskRepository)
        )
    }

    func makeTodayViewModel() -> TodayViewModel {
        TodayViewModel(
            taskRepository: taskRepository,
            aiInsightService: aiInsightService,
            recurringTaskTemplateRepository: recurringTaskTemplateRepository,
            recurringTaskGenerationService: recurringTaskGenerationService
        )
    }

    func makeTaskCreationViewModel() -> TaskCreationViewModel {
        TaskCreationViewModel(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            tagRepository: tagRepository,
            recurringTaskTemplateRepository: recurringTaskTemplateRepository,
            recurringTaskGenerationService: recurringTaskGenerationService,
            parsingService: naturalLanguageParsingService
        )
    }
}
