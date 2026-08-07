import SwiftUI

struct ReminderRow: View {
    let title: String
    let timeLabel: String?

    var body: some View {
        HStack(spacing: MosaicSpacing.md) {
            Image(systemName: "list.bullet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MosaicColor.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: MosaicSpacing.xs) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                if let timeLabel {
                    Text(timeLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(MosaicSpacing.md)
        .mosaicCard()
    }
}
