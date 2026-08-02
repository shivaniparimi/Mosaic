import SwiftUI

struct ColorSwatchPicker: View {
    let selectedHex: String
    let onSelect: (String) -> Void

    static let palette: [String] = [
        "#E8738A", "#4C6EF5", "#51CF66", "#FFA94D",
        "#AF52DE", "#FF6B6B", "#20C997", "#FAB005"
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: MosaicSpacing.md) {
            ForEach(Self.palette, id: \.self) { hex in
                Button {
                    onSelect(hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: hex == selectedHex ? 3 : 0)
                                .padding(-4)
                        )
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: selectedHex)
            }
        }
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var selectedHex = ColorSwatchPicker.palette[0]

        var body: some View {
            ColorSwatchPicker(selectedHex: selectedHex) { selectedHex = $0 }
                .padding()
        }
    }

    return PreviewHost()
}
