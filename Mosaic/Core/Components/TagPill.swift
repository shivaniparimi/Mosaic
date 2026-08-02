import SwiftUI

struct TagPill: View {
    let name: String

    var body: some View {
        Text("#\(name)")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(MosaicColor.tagPurple)
            .padding(.horizontal, MosaicSpacing.sm)
            .padding(.vertical, MosaicSpacing.xs)
            .background(MosaicColor.tagPurple.opacity(0.12))
            .clipShape(Capsule())
    }
}
