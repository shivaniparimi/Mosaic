import Foundation

struct StoredFile: Sendable {
    let localURL: URL
    let filename: String
    let fileSizeBytes: Int
}

@MainActor
protocol AttachmentStorageService {
    func store(data: Data, suggestedFilename: String) throws -> StoredFile
    func delete(at url: URL)
    /// Re-anchors a persisted attachment URL onto the current sandbox's Attachments
    /// directory. The app's container path can change between launches (e.g. after
    /// an app update or reinstall), which would make a stored absolute URL stale.
    /// Callers should always resolve a `TaskAttachment.localURL` through this method
    /// before using it to open, preview, or delete a file on disk.
    func resolvedURL(for storedURL: URL) -> URL
}
