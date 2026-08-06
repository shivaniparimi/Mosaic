import SwiftUI

private struct MosaicCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(MosaicColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

extension View {
    func mosaicCard() -> some View {
        modifier(MosaicCardStyle())
    }
}
