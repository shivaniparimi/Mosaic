import SwiftUI

struct UpcomingView: View {
    @State private var viewModel: UpcomingViewModel
    @State private var selectedTask: TaskItem?
    @State private var selectedEvent: CalendarEvent?
    @AppStorage(SettingsKeys.calendarSyncEnabled) private var calendarSyncEnabled = false
    @Environment(\.dependencies) private var dependencies
    @Environment(\.tabRouter) private var router

    init(viewModel: UpcomingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MosaicSpacing.lg) {
                if viewModel.overdueTasks.isEmpty && viewModel.daySections.isEmpty {
                    EmptyStateView(
                        iconSystemName: "calendar",
                        title: "Nothing Upcoming",
                        message: "Tasks with a due date will show up here."
                    )
                    .padding(.top, MosaicSpacing.xl)
                } else {
                    if !viewModel.overdueTasks.isEmpty {
                        overdueSection
                    }
                    daySectionsList
                }
            }
            .padding(MosaicSpacing.md)
            .padding(.bottom, MosaicSpacing.xl)
        }
        .background(MosaicColor.canvas)
        .navigationDestination(item: $selectedTask) { task in
            TaskDetailView(viewModel: dependencies.makeTaskDetailViewModel(task: task))
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
        .onChange(of: selectedTask) { _, newValue in
            router.setDetailPresented(newValue != nil, for: .upcoming)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("Upcoming")
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
        .onChange(of: calendarSyncEnabled) { _, _ in
            Task { await viewModel.load() }
        }
    }

    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: MosaicSpacing.sm) {
            Text("OVERDUE")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1)
                .foregroundStyle(MosaicColor.destructive)
            ForEach(viewModel.overdueTasks) { task in
                taskCard(for: task)
            }
        }
    }

    @ViewBuilder
    private var daySectionsList: some View {
        let annotated = Self.sectionsAnnotatedWithMonthChange(viewModel.daySections)
        ForEach(annotated, id: \.section.id) { entry in
            if entry.showsMonthDivider {
                SectionHeader(title: Self.monthFormatter.string(from: entry.section.date))
            }
            HStack(alignment: .top, spacing: MosaicSpacing.md) {
                DayBadge(
                    dayOfWeek: Self.dayOfWeekFormatter.string(from: entry.section.date).uppercased(),
                    dayNumber: Self.dayNumberFormatter.string(from: entry.section.date),
                    month: Self.monthAbbreviationFormatter.string(from: entry.section.date).uppercased(),
                    isToday: Calendar.current.isDateInToday(entry.section.date)
                )

                Divider()

                VStack(spacing: MosaicSpacing.sm) {
                    ForEach(entry.section.items) { item in
                        rowView(for: item)
                    }
                }
            }
        }
    }

    private func taskCard(for task: TaskItem) -> some View {
        TaskCard(
            title: task.title,
            isCompleted: task.isCompleted,
            time: task.dueTime.map { Self.timeFormatter.string(from: $0) },
            hasReminder: task.hasReminder,
            hasAttachments: !task.attachments.isEmpty,
            isRecurring: task.recurringTemplate != nil,
            onTap: { selectedTask = task },
            onToggleCompletion: {
                Task { await viewModel.toggleCompletion(task) }
            }
        )
    }

    @ViewBuilder
    private func rowView(for item: UpcomingItem) -> some View {
        switch item {
        case .task(let task):
            taskCard(for: task)
        case .event(let event):
            EventRow(
                title: event.title,
                timeLabel: Self.eventTimeLabel(for: event),
                onTap: { selectedEvent = event }
            )
        }
    }

    private static func eventTimeLabel(for event: CalendarEvent) -> String {
        event.isAllDay ? "All-day" : timeFormatter.string(from: event.startDate)
    }

    private struct AnnotatedSection {
        let section: UpcomingDaySection
        let showsMonthDivider: Bool
    }

    private static func sectionsAnnotatedWithMonthChange(_ sections: [UpcomingDaySection]) -> [AnnotatedSection] {
        var result: [AnnotatedSection] = []
        var lastMonth: Int?
        let calendar = Calendar.current
        for section in sections {
            let month = calendar.component(.month, from: section.date)
            result.append(AnnotatedSection(section: section, showsMonthDivider: month != lastMonth))
            lastMonth = month
        }
        return result
    }

    private static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let dayNumberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let monthAbbreviationFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
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
    let calendar = Calendar.current
    let today = Date.now
    try? container.taskRepository.create(TaskItem(title: "Overdue task", dueDate: calendar.date(byAdding: .day, value: -2, to: today)))
    try? container.taskRepository.create(TaskItem(title: "Today's task", dueDate: today, dueTime: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)))
    try? container.taskRepository.create(TaskItem(title: "Tomorrow's task", dueDate: calendar.date(byAdding: .day, value: 1, to: today)))
    try? container.taskRepository.create(TaskItem(title: "Next month's task", dueDate: calendar.date(byAdding: .month, value: 1, to: today)))

    return UpcomingView(viewModel: container.makeUpcomingViewModel())
        .environment(\.dependencies, container)
}
