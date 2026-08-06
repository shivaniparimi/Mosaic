import SwiftUI

struct SegmentedPillControl<Option: Hashable & Identifiable>: View {
    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: MosaicSpacing.xs) {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, MosaicSpacing.sm)
                        .padding(.vertical, MosaicSpacing.xs)
                        .frame(maxWidth: .infinity)
                        .background(selection == option ? MosaicColor.accent : Color.clear)
                        .foregroundStyle(selection == option ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
    }
}
