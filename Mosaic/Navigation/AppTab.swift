enum AppTab: String, CaseIterable, Identifiable {
    case today, inbox, upcoming, search, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .inbox: "Inbox"
        case .upcoming: "Upcoming"
        case .search: "Search"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max.fill"
        case .inbox: "tray.fill"
        case .upcoming: "calendar"
        case .search: "magnifyingglass"
        case .settings: "gearshape.fill"
        }
    }
}
