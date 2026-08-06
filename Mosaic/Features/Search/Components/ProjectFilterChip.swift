import SwiftUI

struct ProjectFilterChip: View {
    let name: String
    let colorHex: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MosaicSpacing.xs) {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, MosaicSpacing.sm)
            .padding(.vertical, MosaicSpacing.xs)
            .background(isSelected ? Color(hex: colorHex).opacity(0.15) : MosaicColor.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    isSelected ? Color(hex: colorHex) : Color.secondary.opacity(0.2),
                    lineWidth: isSelected ? 1.5 : 1
                )
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
