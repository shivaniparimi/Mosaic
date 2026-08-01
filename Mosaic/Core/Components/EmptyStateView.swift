import SwiftUI

struct EmptyStateView: View {
    let iconSystemName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: MosaicSpacing.md) {
            Image(systemName: iconSystemName)
                .font(.system(size: 40))
                .foregroundStyle(MosaicColor.accent.opacity(0.5))
            Text(title)
                .font(.system(size: 18, weight: .semibold))
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(MosaicSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
