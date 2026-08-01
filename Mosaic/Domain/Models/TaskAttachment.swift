import Foundation
import SwiftData

@Model
final class TaskAttachment {
    @Attribute(.unique) var id: UUID
    var kind: AttachmentKind
    var filename: String
    var fileSizeBytes: Int
    var localURL: URL
    var createdAt: Date
    var task: TaskItem?

    init(
        id: UUID = UUID(),
        kind: AttachmentKind,
        filename: String,
        fileSizeBytes: Int,
        localURL: URL,
        createdAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.fileSizeBytes = fileSizeBytes
        self.localURL = localURL
        self.createdAt = createdAt
        self.task = nil
    }
}
