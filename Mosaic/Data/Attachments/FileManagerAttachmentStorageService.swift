import Foundation

final class FileManagerAttachmentStorageService: AttachmentStorageService {
    private let fileManager: FileManager
    private let attachmentsDirectory: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.attachmentsDirectory = documentsDirectory.appendingPathComponent("Attachments", isDirectory: true)
    }

    func store(data: Data, suggestedFilename: String) throws -> StoredFile {
        if !fileManager.fileExists(atPath: attachmentsDirectory.path) {
            try fileManager.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
        }
        let diskFilename = "\(UUID().uuidString)-\(suggestedFilename)"
        let url = attachmentsDirectory.appendingPathComponent(diskFilename)
        try data.write(to: url)
        return StoredFile(localURL: url, filename: suggestedFilename, fileSizeBytes: data.count)
    }

    func delete(at url: URL) {
        try? fileManager.removeItem(at: url)
    }

    func resolvedURL(for storedURL: URL) -> URL {
        attachmentsDirectory.appendingPathComponent(storedURL.lastPathComponent)
    }
}
