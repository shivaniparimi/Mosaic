import SwiftUI

struct TagPill: View {
    let name: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: MosaicSpacing.xs) {
            Text("#\(name)")
                .font(.system(size: 13, weight: .medium))
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(MosaicColor.tagPurple)
        .padding(.horizontal, MosaicSpacing.sm)
        .padding(.vertical, MosaicSpacing.xs)
        .background(MosaicColor.tagPurple.opacity(0.12))
        .clipShape(Capsule())
    }
}
