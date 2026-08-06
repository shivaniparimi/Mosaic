import SwiftUI

struct PriorityInlineSelector: View {
    @Binding var selection: Priority

    private static let priorities: [Priority] = [.none, .low, .medium, .high]

    private static func color(for priority: Priority) -> Color {
        switch priority {
        case .none: .secondary
        case .low: .blue
        case .medium: .orange
        case .high: MosaicColor.destructive
        }
    }

    var body: some View {
        HStack(spacing: MosaicSpacing.md) {
            ForEach(Self.priorities, id: \.self) { priority in
                Button {
                    selection = priority
                } label: {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(selection == priority ? Self.color(for: priority) : Color.secondary.opacity(0.25))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
