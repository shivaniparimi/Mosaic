import SwiftData

enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            TaskItem.self,
            Project.self,
            Tag.self,
            Subtask.self,
            TaskAttachment.self,
            LocationReminder.self,
            RecurringTaskTemplate.self
        ]
    }
}
