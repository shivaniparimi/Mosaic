import Testing
import Foundation
@preconcurrency import CoreLocation
@testable import Mosaic

@MainActor
struct LocationReminderServiceTests {
    @Test func findTaskReturnsTheTaskOwningThatLocationReminderID() {
        let reminder = LocationReminder(name: "Home", address: "123 Main St", latitude: 37.0, longitude: -122.0, trigger: .arriving)
        let task = TaskItem(title: "Water plants")
        task.locationReminder = reminder
        let otherTask = TaskItem(title: "No reminder")

        let found = CLLocationReminderService.findTask(withLocationReminderID: reminder.id, in: [otherTask, task])

        #expect(found?.title == "Water plants")
    }

    @Test func findTaskReturnsNilWhenNoTaskOwnsThatID() {
        let task = TaskItem(title: "No reminder")

        let found = CLLocationReminderService.findTask(withLocationReminderID: UUID(), in: [task])

        #expect(found == nil)
    }

    // Regression test for a re-entrancy bug found in code review of commit
    // f2aa762: calling requestAuthorization() a second time while a first
    // call's continuation was still pending (both see .notDetermined) used
    // to silently overwrite the single stored continuation, permanently
    // orphaning the first caller's await. The fix tracks pending
    // continuations in an array and resumes all of them together once
    // authorization resolves. Bounded with a time limit so that if this
    // ever regresses, the test fails instead of hanging the suite forever
    // (the exact failure mode this bug produced in production).
    @Test(.timeLimit(.minutes(1)))
    func requestAuthorizationResumesAllPendingCallersWhenCalledReentrantly() async {
        let fakeManager = FakeCLLocationManager()
        let service = CLLocationReminderService(
            manager: fakeManager,
            taskRepository: NoOpTaskRepository(),
            notificationService: NoOpNotificationService()
        )

        async let firstResult = service.requestAuthorization()
        async let secondResult = service.requestAuthorization()

        // Wait until both concurrent calls have reached
        // withCheckedContinuation and registered themselves, so the
        // authorization resolution below is guaranteed to race against both
        // rather than only whichever call happened to run first.
        while service.authorizationContinuations.count < 2 {
            await Task.yield()
        }

        fakeManager.stubbedAuthorizationStatus = .authorizedAlways
        service.locationManagerDidChangeAuthorization(fakeManager)

        let (first, second) = await (firstResult, secondResult)
        #expect(first == true)
        #expect(second == true)
    }
}

/// A CLLocationManager subclass that stubs out authorizationStatus and
/// suppresses the real system permission prompt, so the re-entrancy test
/// above can drive the delegate callback deterministically without a real
/// device/simulator authorization flow (which cannot be scripted from a
/// unit test).
private final class FakeCLLocationManager: CLLocationManager, @unchecked Sendable {
    var stubbedAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    override var authorizationStatus: CLAuthorizationStatus {
        stubbedAuthorizationStatus
    }

    override func requestAlwaysAuthorization() {
        // No-op: avoids triggering a real system permission dialog in tests.
    }
}

private final class NoOpTaskRepository: TaskRepository {
    func fetchAll() throws -> [TaskItem] { [] }
    func fetchInbox() throws -> [TaskItem] { [] }
    func create(_ task: TaskItem) throws {}
    func createMany(_ tasks: [TaskItem]) throws {}
    func update(_ task: TaskItem) throws {}
    func delete(_ task: TaskItem) throws {}
    func toggleCompletion(_ task: TaskItem) throws {}
    func search(query: String) throws -> [TaskItem] { [] }
    func addSubtask(_ subtask: Subtask, to task: TaskItem) throws {}
    func toggleSubtaskCompletion(_ subtask: Subtask) throws {}
    func deleteSubtask(_ subtask: Subtask) throws {}
    func addAttachment(_ attachment: TaskAttachment, to task: TaskItem) throws {}
    func deleteAttachment(_ attachment: TaskAttachment) throws {}
}

private final class NoOpNotificationService: NotificationService {
    func requestAuthorization() async -> Bool { true }
    func scheduleReminder(for reminder: TaskReminderInfo) async {}
    func cancelReminder(id: UUID) async {}
    func cancelAllReminders() async {}
    func postLocationAlert(identifier: String, title: String, body: String) async {}
}
