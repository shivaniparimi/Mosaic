import Testing
import Foundation
@testable import Mosaic

struct FileManagerAttachmentStorageServiceTests {
    @Test @MainActor func storeWritesDataToDiskAndReturnsCorrectMetadata() throws {
        let service = FileManagerAttachmentStorageService()
        let data = Data("hello world".utf8)

        let stored = try service.store(data: data, suggestedFilename: "notes.txt")

        #expect(stored.filename == "notes.txt")
        #expect(stored.fileSizeBytes == data.count)
        #expect(FileManager.default.fileExists(atPath: stored.localURL.path))
        let writtenData = try Data(contentsOf: stored.localURL)
        #expect(writtenData == data)

        service.delete(at: stored.localURL)
    }

    @Test @MainActor func storeGivesEachFileAUniqueDiskLocationEvenWithTheSameSuggestedFilename() throws {
        let service = FileManagerAttachmentStorageService()
        let data = Data("content".utf8)

        let first = try service.store(data: data, suggestedFilename: "duplicate.txt")
        let second = try service.store(data: data, suggestedFilename: "duplicate.txt")

        #expect(first.localURL != second.localURL)
        #expect(FileManager.default.fileExists(atPath: first.localURL.path))
        #expect(FileManager.default.fileExists(atPath: second.localURL.path))

        service.delete(at: first.localURL)
        service.delete(at: second.localURL)
    }

    @Test @MainActor func deleteRemovesTheFileFromDisk() throws {
        let service = FileManagerAttachmentStorageService()
        let stored = try service.store(data: Data("temp".utf8), suggestedFilename: "temp.txt")
        #expect(FileManager.default.fileExists(atPath: stored.localURL.path))

        service.delete(at: stored.localURL)

        #expect(!FileManager.default.fileExists(atPath: stored.localURL.path))
    }

    @Test @MainActor func deleteOfAMissingFileDoesNotThrow() {
        let service = FileManagerAttachmentStorageService()
        let missingURL = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist.txt")

        service.delete(at: missingURL)
    }

    @Test @MainActor func resolvedURLReanchorsAStaleContainerPathOntoTheCurrentAttachmentsDirectory() throws {
        let service = FileManagerAttachmentStorageService()
        let stored = try service.store(data: Data("reanchor me".utf8), suggestedFilename: "photo.jpg")

        // Simulate the app having been reinstalled: the sandbox container UUID changed,
        // so a URL persisted from a previous launch now points at a directory that no
        // longer exists, even though the file itself still lives under the (new)
        // current Attachments directory with the same filename.
        let staleContainerAttachmentsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("old-container-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Attachments", isDirectory: true)
        let staleURL = staleContainerAttachmentsDirectory.appendingPathComponent(stored.localURL.lastPathComponent)

        #expect(staleURL != stored.localURL)
        #expect(!FileManager.default.fileExists(atPath: staleURL.path))

        let resolved = service.resolvedURL(for: staleURL)

        #expect(resolved == stored.localURL)
        #expect(FileManager.default.fileExists(atPath: resolved.path))
        let resolvedData = try Data(contentsOf: resolved)
        #expect(resolvedData == Data("reanchor me".utf8))

        service.delete(at: stored.localURL)
    }
}
