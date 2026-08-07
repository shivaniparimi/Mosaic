import Foundation
@preconcurrency import EventKit

@MainActor
final class EventKitReminderSyncService: ReminderSyncService {
    private let store: EKEventStore

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    func requestAuthorization() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:
            return true
        case .denied, .restricted, .writeOnly:
            return false
        default:
            break
        }
        return (try? await store.requestFullAccessToReminders()) ?? false
    }

    func fetchReminders(from startDate: Date, to endDate: Date) async -> [ReminderItem] {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return [] }

        let store = self.store
        let calendar = Calendar.current
        // EKEventStore's reminder fetch is completion-handler based (unlike
        // the synchronous events(matching:) call for Calendar). `EKReminder`
        // itself isn't Sendable, so the mapping into the Sendable
        // `[ReminderItem]` result happens inside the completion handler,
        // before it ever needs to cross back to this MainActor-isolated
        // await point.
        return await withCheckedContinuation { continuation in
            let predicate = store.predicateForIncompleteReminders(withDueDateStarting: startDate, ending: endDate, calendars: nil)
            store.fetchReminders(matching: predicate) { reminders in
                let items = (reminders ?? []).compactMap { reminder -> ReminderItem? in
                    guard let components = reminder.dueDateComponents, let dueDate = calendar.date(from: components) else { return nil }
                    return ReminderItem(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "Untitled Reminder",
                        dueDate: dueDate,
                        hasTime: components.hour != nil
                    )
                }
                continuation.resume(returning: items)
            }
        }
    }
}
