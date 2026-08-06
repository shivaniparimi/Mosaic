import SwiftUI

struct RootTabView: View {
    @State private var router = TabRouter()
    @State private var tabBarHeight: CGFloat = 0
    @State private var isPresentingTaskCreation = false
    @State private var isPresentingNewProject = false
    @State private var inboxCount = 0
    @AppStorage(SettingsKeys.theme) private var themeRawValue: String = AppTheme.system.rawValue
    @Environment(\.dependencies) private var dependencies

    private var colorScheme: ColorScheme? {
        switch AppTheme(rawValue: themeRawValue) ?? .system {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: router.path(for: tab)) {
                    // Reserve the tab bar's real, measured height as a bottom
                    // safe-area inset so every screen's scrollable content ends above
                    // the bar instead of being clipped behind it, with no per-screen
                    // padding workarounds. This must be applied inside the
                    // NavigationStack: a NavigationStack does not forward a
                    // safe-area inset applied to it (or to an ancestor) down to the
                    // content it hosts.
                    content(for: tab)
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            Color.clear.frame(height: tabBarHeight)
                        }
                }
                .opacity(router.selectedTab == tab ? 1 : 0)
                .allowsHitTesting(router.selectedTab == tab)
                .accessibilityHidden(router.selectedTab != tab)
            }

            if router.isFABVisible(for: router.selectedTab) && !router.isDetailPresented(for: router.selectedTab) {
                FloatingActionButton {
                    switch router.selectedTab {
                    case .projects:
                        isPresentingNewProject = true
                    default:
                        isPresentingTaskCreation = true
                    }
                }
                .padding(.bottom, tabBarHeight + MosaicSpacing.md)
            }

            FrostedTabBar(selectedTab: $router.selectedTab, inboxCount: inboxCount)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    tabBarHeight = height
                }
        }
        .environment(\.tabRouter, router)
        .preferredColorScheme(colorScheme)
        .animation(.easeInOut(duration: 0.18), value: router.selectedTab)
        .sheet(isPresented: $isPresentingTaskCreation) {
            TaskCreationSheet(viewModel: dependencies.makeTaskCreationViewModel(capturesToInbox: router.selectedTab == .inbox))
        }
        .sheet(isPresented: $isPresentingNewProject) {
            NewProjectSheet(viewModel: dependencies.makeNewProjectViewModel())
        }
        .task {
            refreshInboxCount()
            await dependencies.reregisterLocationReminders()
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskDataDidChange)) { _ in
            refreshInboxCount()
        }
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            TodayView(viewModel: dependencies.makeTodayViewModel())
        case .inbox:
            InboxView(viewModel: dependencies.makeInboxViewModel())
        case .projects:
            ProjectsView(viewModel: dependencies.makeProjectsViewModel())
        case .search:
            SearchView(viewModel: dependencies.makeSearchViewModel())
        case .settings:
            SettingsView(viewModel: dependencies.makeSettingsViewModel())
        }
    }

    private func refreshInboxCount() {
        inboxCount = (try? dependencies.taskRepository.fetchInbox().count) ?? 0
    }
}
