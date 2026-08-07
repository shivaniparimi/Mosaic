enum AppTheme: String, CaseIterable, Identifiable {
    case light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
