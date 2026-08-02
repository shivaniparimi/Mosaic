import SwiftUI

struct ProjectCard: View {
    let name: String
    let colorHex: String
    let completed: Int
    let total: Int
    let onDelete: () -> Void

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpacing.sm) {
            HStack(spacing: MosaicSpacing.sm) {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 10, height: 10)
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(completed)/\(total)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: colorHex).opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: colorHex))
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)
        }
        .padding(MosaicSpacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .contextMenu {
            Button("Delete Project", role: .destructive, action: onDelete)
        }
    }
}
