import SwiftUI

struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: TodayViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MosaicSpacing.lg) {
                if let insight = viewModel.insight {
                    InsightCard(message: insight.message)
                }

                if viewModel.totalCount == 0 {
                    EmptyStateView(
                        iconSystemName: "checkmark.circle",
                        title: "All done for today",
                        message: "Nothing left on your plate. Enjoy the rest of your day."
                    )
                    .padding(.top, MosaicSpacing.xl)
                } else {
                    taskSections
                }
            }
            .padding(MosaicSpacing.md)
        }
        .background(MosaicColor.canvas)
        // Pinning the header as a top safe-area inset keeps scrolled content from
        // rendering under the status bar / Dynamic Island: the ScrollView's content
        // is inset below the header, and the header's background extends up through
        // the status bar so nothing can scroll into that band.
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .padding(.horizontal, MosaicSpacing.md)
                .padding(.top, MosaicSpacing.md)
                .padding(.bottom, MosaicSpacing.sm)
                .background(MosaicColor.canvas.ignoresSafeArea(edges: .top))
        }
        .task {
            await viewModel.load()
        }
        // Tabs stay mounted for the app's lifetime, so `.task` fires exactly once.
        // Without these, Today would keep showing yesterday's date and tasks after
        // midnight, and would miss tasks created elsewhere while it was backgrounded.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.load() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: MosaicSpacing.xs) {
                Text("Today")
                    .font(.system(size: 34, weight: .bold))
                Text(Self.dateFormatter.string(from: .now))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ProgressRing(
                completed: viewModel.completedTasks.count,
                total: viewModel.totalCount
            )
        }
    }

    @ViewBuilder
    private var taskSections: some View {
        sectionIfNeeded(title: "Morning", tasks: viewModel.morningTasks)
        sectionIfNeeded(title: "Afternoon", tasks: viewModel.afternoonTasks)
        sectionIfNeeded(title: "Anytime", tasks: viewModel.anytimeTasks)

        if !viewModel.completedTasks.isEmpty {
            completedSection
        }
    }

    @ViewBuilder
    private func sectionIfNeeded(title: String, tasks: [TaskItem]) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: MosaicSpacing.sm) {
                SectionHeader(title: title)
                ForEach(tasks) { task in
                    taskCard(for: task)
                }
            }
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: MosaicSpacing.sm) {
            Button {
                viewModel.toggleCompletedSectionExpanded()
            } label: {
                HStack {
                    Text("Completed \u{00B7} \(viewModel.completedTasks.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(viewModel.isCompletedSectionExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if viewModel.isCompletedSectionExpanded {
                ForEach(viewModel.completedTasks) { task in
                    taskCard(for: task)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isCompletedSectionExpanded)
    }

    private func taskCard(for task: TaskItem) -> some View {
        TaskCard(
            title: task.title,
            isCompleted: task.isCompleted,
            time: task.dueTime.map { Self.timeFormatter.string(from: $0) },
            projectName: task.project?.name,
            projectColor: task.project.map { Color(hex: $0.colorHex) },
            hasReminder: task.hasReminder,
            hasAttachments: !task.attachments.isEmpty,
            isRecurring: task.recurringTemplate != nil,
            onStopRepeating: task.recurringTemplate != nil ? {
                Task { await viewModel.stopRepeating(task) }
            } : nil,
            onToggleCompletion: {
                Task {
                    await viewModel.toggleCompletion(task)
                }
            }
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

#Preview {
    let container = AppDependencyContainer.preview()
    let today = Date.now
    let calendar = Calendar.current
    let project = Project(name: "Design", colorHex: "#E8738A")
    try? container.projectRepository.create(project)
    try? container.taskRepository.create(TaskItem(
        title: "Review Q3 design system updates",
        dueDate: today,
        dueTime: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today),
        timeOfDay: .morning,
        hasReminder: true,
        project: project
    ))
    try? container.taskRepository.create(TaskItem(
        title: "Team standup call",
        dueDate: today,
        dueTime: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: today),
        timeOfDay: .morning
    ))
    try? container.taskRepository.create(TaskItem(
        title: "Write product proposal draft",
        dueDate: today,
        dueTime: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today),
        timeOfDay: .afternoon
    ))
    try? container.taskRepository.create(TaskItem(
        title: "Pick up prescription",
        isCompleted: true,
        dueDate: today,
        timeOfDay: .anytime
    ))

    return TodayView(viewModel: container.makeTodayViewModel())
        .environment(\.dependencies, container)
}
