import Foundation

protocol NaturalLanguageParsingService {
    func parse(_ text: String) -> ParsedTaskDraft
}

struct ParsedTaskDraft: Equatable {
    var date: Date?
    var timeComponents: ParsedTimeComponents?
    var projectName: String?
    var tagName: String?
    var hasReminder: Bool = false
    var cleanedTitle: String?
    var recurringWeekdays: Set<Int>?
    var timeRangeComponents: ParsedTimeRange?
}

struct ParsedTimeComponents: Equatable {
    let hour: Int
    let minute: Int
}

struct ParsedTimeRange: Equatable {
    let start: ParsedTimeComponents
    let end: ParsedTimeComponents
}
