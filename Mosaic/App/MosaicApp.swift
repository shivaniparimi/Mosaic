import SwiftUI

@main
struct MosaicApp: App {
    @State private var dependencies = AppDependencyContainer.live()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.dependencies, dependencies)
        }
    }
}
