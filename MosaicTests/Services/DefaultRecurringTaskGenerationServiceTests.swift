import Testing
import Foundation
@testable import Mosaic

@MainActor
struct DefaultRecurringTaskGenerationServiceTests {
    @Test func generateInitialOccurrencesCreatesOneTaskPerMatchingWeekdayInWindow() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let service = DefaultRecurringTaskGenerationService(taskRepository: taskRepository)

        let template = RecurringTaskTemplate(title: "Hot yoga", weekdays: [2, 4, 6], startHour: 19, startMinute: 0)

        try service.generateInitialOccurrences(for: template)

        let tasks = try taskRepository.fetchAll()
        #expect(!tasks.isEmpty)
        #expect(tasks.allSatisfy { $0.title == "Hot yoga" })
        #expect(tasks.allSatisfy { task in
            guard let dueDate = task.dueDate else { return false }
            let weekday = Calendar.current.component(.weekday, from: dueDate)
            return template.weekdays.contains(weekday)
        })
    }

    @Test func generateInitialOccurrencesSetsCorrectDueTimeAndTimeOfDay() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let service = DefaultRecurringTaskGenerationService(taskRepository: taskRepository)

        let template = RecurringTaskTemplate(title: "Hot yoga", weekdays: [2, 4, 6], startHour: 19, startMinute: 0)
        try service.generateInitialOccurrences(for: template)

        let tasks = try taskRepository.fetchAll()
        let first = try #require(tasks.first)
        let dueTime = try #require(first.dueTime)
        let dueDate = try #require(first.dueDate)
        #expect(Calendar.current.isDate(dueTime, inSameDayAs: dueDate))
        #expect(Calendar.current.component(.hour, from: dueTime) == 19)
        #expect(first.timeOfDay == .afternoon)
    }

    @Test func topUpDoesNothingWhenEnoughFutureOccurrencesRemain() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let service = DefaultRecurringTaskGenerationService(taskRepository: taskRepository)

        let template = RecurringTaskTemplate(title: "Hot yoga", weekdays: [2, 4, 6], startHour: 19, startMinute: 0)
        try service.generateInitialOccurrences(for: template)
        template.occurrences = try taskRepository.fetchAll()

        let countBefore = try taskRepository.fetchAll().count
        try service.topUpIfNeeded([template])
        let countAfter = try taskRepository.fetchAll().count

        #expect(countBefore == countAfter)
    }

    @Test func topUpGeneratesMoreWhenFewerThanTwoWeeksRemain() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let service = DefaultRecurringTaskGenerationService(taskRepository: taskRepository)

        let template = RecurringTaskTemplate(title: "Hot yoga", weekdays: [2, 4, 6], startHour: 19, startMinute: 0)
        let nearFutureDate = Calendar.current.date(byAdding: .day, value: 5, to: Calendar.current.startOfDay(for: .now))!
        let existingOccurrence = TaskItem(title: "Hot yoga", dueDate: nearFutureDate, recurringTemplate: template)
        try taskRepository.create(existingOccurrence)
        template.occurrences = [existingOccurrence]

        try service.topUpIfNeeded([template])

        let tasks = try taskRepository.fetchAll()
        #expect(tasks.count > 1)
    }

    @Test func generateOccurrencesLeavesDueTimeNilWhenTemplateHasNoStartTime() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let service = DefaultRecurringTaskGenerationService(taskRepository: taskRepository)

        let template = RecurringTaskTemplate(title: "Walk dog", weekdays: [2, 4, 6])
        try service.generateInitialOccurrences(for: template)

        let tasks = try taskRepository.fetchAll()
        let first = try #require(tasks.first)
        #expect(first.dueTime == nil)
        #expect(first.timeOfDay == .anytime)
    }

    @Test func topUpClampsGenerationStartToTodayForLongAbandonedTemplates() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let service = DefaultRecurringTaskGenerationService(taskRepository: taskRepository)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let template = RecurringTaskTemplate(title: "Hot yoga", weekdays: [2, 4, 6], startHour: 19, startMinute: 0)
        let staleDate = calendar.date(byAdding: .day, value: -100, to: today)!
        let staleOccurrence = TaskItem(title: "Hot yoga", dueDate: staleDate, recurringTemplate: template)
        try taskRepository.create(staleOccurrence)
        template.occurrences = [staleOccurrence]

        try service.topUpIfNeeded([template])

        let generated = try taskRepository.fetchAll().filter { $0 !== staleOccurrence }
        #expect(!generated.isEmpty)
        // Without the clamp these would all start at staleDate + 1 day and land
        // entirely in the past.
        #expect(generated.allSatisfy { ($0.dueDate ?? .distantPast) >= today })
    }

    @Test func topUpSkipsInactiveTemplates() throws {
        let container = TestModelContainer.makeInMemory()
        let taskRepository = SwiftDataTaskRepository(context: container.mainContext)
        let service = DefaultRecurringTaskGenerationService(taskRepository: taskRepository)

        let template = RecurringTaskTemplate(
            title: "Hot yoga",
            weekdays: [2, 4, 6],
            startHour: 19,
            startMinute: 0,
            isActive: false
        )
        let nearFutureDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
        let existingOccurrence = TaskItem(title: "Hot yoga", dueDate: nearFutureDate, recurringTemplate: template)
        try taskRepository.create(existingOccurrence)
        template.occurrences = [existingOccurrence]

        try service.topUpIfNeeded([template])

        let tasks = try taskRepository.fetchAll()
        #expect(tasks.count == 1)
    }
}
