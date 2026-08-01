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
        let draft = service.parse("design review at 9:30 AM @Design")
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

    @Test func detectsProjectMention() {
        let draft = service.parse("design review at 9 AM @Design")
        #expect(draft.projectName == "Design")
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
        #expect(draft.projectName == nil)
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

    @Test func cleanedTitleStripsProjectTagAndReminder() {
        let draft = service.parse("remind me design review tomorrow at 9:30 AM @Design #urgent")
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
        #expect(service.parse("design review at 9 AM @Design").cleanedTitle == "design review")
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
}
