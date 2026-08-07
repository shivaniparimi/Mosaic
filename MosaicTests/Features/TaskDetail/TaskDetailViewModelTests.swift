import Testing
import SwiftData
import Foundation
@testable import Mosaic

@MainActor
struct TaskDetailViewModelTests {
    private func makeViewModel(
        task: TaskItem,
        context: ModelContext,
        notificationService: NotificationService = RecordingNotificationService(),
        locationReminderService: LocationReminderService = RecordingLocationReminderService(),
        attachmentStorageService: AttachmentStorageService = RecordingAttachmentStorageService()
    ) -> TaskDetailViewModel {
        TaskDetailViewModel(
            task: task,
            taskRepository: SwiftDataTaskRepository(context: context),
            tagRepository: SwiftDataTagRepository(context: context),
            notificationService: notificationService,
            locationReminderService: locationReminderService,
            attachmentStorageService: attachmentStorageService
        )
    }

    @Test func persistSavesDirectTaskMutations() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Original")
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        task.title = "Updated"
        viewModel.persist()

        let reloaded = try taskRepository.fetchAll().first
        #expect(reloaded?.title == "Updated")
    }

    @Test func setPriorityUpdatesAndPersists() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        viewModel.setPriority(.high)

        #expect(task.priority == .high)
    }

    @Test func addTagCreatesAndAttachesNewTag() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        viewModel.addTag(name: "urgent")

        #expect(task.tags.map(\.name) == ["urgent"])
    }

    @Test func addTagIsANoOpForBlankName() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        viewModel.addTag(name: "   ")

        #expect(task.tags.isEmpty)
    }

    @Test func addTagDoesNotDuplicateAnExistingTagOnTheTask() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let tagRepository = SwiftDataTagRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)
        let tag = try tagRepository.findOrCreate(name: "urgent")
        task.tags.append(tag)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        viewModel.addTag(name: "urgent")

        #expect(task.tags.count == 1)
    }

    @Test func removeTagRemovesItFromTheTask() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let tagRepository = SwiftDataTagRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)
        let tag = try tagRepository.findOrCreate(name: "urgent")
        task.tags.append(tag)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        viewModel.removeTag(tag)

        #expect(task.tags.isEmpty)
    }

    @Test func addSubtaskAppendsWithCorrectSortOrder() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        viewModel.addSubtask(title: "First")
        viewModel.addSubtask(title: "Second")

        let sorted = task.subtasks.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted.map(\.title) == ["First", "Second"])
        #expect(sorted.map(\.sortOrder) == [0, 1])
    }

    @Test func addSubtaskIsANoOpForBlankTitle() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        viewModel.addSubtask(title: "   ")

        #expect(task.subtasks.isEmpty)
    }

    @Test func toggleSubtaskFlipsCompletion() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        viewModel.addSubtask(title: "First")
        let subtask = try #require(task.subtasks.first)

        viewModel.toggleSubtask(subtask)

        #expect(subtask.isCompleted)
    }

    @Test func deleteSubtaskRemovesItFromTheTask() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        viewModel.addSubtask(title: "First")
        let subtask = try #require(task.subtasks.first)

        viewModel.deleteSubtask(subtask)

        #expect(task.subtasks.isEmpty)
    }

    @Test func setDueDateWithNonNilDateClearsCapturedAtAndPersists() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task", capturedAt: .now, origin: .quickCapture)
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        let newDate = Calendar.current.startOfDay(for: .now)
        viewModel.setDueDate(newDate)

        #expect(task.dueDate == newDate)
        #expect(task.capturedAt == nil)

        let reloaded = try taskRepository.fetchAll().first
        #expect(reloaded?.dueDate == newDate)
        #expect(reloaded?.capturedAt == nil)
    }

    @Test func setDueDateWithNilClearsDueDateWithoutTouchingCapturedAt() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task", dueDate: .now)
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        viewModel.setDueDate(nil)

        #expect(task.dueDate == nil)
        #expect(task.capturedAt == nil)
    }

    @Test func setDueTimeInTheMorningSetsTimeOfDayToMorningAndPersists() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        let morningTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
        viewModel.setDueTime(morningTime)

        #expect(task.dueTime == morningTime)
        #expect(task.timeOfDay == .morning)

        let reloaded = try taskRepository.fetchAll().first
        #expect(reloaded?.timeOfDay == .morning)
    }

    @Test func setDueTimeInTheAfternoonSetsTimeOfDayToAfternoon() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        let afternoonTime = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: .now)!
        viewModel.setDueTime(afternoonTime)

        #expect(task.timeOfDay == .afternoon)
    }

    @Test func setDueTimeWithNilDoesNotChangeTimeOfDay() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task", timeOfDay: .anytime)
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        viewModel.setDueTime(nil)

        #expect(task.dueTime == nil)
        #expect(task.timeOfDay == .anytime)
    }

    @Test func addSubtaskAfterDeletionDoesNotCollideSortOrder() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        viewModel.addSubtask(title: "First")
        viewModel.addSubtask(title: "Second")
        viewModel.addSubtask(title: "Third")

        let first = try #require(task.subtasks.first { $0.title == "First" })
        viewModel.deleteSubtask(first)

        viewModel.addSubtask(title: "Fourth")

        let sortOrders = task.subtasks.map(\.sortOrder)
        #expect(Set(sortOrders).count == sortOrders.count, "sortOrder values must not collide")

        let fourth = try #require(task.subtasks.first { $0.title == "Fourth" })
        let remainingOthers = task.subtasks.filter { $0.title != "Fourth" }
        #expect(!remainingOthers.contains { $0.sortOrder == fourth.sortOrder })
    }

    @Test func deleteRemovesTheTaskFromTheRepository() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let viewModel = makeViewModel(task: task, context: container.mainContext)
        let deleted = viewModel.delete()

        #expect(deleted)
        #expect(try taskRepository.fetchAll().isEmpty)
    }

    @Test func persistSchedulesReminderAfterSuccessfulSave() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task", dueDate: .now, dueTime: .now, hasReminder: true)
        try taskRepository.create(task)

        let notificationService = RecordingNotificationService()
        let viewModel = makeViewModel(task: task, context: container.mainContext, notificationService: notificationService)
        viewModel.persist()

        try await Task.sleep(for: .milliseconds(50))

        #expect(notificationService.scheduledTaskIDs == [task.id])
    }

    @Test func deleteCancelsReminder() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task", dueDate: .now, dueTime: .now, hasReminder: true)
        try taskRepository.create(task)

        let notificationService = RecordingNotificationService()
        let viewModel = makeViewModel(task: task, context: container.mainContext, notificationService: notificationService)
        let deleted = viewModel.delete()

        try await Task.sleep(for: .milliseconds(50))

        #expect(deleted)
        #expect(notificationService.cancelledTaskIDs == [task.id])
    }

    @Test func setLocationReminderSavesAndStartsMonitoringWhenAuthorized() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let locationService = RecordingLocationReminderService(authorizationGranted: true)
        let viewModel = makeViewModel(task: task, context: container.mainContext, locationReminderService: locationService)

        await viewModel.setLocationReminder(name: "Home", address: "123 Main St", latitude: 37.0, longitude: -122.0, trigger: .arriving)

        #expect(task.locationReminder?.name == "Home")
        #expect(task.locationReminder?.trigger == .arriving)
        #expect(locationService.startedReminderIDs == [task.locationReminder!.id])
        #expect(viewModel.errorMessage == nil)
    }

    @Test func setLocationReminderSavesButDoesNotMonitorWhenDenied() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let locationService = RecordingLocationReminderService(authorizationGranted: false)
        let viewModel = makeViewModel(task: task, context: container.mainContext, locationReminderService: locationService)

        await viewModel.setLocationReminder(name: "Home", address: "123 Main St", latitude: 37.0, longitude: -122.0, trigger: .arriving)

        #expect(task.locationReminder?.name == "Home")
        #expect(locationService.startedReminderIDs.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func setLocationTriggerUpdatesAndRestartsMonitoring() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let reminder = LocationReminder(name: "Home", address: "123 Main St", latitude: 37.0, longitude: -122.0, trigger: .arriving)
        let task = TaskItem(title: "Task")
        task.locationReminder = reminder
        try taskRepository.create(task)

        let locationService = RecordingLocationReminderService()
        let viewModel = makeViewModel(task: task, context: container.mainContext, locationReminderService: locationService)

        await viewModel.setLocationTrigger(.leaving)

        #expect(task.locationReminder?.trigger == .leaving)
        #expect(locationService.startedReminderIDs == [reminder.id])
    }

    @Test func clearLocationReminderRemovesItAndStopsMonitoring() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let reminder = LocationReminder(name: "Home", address: "123 Main St", latitude: 37.0, longitude: -122.0, trigger: .arriving)
        let reminderID = reminder.id
        let task = TaskItem(title: "Task")
        task.locationReminder = reminder
        try taskRepository.create(task)

        let locationService = RecordingLocationReminderService()
        let viewModel = makeViewModel(task: task, context: container.mainContext, locationReminderService: locationService)

        await viewModel.clearLocationReminder()

        #expect(task.locationReminder == nil)
        #expect(locationService.stoppedReminderIDs == [reminderID])
    }

    @Test func deleteStopsLocationMonitoringWhenReminderExists() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let reminder = LocationReminder(name: "Home", address: "123 Main St", latitude: 37.0, longitude: -122.0, trigger: .arriving)
        let reminderID = reminder.id
        let task = TaskItem(title: "Task")
        task.locationReminder = reminder
        try taskRepository.create(task)

        let locationService = RecordingLocationReminderService()
        let viewModel = makeViewModel(task: task, context: container.mainContext, locationReminderService: locationService)

        let deleted = viewModel.delete()
        try await Task.sleep(for: .milliseconds(50))

        #expect(deleted)
        #expect(locationService.stoppedReminderIDs == [reminderID])
    }

    @Test func addAttachmentStoresFileAndAppendsToTask() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let storageService = RecordingAttachmentStorageService()
        let viewModel = makeViewModel(task: task, context: container.mainContext, attachmentStorageService: storageService)

        await viewModel.addAttachment(data: Data("photo bytes".utf8), filename: "sunset.jpg", kind: .photo)

        #expect(task.attachments.count == 1)
        #expect(task.attachments.first?.filename == "sunset.jpg")
        #expect(task.attachments.first?.kind == .photo)
        #expect(task.attachments.first?.fileSizeBytes == Data("photo bytes".utf8).count)
        #expect(storageService.storedFilenames == ["sunset.jpg"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test func addAttachmentSetsErrorMessageAndDoesNotMutateTaskWhenStorageFails() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let storageService = RecordingAttachmentStorageService()
        storageService.shouldThrowOnStore = true
        let viewModel = makeViewModel(task: task, context: container.mainContext, attachmentStorageService: storageService)

        await viewModel.addAttachment(data: Data("bytes".utf8), filename: "file.txt", kind: .file)

        #expect(task.attachments.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func addAttachmentDeletesStoredFileWhenRepositorySaveFails() async throws {
        let container = TestModelContainer.makeInMemory()
        let task = TaskItem(title: "Task")

        let storageService = RecordingAttachmentStorageService()
        let viewModel = TaskDetailViewModel(
            task: task,
            taskRepository: FailingAddAttachmentTaskRepository(),
            tagRepository: SwiftDataTagRepository(context: container.mainContext),
            notificationService: RecordingNotificationService(),
            locationReminderService: RecordingLocationReminderService(),
            attachmentStorageService: storageService
        )

        await viewModel.addAttachment(data: Data("bytes".utf8), filename: "file.txt", kind: .file)

        #expect(storageService.storedFilenames == ["file.txt"])
        let expectedURL = FileManager.default.temporaryDirectory.appendingPathComponent("file.txt")
        #expect(storageService.deletedURLs == [expectedURL])
        #expect(viewModel.errorMessage != nil)
    }

    @Test func addFileAttachmentReadsRealFileAndInfersPdfKind() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("receipt.pdf")
        try Data("pdf bytes".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let storageService = RecordingAttachmentStorageService()
        let viewModel = makeViewModel(task: task, context: container.mainContext, attachmentStorageService: storageService)

        await viewModel.addFileAttachment(url: tempURL)

        #expect(task.attachments.first?.filename == "receipt.pdf")
        #expect(task.attachments.first?.kind == .pdf)
    }

    @Test func addFileAttachmentInfersFileKindForNonPdfExtensions() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("notes.txt")
        try Data("text bytes".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let storageService = RecordingAttachmentStorageService()
        let viewModel = makeViewModel(task: task, context: container.mainContext, attachmentStorageService: storageService)

        await viewModel.addFileAttachment(url: tempURL)

        #expect(task.attachments.first?.kind == .file)
    }

    @Test func deleteAttachmentRemovesFromTaskAndDeletesFromStorage() async throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let task = TaskItem(title: "Task")
        try taskRepository.create(task)

        let storageService = RecordingAttachmentStorageService()
        let viewModel = makeViewModel(task: task, context: container.mainContext, attachmentStorageService: storageService)
        await viewModel.addAttachment(data: Data("bytes".utf8), filename: "file.txt", kind: .file)
        let attachment = try #require(task.attachments.first)
        let attachmentURL = attachment.localURL

        viewModel.deleteAttachment(attachment)

        #expect(task.attachments.isEmpty)
        #expect(storageService.deletedURLs == [attachmentURL])
    }
}

private final class RecordingNotificationService: NotificationService {
    private(set) var scheduledTaskIDs: [UUID] = []
    private(set) var cancelledTaskIDs: [UUID] = []

    func requestAuthorization() async -> Bool { true }

    func scheduleReminder(for reminder: TaskReminderInfo) async {
        scheduledTaskIDs.append(reminder.id)
    }

    func cancelReminder(id: UUID) async {
        cancelledTaskIDs.append(id)
    }

    func cancelAllReminders() async {}

    func postLocationAlert(identifier: String, title: String, body: String) async {}
}

private final class RecordingLocationReminderService: LocationReminderService {
    private let authorizationGranted: Bool
    private(set) var startedReminderIDs: [UUID] = []
    private(set) var stoppedReminderIDs: [UUID] = []

    init(authorizationGranted: Bool = true) {
        self.authorizationGranted = authorizationGranted
    }

    func requestAuthorization() async -> Bool { authorizationGranted }

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

private struct FailingAddAttachmentTaskRepository: TaskRepository {
    func fetchAll() throws -> [TaskItem] { [] }
    func fetchInbox() throws -> [TaskItem] { [] }
    func create(_ task: TaskItem) throws { }
    func createMany(_ tasks: [TaskItem]) throws { }
    func update(_ task: TaskItem) throws { }
    func delete(_ task: TaskItem) throws { }
    func toggleCompletion(_ task: TaskItem) throws { }
    func search(query: String) throws -> [TaskItem] { [] }
    func addSubtask(_ subtask: Subtask, to task: TaskItem) throws { }
    func toggleSubtaskCompletion(_ subtask: Subtask) throws { }
    func deleteSubtask(_ subtask: Subtask) throws { }
    func addAttachment(_ attachment: TaskAttachment, to task: TaskItem) throws {
        throw NSError(domain: "test", code: 1)
    }
    func deleteAttachment(_ attachment: TaskAttachment) throws { }
}

private final class RecordingAttachmentStorageService: AttachmentStorageService {
    var shouldThrowOnStore = false
    private(set) var storedFilenames: [String] = []
    private(set) var deletedURLs: [URL] = []

    func store(data: Data, suggestedFilename: String) throws -> StoredFile {
        if shouldThrowOnStore {
            struct StoreError: Error {}
            throw StoreError()
        }
        storedFilenames.append(suggestedFilename)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedFilename)
        return StoredFile(localURL: url, filename: suggestedFilename, fileSizeBytes: data.count)
    }

    func delete(at url: URL) {
        deletedURLs.append(url)
    }

    func resolvedURL(for storedURL: URL) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(storedURL.lastPathComponent)
    }
}
