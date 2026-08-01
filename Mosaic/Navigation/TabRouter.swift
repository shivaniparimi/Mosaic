import SwiftUI

@Observable
@MainActor
final class TabRouter {
    var selectedTab: AppTab = .today
    private var paths: [AppTab: NavigationPath] = Dictionary(
        uniqueKeysWithValues: AppTab.allCases.map { ($0, NavigationPath()) }
    )

    func path(for tab: AppTab) -> Binding<NavigationPath> {
        Binding(
            get: { self.paths[tab, default: NavigationPath()] },
            set: { self.paths[tab] = $0 }
        )
    }

    func isFABVisible(for tab: AppTab) -> Bool {
        switch tab {
        case .today, .inbox, .projects: true
        case .search, .settings: false
        }
    }
}
