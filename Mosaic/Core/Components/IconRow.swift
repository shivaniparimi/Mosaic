import SwiftUI

struct IconRow<Trailing: View>: View {
    let icon: String
    let title: String
    private let trailing: Trailing

    init(icon: String, title: String, @ViewBuilder trailing: () -> Trailing) {
        self.icon = icon
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: MosaicSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(MosaicColor.accent)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 15))
            Spacer()
            trailing
        }
        .padding(MosaicSpacing.md)
    }
}
