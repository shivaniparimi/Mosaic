import SwiftUI

struct InboxView: View {
    @State private var viewModel: InboxViewModel
    @FocusState private var isCaptureFocused: Bool
    @State private var selectedTask: TaskItem?
    @Environment(\.dependencies) private var dependencies
    @Environment(\.tabRouter) private var router

    init(viewModel: InboxViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MosaicSpacing.lg) {
                captureField

                if viewModel.items.isEmpty {
                    EmptyStateView(
                        iconSystemName: "tray",
                        title: "Inbox Zero",
                        message: "Capture a task above and it'll show up here."
                    )
                    .padding(.top, MosaicSpacing.xl)
                } else {
                    VStack(spacing: MosaicSpacing.sm) {
                        ForEach(viewModel.items) { task in
                            taskCard(for: task)
                        }
                    }
                }
            }
            .padding(MosaicSpacing.md)
        }
        .background(MosaicColor.canvas)
        .navigationDestination(item: $selectedTask) { task in
            TaskDetailView(viewModel: dependencies.makeTaskDetailViewModel(task: task))
        }
        .onChange(of: selectedTask) { _, newValue in
            router.setDetailPresented(newValue != nil, for: .inbox)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("Inbox")
                .font(.system(size: 34, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MosaicSpacing.md)
                .padding(.top, MosaicSpacing.md)
                .padding(.bottom, MosaicSpacing.sm)
                .background(MosaicColor.canvas.ignoresSafeArea(edges: .top))
        }
        .task {
            await viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
    }

    private var captureField: some View {
        TextField("Capture a task", text: $viewModel.captureText)
            .font(.system(size: 16))
            .focused($isCaptureFocused)
            .padding(MosaicSpacing.md)
            .background(MosaicColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onSubmit {
                Task { await viewModel.capture() }
            }
    }

    private func taskCard(for task: TaskItem) -> some View {
        TaskCard(
            title: task.title,
            isCompleted: task.isCompleted,
            time: task.capturedAt.map { Self.relativeFormatter.localizedString(for: $0, relativeTo: .now) },
            onMoveToToday: {
                Task { await viewModel.moveToToday(task) }
            },
            onTap: { selectedTask = task },
            onToggleCompletion: {
                Task { await viewModel.toggleCompletion(task) }
            }
        )
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

#Preview {
    let container = AppDependencyContainer.preview()
    try? container.taskRepository.create(TaskItem(
        title: "Buy birthday gift",
        capturedAt: .now,
        origin: .quickCapture
    ))
    try? container.taskRepository.create(TaskItem(
        title: "Read design doc",
        capturedAt: Date.now.addingTimeInterval(-3600 * 5),
        origin: .quickCapture
    ))

    return InboxView(viewModel: container.makeInboxViewModel())
        .environment(\.dependencies, container)
}
