import SwiftUI

private struct AppDependencyContainerKey: EnvironmentKey {
    // `nonisolated(unsafe)` + `MainActor.assumeIsolated` is safe here because:
    // 1. EnvironmentKey protocol requires a nonisolated defaultValue property,
    //    but AppDependencyContainer is @MainActor-isolated
    // 2. Static let defaults are lazily initialized on first access (thread-safe)
    // 3. SwiftUI never reads environment defaults off the main actor, so the
    //    assumption that the first access is on the main actor is safe
    // This pattern should NOT be copied to contexts where off-main-actor access is possible.
    nonisolated(unsafe) static let defaultValue: AppDependencyContainer = {
        MainActor.assumeIsolated {
            .preview()
        }
    }()
}

extension EnvironmentValues {
    var dependencies: AppDependencyContainer {
        get { self[AppDependencyContainerKey.self] }
        set { self[AppDependencyContainerKey.self] = newValue }
    }
}
