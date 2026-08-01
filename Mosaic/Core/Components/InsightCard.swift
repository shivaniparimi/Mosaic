import SwiftUI

struct InsightCard: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: MosaicSpacing.sm) {
            Image(systemName: "sparkles")
                .foregroundStyle(MosaicColor.accent)

            VStack(alignment: .leading, spacing: MosaicSpacing.xs) {
                Text("MOSAIC")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(MosaicColor.accent)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
            }
        }
        .padding(MosaicSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [MosaicColor.accent.opacity(0.12), MosaicColor.accent.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
