import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: MosaicSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MosaicSpacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
