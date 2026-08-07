import SwiftUI

@Observable
@MainActor
final class TabRouter {
    var selectedTab: AppTab = .today
    private var paths: [AppTab: NavigationPath] = Dictionary(
        uniqueKeysWithValues: AppTab.allCases.map { ($0, NavigationPath()) }
    )
    // `NavigationStack(path:)` does not write back into this binding when a push
    // originates from `.navigationDestination(item:)` (as Task Detail does on
    // Today/Inbox/Search) — only `.navigationDestination(for:)` pushes keep `paths`
    // in sync. Screens that push via an item binding report their presentation
    // state here explicitly instead, so FAB visibility has something accurate to read.
    private var detailPresented: [AppTab: Bool] = [:]

    func path(for tab: AppTab) -> Binding<NavigationPath> {
        Binding(
            get: { self.paths[tab, default: NavigationPath()] },
            set: { self.paths[tab] = $0 }
        )
    }

    func isFABVisible(for tab: AppTab) -> Bool {
        switch tab {
        case .today, .inbox, .upcoming: true
        case .search, .settings: false
        }
    }

    func isDetailPresented(for tab: AppTab) -> Bool {
        detailPresented[tab] ?? false
    }

    func setDetailPresented(_ isPresented: Bool, for tab: AppTab) {
        detailPresented[tab] = isPresented
    }
}
