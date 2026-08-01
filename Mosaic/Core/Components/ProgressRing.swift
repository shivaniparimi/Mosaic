import SwiftUI

struct ProgressRing: View {
    let completed: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(MosaicColor.accent.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(MosaicColor.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(completed)/\(total)")
                .font(.system(size: 11, weight: .semibold))
        }
        .frame(width: 44, height: 44)
    }
}
