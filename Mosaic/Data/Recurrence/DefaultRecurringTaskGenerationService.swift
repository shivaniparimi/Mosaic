import Foundation

@MainActor
final class DefaultRecurringTaskGenerationService: RecurringTaskGenerationService {
    private let taskRepository: TaskRepository
    private let windowLengthDays = 56
    private let topUpThresholdDays = 14

    init(taskRepository: TaskRepository) {
        self.taskRepository = taskRepository
    }

    func generateInitialOccurrences(for template: RecurringTaskTemplate) throws {
        try generateOccurrences(for: template, from: Calendar.current.startOfDay(for: .now), days: windowLengthDays)
    }

    func topUpIfNeeded(_ templates: [RecurringTaskTemplate]) throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        for template in templates where template.isActive {
            guard let furthestDate = template.occurrences.compactMap(\.dueDate).max() else {
                try generateOccurrences(for: template, from: today, days: windowLengthDays)
                continue
            }

            let daysRemaining = calendar.dateComponents([.day], from: today, to: furthestDate).day ?? 0
            if daysRemaining < topUpThresholdDays {
                let nextDay = calendar.date(byAdding: .day, value: 1, to: furthestDate) ?? today
                // Clamp to today: after a long absence the furthest occurrence can
                // be months in the past, and an unclamped window would generate a
                // whole 56-day block of already-dead rows.
                let startDate = max(nextDay, today)
                try generateOccurrences(for: template, from: startDate, days: windowLengthDays)
            }
        }
    }

    private func generateOccurrences(for template: RecurringTaskTemplate, from startDate: Date, days: Int) throws {
        let calendar = Calendar.current
        var currentDate = startDate
        var occurrences: [TaskItem] = []

        for _ in 0..<days {
            let weekday = calendar.component(.weekday, from: currentDate)
            if template.weekdays.contains(weekday) {
                let dueTime = template.startHour.flatMap { hour in
                    calendar.date(bySettingHour: hour, minute: template.startMinute ?? 0, second: 0, of: currentDate)
                }
                let timeOfDay: TimeOfDay = template.startHour.map { $0 < 12 ? .morning : .afternoon } ?? .anytime

                occurrences.append(TaskItem(
                    title: template.title,
                    dueDate: currentDate,
                    dueTime: dueTime,
                    timeOfDay: timeOfDay,
                    recurringTemplate: template
                ))
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        // One save, one `.taskDataDidChange` post — not ~25 of each, which would
        // trigger a full Today reload cascade per generated occurrence.
        if !occurrences.isEmpty {
            try taskRepository.createMany(occurrences)
        }
    }
}
