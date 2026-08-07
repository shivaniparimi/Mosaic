import SwiftUI

struct EventRow: View {
    let title: String
    let timeLabel: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MosaicSpacing.md) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MosaicColor.accent)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: MosaicSpacing.xs) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(timeLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(MosaicSpacing.md)
            .mosaicCard()
        }
        .buttonStyle(.plain)
    }
}
