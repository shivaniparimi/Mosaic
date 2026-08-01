import SwiftUI

struct ChipView: View {
    let icon: String
    let label: String
    let tintColor: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: MosaicSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(tintColor)
        .padding(.horizontal, MosaicSpacing.sm)
        .padding(.vertical, MosaicSpacing.xs)
        .background(tintColor.opacity(0.12))
        .clipShape(Capsule())
    }
}
