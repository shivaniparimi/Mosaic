enum AppTab: String, CaseIterable, Identifiable {
    case today, inbox, projects, search, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .inbox: "Inbox"
        case .projects: "Projects"
        case .search: "Search"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max.fill"
        case .inbox: "tray.fill"
        case .projects: "square.stack.fill"
        case .search: "magnifyingglass"
        case .settings: "gearshape.fill"
        }
    }
}
