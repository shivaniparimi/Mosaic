import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(\.dependencies) private var dependencies

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MosaicSpacing.lg) {
                section(title: "Appearance") {
                    IconRow(icon: "paintbrush", title: "Theme") {
                        SegmentedPillControl(
                            options: AppTheme.allCases,
                            label: { $0.label },
                            selection: $viewModel.theme
                        )
                    }
                }

                section(title: "Notifications") {
                    ToggleRow(icon: "bell", title: "Enable Notifications", isOn: $viewModel.notificationsEnabled)
                }

                section(title: "AI Settings") {
                    ToggleRow(icon: "sparkles", title: "AI Insights", isOn: $viewModel.aiInsightsEnabled)
                }

                section(title: "Calendar") {
                    ToggleRow(icon: "calendar", title: "Sync Calendar", isOn: $viewModel.calendarSyncEnabled)
                    if viewModel.calendarSyncEnabled {
                        NavigationLink {
                            CalendarPickerView(viewModel: dependencies.makeCalendarPickerViewModel())
                        } label: {
                            IconRow(icon: "list.bullet", title: "Choose Calendars") {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                section(title: "Reminders") {
                    ToggleRow(icon: "checklist", title: "Sync Reminders", isOn: $viewModel.reminderSyncEnabled)
                }
            }
            .padding(MosaicSpacing.md)
        }
        .background(MosaicColor.canvas)
        .onChange(of: viewModel.notificationsEnabled) { _, _ in
            Task { await viewModel.handleNotificationsToggleChanged() }
        }
        .onChange(of: viewModel.calendarSyncEnabled) { _, _ in
            Task { await viewModel.handleCalendarSyncToggleChanged() }
        }
        .onChange(of: viewModel.reminderSyncEnabled) { _, _ in
            Task { await viewModel.handleReminderSyncToggleChanged() }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("Settings")
                .font(.system(size: 34, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MosaicSpacing.md)
                .padding(.top, MosaicSpacing.md)
                .padding(.bottom, MosaicSpacing.sm)
                .background(MosaicColor.canvas.ignoresSafeArea(edges: .top))
        }
    }

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: MosaicSpacing.sm) {
            SectionHeader(title: title)
            GroupedCard {
                content()
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: AppDependencyContainer.preview().makeSettingsViewModel())
}
