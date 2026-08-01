enum Priority: Int, Codable, CaseIterable {
    case none, low, medium, high
}

enum TaskOrigin: String, Codable {
    case manual, quickCapture, aiExtracted, aiSuggested
}

enum TimeOfDay: String, Codable, CaseIterable {
    case morning, afternoon, anytime
}

enum AttachmentKind: String, Codable {
    case photo, pdf, file
}

enum LocationTrigger: String, Codable {
    case arriving, leaving
}
