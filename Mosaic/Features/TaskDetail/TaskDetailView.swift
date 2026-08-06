import SwiftUI

struct TaskDetailView: View {
    @State private var viewModel: TaskDetailViewModel
    @Bindable private var task: TaskItem
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingDeleteConfirmation = false
    @State private var isPresentingLocationSearch = false

    init(viewModel: TaskDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
        _task = Bindable(viewModel.task)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MosaicSpacing.lg) {
                TextField("Title", text: $task.title, axis: .vertical)
                    .font(.system(size: 22, weight: .bold))
                    .onChange(of: task.title) { _, _ in viewModel.scheduleSave() }

                TextField(
                    "Notes",
                    text: Binding(
                        get: { task.notes ?? "" },
                        set: { task.notes = $0.isEmpty ? nil : $0 }
                    ),
                    axis: .vertical
                )
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .onChange(of: task.notes) { _, _ in viewModel.scheduleSave() }

                sectionedCard(title: "Schedule") {
                    ScheduleCard(
                        task: task,
                        onChange: viewModel.persist,
                        onSetDueDate: viewModel.setDueDate,
                        onSetDueTime: viewModel.setDueTime,
                        onAddLocation: { isPresentingLocationSearch = true },
                        onClearLocation: { Task { await viewModel.clearLocationReminder() } },
                        onSetLocationTrigger: { trigger in Task { await viewModel.setLocationTrigger(trigger) } }
                    )
                }

                sectionedCard(title: "Organisation") {
                    OrganisationCard(
                        task: task,
                        availableProjects: viewModel.availableProjects,
                        onSelectProject: viewModel.setProject,
                        onSelectPriority: viewModel.setPriority,
                        onAddTag: viewModel.addTag,
                        onRemoveTag: viewModel.removeTag
                    )
                }

                sectionedCard(title: "Subtasks") {
                    SubtasksCard(
                        subtasks: task.subtasks.sorted { $0.sortOrder < $1.sortOrder },
                        onAdd: viewModel.addSubtask,
                        onToggle: viewModel.toggleSubtask,
                        onDelete: viewModel.deleteSubtask
                    )
                }

                sectionedCard(title: "Attachments") {
                    AttachmentsCard(
                        attachments: task.attachments.sorted { $0.createdAt < $1.createdAt },
                        onAddPhoto: { item in Task { await viewModel.addPhotoAttachment(item: item) } },
                        onAddFile: { url in Task { await viewModel.addFileAttachment(url: url) } },
                        onDelete: viewModel.deleteAttachment,
                        resolveURL: viewModel.resolvedAttachmentURL
                    )
                }
            }
            .padding(MosaicSpacing.md)
            .padding(.bottom, MosaicSpacing.xl)
        }
        .background(MosaicColor.canvas)
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", role: .destructive) {
                    isPresentingDeleteConfirmation = true
                }
            }
        }
        .alert("Delete Task?", isPresented: $isPresentingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dismiss()
                DispatchQueue.main.async {
                    viewModel.delete()
                }
            }
        } message: {
            Text("This can't be undone.")
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearError()
                }
            }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $isPresentingLocationSearch) {
            LocationSearchSheet(trigger: .arriving) { place, trigger in
                await viewModel.setLocationReminder(
                    name: place.name,
                    address: place.address,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    trigger: trigger
                )
            }
        }
    }

    @ViewBuilder
    private func sectionedCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: MosaicSpacing.sm) {
            SectionHeader(title: title)
            content()
        }
    }
}

#Preview {
    let container = AppDependencyContainer.preview()
    let task = TaskItem(title: "Review Q3 design system updates", notes: "Check accessibility contrast")
    try? container.taskRepository.create(task)

    return NavigationStack {
        TaskDetailView(viewModel: container.makeTaskDetailViewModel(task: task))
    }
    .environment(\.dependencies, container)
}
