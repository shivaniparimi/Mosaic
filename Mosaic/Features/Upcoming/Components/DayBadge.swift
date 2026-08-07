import SwiftUI

struct DayBadge: View {
    let dayOfWeek: String
    let dayNumber: String
    let month: String
    let isToday: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(dayOfWeek)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(dayNumber)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(isToday ? MosaicColor.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isToday ? Color.clear : Color.secondary.opacity(0.25), lineWidth: 1)
                )
            Text(month)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 48)
    }
}

#Preview {
    HStack(spacing: 16) {
        DayBadge(dayOfWeek: "WED", dayNumber: "5", month: "AUG", isToday: true)
        DayBadge(dayOfWeek: "THU", dayNumber: "6", month: "AUG", isToday: false)
    }
    .padding()
}
