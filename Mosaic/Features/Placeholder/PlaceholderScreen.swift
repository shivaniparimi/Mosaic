import SwiftUI

struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        VStack(spacing: MosaicSpacing.sm) {
            Text(title)
                .font(.largeTitle.bold())
            Text("Coming soon")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MosaicColor.canvas)
    }
}
