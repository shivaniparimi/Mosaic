import SwiftUI

struct TaskCreationSheet: View {
    @State private var viewModel: TaskCreationViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool

    init(viewModel: TaskCreationViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MosaicSpacing.md) {
                TextField("What do you need to do?", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: 19, weight: .medium))
                    .focused($isInputFocused)
                    .onChange(of: viewModel.inputText) { _, _ in
                        viewModel.scheduleParse()
                    }

                if let draft = viewModel.draft {
                    chipsRow(for: draft)
                }

                if viewModel.canCreate {
                    previewCard
                }

                Spacer()
            }
            .padding(MosaicSpacing.md)
            .background(MosaicColor.canvas)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            if await viewModel.createTask() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canCreate)
                }
            }
            .onAppear {
                isInputFocused = true
            }
            .alert("Couldn't Create Task", isPresented: Binding(
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
        }
    }

    @ViewBuilder
    private func chipsRow(for draft: ParsedTaskDraft) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MosaicSpacing.sm) {
                // Suppressed in recurring mode: `detectDate` independently matches
                // the first full weekday name ("gym monday wednesday friday"), but
                // the recurring path never reads `draft.date`, so the chip would
                // imply a one-off task on a date that is never used.
                if let date = draft.date, (draft.recurringWeekdays?.count ?? 0) < 2 {
                    ChipView(icon: "calendar", label: Self.dateFormatter.string(from: date), tintColor: .blue) {
                        viewModel.clearDate()
                    }
                }
                if let weekdays = draft.recurringWeekdays, weekdays.count >= 2 {
                    ChipView(icon: "repeat", label: Self.weekdaysLabel(for: weekdays), tintColor: MosaicColor.accent) {
                        viewModel.clearRecurringWeekdays()
                    }
                }
                if let timeRange = draft.timeRangeComponents {
                    ChipView(icon: "clock", label: Self.timeRangeLabel(for: timeRange), tintColor: .orange) {
                        viewModel.clearTimeRange()
                    }
                }
                if let time = draft.timeComponents {
                    ChipView(icon: "clock", label: Self.timeLabel(for: time), tintColor: .orange) {
                        viewModel.clearTime()
                    }
                }
                if let projectName = draft.projectName {
                    ChipView(icon: "folder", label: projectName, tintColor: .blue) {
                        viewModel.clearProject()
                    }
                }
                if let tagName = draft.tagName {
                    ChipView(icon: "tag", label: "#\(tagName)", tintColor: MosaicColor.tagPurple) {
                        viewModel.clearTag()
                    }
                }
                if draft.hasReminder {
                    ChipView(icon: "bell", label: "Reminder", tintColor: MosaicColor.accent) {
                        viewModel.clearReminder()
                    }
                }
            }
        }
    }

    private var previewCard: some View {
        TaskCard(
            title: viewModel.draft?.cleanedTitle ?? viewModel.inputText,
            isCompleted: false,
            time: viewModel.draft?.timeRangeComponents.map { Self.timeRangeLabel(for: $0) }
                ?? viewModel.draft?.timeComponents.map { Self.timeLabel(for: $0) },
            projectName: viewModel.draft?.projectName,
            projectColor: nil,
            hasReminder: viewModel.draft?.hasReminder ?? false,
            hasAttachments: false,
            onToggleCompletion: {}
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func weekdaysLabel(for weekdays: Set<Int>) -> String {
        let shortNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return weekdays.sorted().compactMap { weekday in
            (weekday >= 1 && weekday <= 7) ? shortNames[weekday - 1] : nil
        }.joined(separator: ", ")
    }

    private static func timeRangeLabel(for range: ParsedTimeRange) -> String {
        "\(timeLabel(for: range.start)) - \(timeLabel(for: range.end))"
    }

    private static func timeLabel(for components: ParsedTimeComponents) -> String {
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: components.hour, minute: components.minute, second: 0, of: .now) ?? .now
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
