import PhotosUI
import SwiftUI
import Foundation

@Observable
@MainActor
final class TaskDetailViewModel {
    let task: TaskItem
    private(set) var errorMessage: String?

    private let taskRepository: TaskRepository
    private let projectRepository: ProjectRepository
    private let tagRepository: TagRepository
    private let notificationService: NotificationService
    private let locationReminderService: LocationReminderService
    private let attachmentStorageService: AttachmentStorageService
    private var saveTask: Task<Void, Never>?

    init(task: TaskItem, taskRepository: TaskRepository, projectRepository: ProjectRepository, tagRepository: TagRepository, notificationService: NotificationService, locationReminderService: LocationReminderService, attachmentStorageService: AttachmentStorageService) {
        self.task = task
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.tagRepository = tagRepository
        self.notificationService = notificationService
        self.locationReminderService = locationReminderService
        self.attachmentStorageService = attachmentStorageService
    }

    var availableProjects: [Project] {
        (try? projectRepository.fetchAll()) ?? []
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled, let self else { return }
            self.persist()
        }
    }

    func persist() {
        do {
            try taskRepository.update(task)
        } catch {
            errorMessage = "Couldn't save changes."
            return
        }
        errorMessage = nil
        let reminder = TaskReminderInfo(task: task)
        Task { await notificationService.scheduleReminder(for: reminder) }
    }

    func setLocationReminder(name: String, address: String, latitude: Double, longitude: Double, trigger: LocationTrigger) async {
        let reminder = LocationReminder(name: name, address: address, latitude: latitude, longitude: longitude, trigger: trigger)
        task.locationReminder = reminder
        do {
            try taskRepository.update(task)
        } catch {
            errorMessage = "Couldn't save that location."
            return
        }

        let granted = await locationReminderService.requestAuthorization()
        guard granted else {
            errorMessage = "Location access is off, so this reminder won't fire. Enable it in Settings."
            return
        }
        errorMessage = nil
        guard let reminderInfo = LocationReminderInfo(task: task) else { return }
        await locationReminderService.startMonitoring(for: reminderInfo)
    }

    func setLocationTrigger(_ trigger: LocationTrigger) async {
        task.locationReminder?.trigger = trigger
        do {
            try taskRepository.update(task)
        } catch {
            errorMessage = "Couldn't save changes."
            return
        }
        errorMessage = nil
        guard let reminderInfo = LocationReminderInfo(task: task) else { return }
        await locationReminderService.startMonitoring(for: reminderInfo)
    }

    func clearLocationReminder() async {
        guard let reminderID = task.locationReminder?.id else { return }
        task.locationReminder = nil
        do {
            try taskRepository.update(task)
        } catch {
            errorMessage = "Couldn't remove that location."
            return
        }
        errorMessage = nil
        await locationReminderService.stopMonitoring(id: reminderID)
    }

    func addPhotoAttachment(item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "Couldn't add that photo."
            return
        }
        let filename = "Photo-\(Int(Date.now.timeIntervalSince1970)).jpg"
        await addAttachment(data: data, filename: filename, kind: .photo)
    }

    func addFileAttachment(url: URL) async {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "Couldn't add that file."
            return
        }
        let filename = url.lastPathComponent
        let kind: AttachmentKind = url.pathExtension.lowercased() == "pdf" ? .pdf : .file
        await addAttachment(data: data, filename: filename, kind: kind)
    }

    func addAttachment(data: Data, filename: String, kind: AttachmentKind) async {
        let stored: StoredFile
        do {
            stored = try attachmentStorageService.store(data: data, suggestedFilename: filename)
        } catch {
            errorMessage = "Couldn't save that attachment."
            return
        }
        let attachment = TaskAttachment(kind: kind, filename: stored.filename, fileSizeBytes: stored.fileSizeBytes, localURL: stored.localURL)
        do {
            try taskRepository.addAttachment(attachment, to: task)
            errorMessage = nil
        } catch {
            attachmentStorageService.delete(at: stored.localURL)
            errorMessage = "Couldn't save that attachment."
        }
    }

    func deleteAttachment(_ attachment: TaskAttachment) {
        let url = attachmentStorageService.resolvedURL(for: attachment.localURL)
        do {
            try taskRepository.deleteAttachment(attachment)
        } catch {
            errorMessage = "Couldn't delete that attachment."
            return
        }
        errorMessage = nil
        attachmentStorageService.delete(at: url)
    }

    func resolvedAttachmentURL(_ attachment: TaskAttachment) -> URL {
        attachmentStorageService.resolvedURL(for: attachment.localURL)
    }

    func clearError() {
        errorMessage = nil
    }

    func setProject(_ project: Project?) {
        task.project = project
        persist()
    }

    func setPriority(_ priority: Priority) {
        task.priority = priority
        persist()
    }

    func setDueDate(_ date: Date?) {
        task.dueDate = date
        if date != nil {
            task.capturedAt = nil
        }
        persist()
    }

    func setDueTime(_ time: Date?) {
        task.dueTime = time
        if let time {
            let hour = Calendar.current.component(.hour, from: time)
            task.timeOfDay = Self.timeOfDay(forHour: hour)
        }
        persist()
    }

    func addTag(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let tag = try? tagRepository.findOrCreate(name: trimmed) else {
            errorMessage = "Couldn't add that tag."
            return
        }
        guard !task.tags.contains(where: { $0.name == tag.name }) else { return }
        task.tags.append(tag)
        persist()
    }

    func removeTag(_ tag: Tag) {
        task.tags.removeAll { $0.name == tag.name }
        persist()
    }

    func addSubtask(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextSortOrder = (task.subtasks.map(\.sortOrder).max() ?? -1) + 1
        let subtask = Subtask(title: trimmed, sortOrder: nextSortOrder)
        do {
            try taskRepository.addSubtask(subtask, to: task)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't add that subtask."
        }
    }

    func toggleSubtask(_ subtask: Subtask) {
        do {
            try taskRepository.toggleSubtaskCompletion(subtask)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't update that subtask."
        }
    }

    func deleteSubtask(_ subtask: Subtask) {
        do {
            try taskRepository.deleteSubtask(subtask)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't delete that subtask."
        }
    }

    @discardableResult
    func delete() -> Bool {
        let taskID = task.id
        let locationReminderID = task.locationReminder?.id
        do {
            try taskRepository.delete(task)
        } catch {
            errorMessage = "Couldn't delete this task."
            return false
        }
        Task { await notificationService.cancelReminder(id: taskID) }
        if let locationReminderID {
            Task { await locationReminderService.stopMonitoring(id: locationReminderID) }
        }
        return true
    }

    private static func timeOfDay(forHour hour: Int?) -> TimeOfDay {
        guard let hour else { return .anytime }
        return hour < 12 ? .morning : .afternoon
    }
}
