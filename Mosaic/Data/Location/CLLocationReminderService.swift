import Foundation
@preconcurrency import CoreLocation

@MainActor
final class CLLocationReminderService: NSObject, LocationReminderService {
    private static let regionRadius: CLLocationDistance = 150

    private let manager: CLLocationManager
    private let taskRepository: TaskRepository
    private let notificationService: NotificationService
    // Not `private`: exposed at `internal` visibility so tests (via
    // `@testable import`) can observe how many callers are currently
    // waiting on authorization, to deterministically synchronize a
    // re-entrancy test without a real CLLocationManager prompt.
    private(set) var authorizationContinuations: [CheckedContinuation<Bool, Never>] = []

    init(manager: CLLocationManager = CLLocationManager(), taskRepository: TaskRepository, notificationService: NotificationService) {
        self.manager = manager
        self.taskRepository = taskRepository
        self.notificationService = notificationService
        super.init()
        manager.delegate = self
    }

    func requestAuthorization() async -> Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            return true
        case .denied, .restricted:
            return false
        default:
            break
        }

        manager.requestAlwaysAuthorization()

        // Bridges CLLocationManager's delegate-based authorization flow into
        // async/await — there is no native async variant of
        // requestAlwaysAuthorization(). Resumed from
        // locationManagerDidChangeAuthorization below.
        //
        // Known limitation: if the user already declined the "upgrade to
        // Always" prompt once before, iOS silently does not re-prompt on
        // subsequent calls and authorizationStatus never changes — the
        // delegate callback that would resume this continuation never
        // fires. This leaves the continuation pending until the next
        // successful/failed authorization flow resumes it. Documented and
        // accepted rather than adding a timeout, since a timeout risks a
        // worse failure mode: reporting "denied" while the system dialog is
        // still legitimately on screen for a slow-to-respond user.
        //
        // Re-entrancy: if requestAuthorization() is called again while a
        // prior call is still pending (both see .notDetermined), each call
        // appends its own continuation here rather than overwriting a
        // single stored one — otherwise the first caller's continuation
        // would be silently orphaned and its await would hang forever.
        // locationManagerDidChangeAuthorization resumes every pending
        // continuation once the status resolves.
        return await withCheckedContinuation { continuation in
            authorizationContinuations.append(continuation)
        }
    }

    func startMonitoring(for reminder: LocationReminderInfo) async {
        let center = CLLocationCoordinate2D(latitude: reminder.latitude, longitude: reminder.longitude)
        let region = CLCircularRegion(center: center, radius: Self.regionRadius, identifier: reminder.reminderID.uuidString)
        region.notifyOnEntry = reminder.trigger == .arriving
        region.notifyOnExit = reminder.trigger == .leaving
        manager.startMonitoring(for: region)
    }

    func stopMonitoring(id: UUID) async {
        let identifier = id.uuidString
        guard let region = manager.monitoredRegions.first(where: { $0.identifier == identifier }) else { return }
        manager.stopMonitoring(for: region)
    }

    func reregisterAll(reminders: [LocationReminderInfo]) async {
        for reminder in reminders {
            await startMonitoring(for: reminder)
        }
    }

    static func findTask(withLocationReminderID id: UUID, in tasks: [TaskItem]) -> TaskItem? {
        tasks.first { $0.locationReminder?.id == id }
    }

    private func handleRegionCrossing(region: CLRegion, trigger: LocationTrigger) async {
        guard let reminderID = UUID(uuidString: region.identifier) else { return }
        let tasks = (try? taskRepository.fetchAll()) ?? []
        guard let match = Self.findTask(withLocationReminderID: reminderID, in: tasks) else {
            // The task (and its LocationReminder, cascade-deleted with it)
            // is gone but the region registration lingered — clean it up.
            await stopMonitoring(id: reminderID)
            return
        }
        let placeName = match.locationReminder?.name ?? "your location"
        let title = trigger == .arriving ? "Arrived: \(placeName)" : "Left: \(placeName)"
        await notificationService.postLocationAlert(identifier: reminderID.uuidString, title: title, body: match.title)
    }
}

extension CLLocationReminderService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard !self.authorizationContinuations.isEmpty else { return }
            let status = self.manager.authorizationStatus
            guard status != .notDetermined else { return }
            let continuations = self.authorizationContinuations
            self.authorizationContinuations = []
            for continuation in continuations {
                continuation.resume(returning: status == .authorizedAlways)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            await self.handleRegionCrossing(region: region, trigger: .arriving)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            await self.handleRegionCrossing(region: region, trigger: .leaving)
        }
    }
}
