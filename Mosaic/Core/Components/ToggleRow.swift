import SwiftUI

struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        IconRow(icon: icon, title: title) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(MosaicColor.accent)
        }
    }
}
