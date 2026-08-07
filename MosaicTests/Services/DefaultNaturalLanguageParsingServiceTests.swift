import Testing
import Foundation
@testable import Mosaic

struct DefaultNaturalLanguageParsingServiceTests {
    let service = DefaultNaturalLanguageParsingService()
    let calendar = Calendar.current

    @Test func detectsToday() {
        let draft = service.parse("finish report today")
        #expect(draft.date != nil)
        #expect(calendar.isDateInToday(draft.date!))
    }

    @Test func detectsTomorrow() {
        let draft = service.parse("email Haley tomorrow")
        let expected = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))
        #expect(draft.date == expected)
    }

    @Test func detectsNextWeek() {
        let draft = service.parse("plan trip next week")
        let expected = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: .now))
        #expect(draft.date == expected)
    }

    @Test func detectsThisWeekend() {
        let draft = service.parse("clean garage this weekend")
        #expect(draft.date != nil)
        #expect(calendar.component(.weekday, from: draft.date!) == 7)
    }

    @Test func detectsWeekdayName() {
        let draft = service.parse("buy groceries Saturday")
        #expect(draft.date != nil)
        #expect(calendar.component(.weekday, from: draft.date!) == 7)
    }

    @Test func detectsTimeWithMinutes() {
        let draft = service.parse("design review at 9:30 AM")
        #expect(draft.timeComponents == ParsedTimeComponents(hour: 9, minute: 30))
    }

    @Test func detectsTimeWithoutMinutes() {
        let draft = service.parse("email Haley tomorrow at 2 PM")
        #expect(draft.timeComponents == ParsedTimeComponents(hour: 14, minute: 0))
    }

    @Test func convertsTwelvePMCorrectly() {
        let draft = service.parse("lunch at 12 PM")
        #expect(draft.timeComponents == ParsedTimeComponents(hour: 12, minute: 0))
    }

    @Test func convertsTwelveAMCorrectly() {
        let draft = service.parse("midnight snack at 12 AM")
        #expect(draft.timeComponents == ParsedTimeComponents(hour: 0, minute: 0))
    }

    @Test func detectsTag() {
        let draft = service.parse("fix the bug #urgent")
        #expect(draft.tagName == "urgent")
    }

    @Test func detectsReminderPhrase() {
        let draft = service.parse("remind me call dentist")
        #expect(draft.hasReminder == true)
    }

    @Test func returnsEmptyDraftForPlainText() {
        let draft = service.parse("buy milk")
        #expect(draft.date == nil)
        #expect(draft.timeComponents == nil)
        #expect(draft.tagName == nil)
        #expect(draft.hasReminder == false)
    }

    @Test func doesNotFalsePositiveOnPartialWordMatch() {
        let draft = service.parse("todayish plans")
        #expect(draft.date == nil)
    }

    @Test func cleanedTitleStripsDetectedTokens() {
        let draft = service.parse("email Haley tomorrow at 2 PM")
        #expect(draft.cleanedTitle == "email Haley")
    }

    @Test func cleanedTitleStripsTagAndReminder() {
        let draft = service.parse("remind me design review tomorrow at 9:30 AM #urgent")
        #expect(draft.cleanedTitle == "design review")
    }

    @Test func cleanedTitleKeepsPrepositionNotIntroducingATime() {
        let draft = service.parse("buy milk at Target tomorrow")
        #expect(draft.cleanedTitle == "buy milk at Target")
    }

    @Test func cleanedTitleFallsBackToOriginalWhenNothingRemains() {
        let draft = service.parse("tomorrow")
        #expect(draft.cleanedTitle == "tomorrow")
    }

    @Test func cleanedTitlePreservesPlainTextWithNothingDetected() {
        let draft = service.parse("buy milk")
        #expect(draft.cleanedTitle == "buy milk")
    }

    @Test func cleanedTitleForShowcasePhrases() {
        #expect(service.parse("buy groceries Saturday").cleanedTitle == "buy groceries")
        #expect(service.parse("design review at 9 AM").cleanedTitle == "design review")
        #expect(service.parse("#urgent").cleanedTitle == "#urgent")
        #expect(service.parse("remind me call dentist").cleanedTitle == "call dentist")
    }

    @Test func singleWeekdayMentionDoesNotTriggerRecurringMode() {
        let draft = service.parse("dentist appointment monday")
        #expect(draft.recurringWeekdays == nil)
        #expect(draft.date != nil)
    }

    @Test func detectsRecurringWeekdaysFromAbbreviations() {
        let draft = service.parse("hot yoga mon wed fri")
        #expect(draft.recurringWeekdays == [2, 4, 6])
    }

    @Test func detectsRecurringWeekdaysFromFullNames() {
        let draft = service.parse("book club tuesday and thursday")
        #expect(draft.recurringWeekdays == [3, 5])
    }

    @Test func detectsTimeRangeWithTrailingMeridiemOnly() {
        let draft = service.parse("hot yoga 7-8pm mon wed fri")
        #expect(draft.timeRangeComponents == ParsedTimeRange(
            start: ParsedTimeComponents(hour: 19, minute: 0),
            end: ParsedTimeComponents(hour: 20, minute: 0)
        ))
    }

    @Test func detectsTimeRangeWithBothMeridiems() {
        let draft = service.parse("work 9am-5pm mon tue wed thu fri")
        #expect(draft.timeRangeComponents == ParsedTimeRange(
            start: ParsedTimeComponents(hour: 9, minute: 0),
            end: ParsedTimeComponents(hour: 17, minute: 0)
        ))
    }

    @Test func ambiguousTimeRangeWithNoMeridiemIsNotDetected() {
        let draft = service.parse("hot yoga 7-8 mon wed fri")
        #expect(draft.timeRangeComponents == nil)
        #expect(draft.timeComponents == nil)
    }

    @Test func cleanedTitleStripsRecurringWeekdaysAndTimeRange() {
        let draft = service.parse("hot yoga 7-8pm mon wed fri")
        #expect(draft.cleanedTitle == "hot yoga")
    }

    @Test func cleanedTitleStripsTimeRangeWithBothMeridiems() {
        let draft = service.parse("work 9am-5pm mon tue wed thu fri")
        #expect(draft.cleanedTitle == "work")
    }

    @Test func detectsExplicitDateWithAbbreviatedMonthAndOrdinal() {
        let draft = service.parse("cafe on aug 19th")
        #expect(draft.date == Self.expectedExplicitDate(month: 8, day: 19))
    }

    @Test func detectsExplicitDateWithFullMonthNameAndOrdinal() {
        let draft = service.parse("book flight on august 19th")
        #expect(draft.date == Self.expectedExplicitDate(month: 8, day: 19))
    }

    @Test func detectsExplicitDateWithoutOrdinalSuffix() {
        let draft = service.parse("trip on september 3")
        #expect(draft.date == Self.expectedExplicitDate(month: 9, day: 3))
    }

    @Test func detectsExplicitDateRollsToNextYearWhenAlreadyPassedThisYear() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))!
        let monthName = Self.monthFormatter.string(from: yesterday)
        let day = calendar.component(.day, from: yesterday)

        let draft = service.parse("do taxes \(monthName) \(day)")

        let detectedDate = try? #require(draft.date)
        #expect(calendar.component(.year, from: detectedDate ?? .distantPast) == calendar.component(.year, from: yesterday) + 1)
        #expect(calendar.component(.month, from: detectedDate ?? .distantPast) == calendar.component(.month, from: yesterday))
        #expect(calendar.component(.day, from: detectedDate ?? .distantPast) == day)
    }

    @Test func cleanedTitleStripsExplicitDateWithLeadingOn() {
        let draft = service.parse("cafe on aug 19th")
        #expect(draft.cleanedTitle == "cafe")
    }

    @Test func cleanedTitleStripsExplicitDateWithoutLeadingOn() {
        let draft = service.parse("call mom aug 19th")
        #expect(draft.cleanedTitle == "call mom")
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func expectedExplicitDate(month: Int, day: Int) -> Date {
        let calendar = Calendar.current
        let thisYear = calendar.component(.year, from: .now)
        let candidate = calendar.date(from: DateComponents(year: thisYear, month: month, day: day))!
        if calendar.startOfDay(for: candidate) < calendar.startOfDay(for: .now) {
            return calendar.date(from: DateComponents(year: thisYear + 1, month: month, day: day))!
        }
        return candidate
    }
}
