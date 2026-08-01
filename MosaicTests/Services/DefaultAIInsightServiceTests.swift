import Testing
import Foundation
@testable import Mosaic

@MainActor
struct DefaultAIInsightServiceTests {
    @Test func returnsNilWhenNoIncompleteTasks() async {
        let service = DefaultAIInsightService()
        let task = TaskItem(title: "Done", isCompleted: true)

        let insight = await service.generateInsight(for: [task])

        #expect(insight == nil)
    }

    @Test func returnsNilForEmptyTaskList() async {
        let service = DefaultAIInsightService()

        let insight = await service.generateInsight(for: [])

        #expect(insight == nil)
    }

    @Test func includesRemainingCountAndNextTaskWithDueTime() async {
        let service = DefaultAIInsightService()
        let calendar = Calendar.current
        let earlyTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
        let lateTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: .now)!

        let earlyTask = TaskItem(title: "Team standup", dueTime: earlyTime)
        let lateTask = TaskItem(title: "Write report", dueTime: lateTime)

        let insight = await service.generateInsight(for: [earlyTask, lateTask])

        #expect(insight?.message == "2 tasks remaining. Team standup at 9:00 AM is your next priority.")
    }

    @Test func usesSingularTaskWordingForOneRemaining() async {
        let service = DefaultAIInsightService()
        let task = TaskItem(title: "Solo task")

        let insight = await service.generateInsight(for: [task])

        #expect(insight?.message == "1 task remaining.")
    }

    @Test func omitsNextTaskSentenceWhenNoTaskHasDueTime() async {
        let service = DefaultAIInsightService()
        let task = TaskItem(title: "No time set")

        let insight = await service.generateInsight(for: [task])

        #expect(insight?.message == "1 task remaining.")
    }
}
