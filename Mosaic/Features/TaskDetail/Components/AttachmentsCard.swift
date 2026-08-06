import SwiftUI
import PhotosUI
import QuickLook
import UniformTypeIdentifiers

struct AttachmentsCard: View {
    let attachments: [TaskAttachment]
    let onAddPhoto: (PhotosPickerItem) -> Void
    let onAddFile: (URL) -> Void
    let onDelete: (TaskAttachment) -> Void
    let resolveURL: (TaskAttachment) -> URL

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotosPicker = false
    @State private var showFileImporter = false
    @State private var previewURL: URL?

    var body: some View {
        GroupedCard {
            ForEach(attachments, id: \.id) { attachment in
                HStack(spacing: MosaicSpacing.sm) {
                    Button {
                        previewURL = resolveURL(attachment)
                    } label: {
                        HStack(spacing: MosaicSpacing.sm) {
                            Image(systemName: Self.icon(for: attachment.kind))
                                .foregroundStyle(MosaicColor.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(attachment.filename)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(Self.formattedSize(attachment.fileSizeBytes))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        onDelete(attachment)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(MosaicSpacing.md)
            }

            Menu {
                Button("Photo Library") { showPhotosPicker = true }
                Button("Browse Files") { showFileImporter = true }
            } label: {
                HStack(spacing: MosaicSpacing.sm) {
                    Image(systemName: "paperclip")
                        .foregroundStyle(MosaicColor.accent)
                        .frame(width: 24)
                    Text("Add Attachment")
                        .font(.system(size: 14))
                    Spacer()
                }
            }
            .padding(MosaicSpacing.md)
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            if let newValue {
                onAddPhoto(newValue)
                selectedPhotoItem = nil
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                onAddFile(url)
            }
        }
        .quickLookPreview($previewURL)
    }

    private static func icon(for kind: AttachmentKind) -> String {
        switch kind {
        case .photo: return "photo"
        case .pdf: return "doc.richtext"
        case .file: return "doc"
        }
    }

    private static func formattedSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

#Preview {
    AttachmentsCard(
        attachments: [
            TaskAttachment(kind: .photo, filename: "sunset.jpg", fileSizeBytes: 245_000, localURL: URL(fileURLWithPath: "/tmp/sunset.jpg")),
            TaskAttachment(kind: .pdf, filename: "itinerary.pdf", fileSizeBytes: 88_000, localURL: URL(fileURLWithPath: "/tmp/itinerary.pdf"))
        ],
        onAddPhoto: { _ in },
        onAddFile: { _ in },
        onDelete: { _ in },
        resolveURL: { $0.localURL }
    )
    .padding()
}
