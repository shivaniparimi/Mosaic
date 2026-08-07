import SwiftUI

struct EventDetailView: View {
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpacing.md) {
            Text(event.title)
                .font(.system(size: 22, weight: .bold))

            Label(Self.timeRangeLabel(for: event), systemImage: "clock")
                .foregroundStyle(.secondary)

            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(MosaicSpacing.lg)
        .presentationDetents([.medium])
    }

    static func timeRangeLabel(for event: CalendarEvent) -> String {
        if event.isAllDay { return "All-day" }
        return "\(timeFormatter.string(from: event.startDate)) – \(timeFormatter.string(from: event.endDate))"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
