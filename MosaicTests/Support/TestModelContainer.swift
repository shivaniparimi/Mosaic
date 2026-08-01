import SwiftData
@testable import Mosaic

enum TestModelContainer {
    @MainActor
    static func makeInMemory() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: schema,
            migrationPlan: MosaicMigrationPlan.self,
            configurations: configuration
        )
    }
}
