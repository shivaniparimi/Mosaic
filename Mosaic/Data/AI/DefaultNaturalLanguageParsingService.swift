import Foundation

struct DefaultNaturalLanguageParsingService: NaturalLanguageParsingService {
    private static let weekdayNames = [
        "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"
    ]
    private static let weekdayAbbreviations = [
        "sun", "mon", "tue", "wed", "thu", "fri", "sat"
    ]
    private static let monthNames = [
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december"
    ]
    private static let monthAbbreviations = [
        "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"
    ]

    func parse(_ text: String) -> ParsedTaskDraft {
        var draft = ParsedTaskDraft()
        draft.date = Self.detectDate(in: text)
        draft.recurringWeekdays = Self.detectRecurringWeekdays(in: text)
        if let timeRange = Self.detectTimeRange(in: text) {
            draft.timeRangeComponents = timeRange
        } else {
            draft.timeComponents = Self.detectTime(in: text)
        }
        draft.tagName = Self.detectTag(in: text)
        draft.hasReminder = Self.containsWord(text.lowercased(), phrase: "remind me")
        draft.cleanedTitle = Self.buildCleanedTitle(from: text, draft: draft)
        return draft
    }

    private static func buildCleanedTitle(from text: String, draft: ParsedTaskDraft) -> String {
        var cleaned = text

        if draft.hasReminder {
            cleaned = cleaned.replacingOccurrences(
                of: #"\bremind me\b"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        if draft.tagName != nil {
            cleaned = cleaned.replacingOccurrences(of: #"#\w+"#, with: "", options: .regularExpression)
        }
        if draft.timeRangeComponents != nil {
            cleaned = cleaned.replacingOccurrences(
                of: #"\b(?:at\s+)?(1[0-2]|0?[1-9])(:([0-5][0-9]))?\s*([AaPp][Mm])?\s*-\s*(1[0-2]|0?[1-9])(:([0-5][0-9]))?\s*([AaPp][Mm])\b"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        } else if draft.timeComponents != nil {
            // The optional leading "at " is folded into the time pattern so the
            // preposition is only dropped when it actually introduces a detected
            // time ("meet at 2 PM"), never in ordinary prose ("buy milk at Target").
            cleaned = cleaned.replacingOccurrences(
                of: #"\b(?:at\s+)?(1[0-2]|0?[1-9])(:([0-5][0-9]))?\s*([AaPp][Mm])\b"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        if let recurringWeekdays = draft.recurringWeekdays, recurringWeekdays.count >= 2 {
            for keyword in weekdayNames + weekdayAbbreviations {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
                cleaned = cleaned.replacingOccurrences(
                    of: pattern,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
            }
        } else if draft.date != nil {
            let dateKeywords = ["today", "tomorrow", "next week", "this weekend"] + weekdayNames
            for keyword in dateKeywords {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
                cleaned = cleaned.replacingOccurrences(
                    of: pattern,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
            }
            cleaned = Self.stripExplicitDate(from: cleaned)
        }
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : cleaned
    }

    private static func detectDate(in text: String) -> Date? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        if let explicitDate = detectExplicitMonthDay(in: text) {
            return explicitDate
        }
        if containsWord(lowercased, phrase: "today") {
            return today
        }
        if containsWord(lowercased, phrase: "tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: today)
        }
        if containsWord(lowercased, phrase: "next week") {
            return calendar.date(byAdding: .day, value: 7, to: today)
        }
        if containsWord(lowercased, phrase: "this weekend") {
            return nextOccurrence(ofWeekday: 7, from: today, calendar: calendar)
        }
        for (index, weekday) in weekdayNames.enumerated() {
            if containsWord(lowercased, phrase: weekday) {
                return nextOccurrence(ofWeekday: index + 1, from: today, calendar: calendar)
            }
        }
        return nil
    }

    private static let monthAlternation = (monthNames + monthAbbreviations).joined(separator: "|")

    private static func detectExplicitMonthDay(in text: String) -> Date? {
        guard let (month, day) = explicitMonthDayComponents(in: text) else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let thisYear = calendar.component(.year, from: today)
        guard let candidate = calendar.date(from: DateComponents(year: thisYear, month: month, day: day)) else {
            return nil
        }
        if calendar.startOfDay(for: candidate) < today {
            return calendar.date(from: DateComponents(year: thisYear + 1, month: month, day: day))
        }
        return candidate
    }

    private static func explicitMonthDayComponents(in text: String) -> (month: Int, day: Int)? {
        let pattern = "\\b(\(monthAlternation))\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let monthRange = Range(match.range(at: 1), in: text),
              let dayRange = Range(match.range(at: 2), in: text),
              let day = Int(text[dayRange]) else { return nil }

        let monthWord = text[monthRange].lowercased()
        if let index = monthNames.firstIndex(of: monthWord) {
            return (index + 1, day)
        }
        if let index = monthAbbreviations.firstIndex(of: monthWord) {
            return (index + 1, day)
        }
        return nil
    }

    private static func stripExplicitDate(from text: String) -> String {
        let pattern = "\\b(?:on\\s+)?(?:\(monthAlternation))\\s+\\d{1,2}(?:st|nd|rd|th)?\\b"
        return text.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
    }

    private static func detectRecurringWeekdays(in text: String) -> Set<Int>? {
        let lowercased = text.lowercased()
        var found: Set<Int> = []

        for (index, name) in weekdayNames.enumerated() where containsWord(lowercased, phrase: name) {
            found.insert(index + 1)
        }
        for (index, abbreviation) in weekdayAbbreviations.enumerated() {
            let weekdayValue = index + 1
            if !found.contains(weekdayValue) && containsWord(lowercased, phrase: abbreviation) {
                found.insert(weekdayValue)
            }
        }

        return found.count >= 2 ? found : nil
    }

    private static func nextOccurrence(ofWeekday targetWeekday: Int, from date: Date, calendar: Calendar) -> Date? {
        let currentWeekday = calendar.component(.weekday, from: date)
        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd < 0 {
            daysToAdd += 7
        }
        return calendar.date(byAdding: .day, value: daysToAdd, to: date)
    }

    private static func detectTime(in text: String) -> ParsedTimeComponents? {
        let pattern = #"\b(1[0-2]|0?[1-9])(:([0-5][0-9]))?\s*([AaPp][Mm])\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        guard let hourRange = Range(match.range(at: 1), in: text),
              var hour = Int(text[hourRange]) else { return nil }

        var minute = 0
        if let minuteRange = Range(match.range(at: 3), in: text) {
            minute = Int(text[minuteRange]) ?? 0
        }

        guard let meridiemRange = Range(match.range(at: 4), in: text) else { return nil }
        let meridiem = text[meridiemRange].lowercased()

        if meridiem == "pm" && hour != 12 {
            hour += 12
        } else if meridiem == "am" && hour == 12 {
            hour = 0
        }

        return ParsedTimeComponents(hour: hour, minute: minute)
    }

    private static func detectTimeRange(in text: String) -> ParsedTimeRange? {
        let pattern = #"\b(1[0-2]|0?[1-9])(:([0-5][0-9]))?\s*([AaPp][Mm])?\s*-\s*(1[0-2]|0?[1-9])(:([0-5][0-9]))?\s*([AaPp][Mm])\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        guard let startHourRange = Range(match.range(at: 1), in: text),
              let startHourValue = Int(text[startHourRange]) else { return nil }
        var startMinute = 0
        if let startMinuteRange = Range(match.range(at: 3), in: text) {
            startMinute = Int(text[startMinuteRange]) ?? 0
        }

        guard let endHourRange = Range(match.range(at: 5), in: text),
              let endHourValue = Int(text[endHourRange]) else { return nil }
        var endMinute = 0
        if let endMinuteRange = Range(match.range(at: 7), in: text) {
            endMinute = Int(text[endMinuteRange]) ?? 0
        }

        guard let endMeridiemRange = Range(match.range(at: 8), in: text) else { return nil }
        let endMeridiem = text[endMeridiemRange].lowercased()

        let startMeridiem: String
        if let startMeridiemRange = Range(match.range(at: 4), in: text) {
            startMeridiem = text[startMeridiemRange].lowercased()
        } else {
            startMeridiem = endMeridiem
        }

        return ParsedTimeRange(
            start: ParsedTimeComponents(hour: Self.resolvedHour(startHourValue, meridiem: startMeridiem), minute: startMinute),
            end: ParsedTimeComponents(hour: Self.resolvedHour(endHourValue, meridiem: endMeridiem), minute: endMinute)
        )
    }

    private static func resolvedHour(_ hour: Int, meridiem: String) -> Int {
        if meridiem == "pm" && hour != 12 {
            return hour + 12
        } else if meridiem == "am" && hour == 12 {
            return 0
        }
        return hour
    }

    private static func detectTag(in text: String) -> String? {
        guard let range = text.range(of: #"#(\w+)"#, options: .regularExpression) else { return nil }
        return String(text[range].dropFirst())
    }

    private static func containsWord(_ text: String, phrase: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: phrase))\\b"
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}
