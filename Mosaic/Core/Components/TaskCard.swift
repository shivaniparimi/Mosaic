import SwiftUI

struct TaskCard: View {
    let title: String
    let isCompleted: Bool
    var time: String? = nil
    var projectName: String? = nil
    var projectColor: Color? = nil
    var hasReminder: Bool = false
    var hasAttachments: Bool = false
    var isRecurring: Bool = false
    var onStopRepeating: (() -> Void)? = nil
    var onMoveToToday: (() -> Void)? = nil
    let onToggleCompletion: () -> Void

    var body: some View {
        HStack(spacing: MosaicSpacing.md) {
            Button(action: onToggleCompletion) {
                ZStack {
                    Circle()
                        .strokeBorder(isCompleted ? MosaicColor.accent : Color.secondary.opacity(0.3), lineWidth: 2)
                        .background(Circle().fill(isCompleted ? MosaicColor.accent : Color.clear))
                        .frame(width: 24, height: 24)
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: MosaicSpacing.xs) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? .secondary : .primary)

                HStack(spacing: MosaicSpacing.sm) {
                    if let time {
                        Label(time, systemImage: "clock")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    if let projectName {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(projectColor ?? MosaicColor.accent)
                                .frame(width: 6, height: 6)
                            Text(projectName)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if hasReminder {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if hasAttachments {
                        Image(systemName: "paperclip")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            if let onMoveToToday {
                Button(action: onMoveToToday) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MosaicColor.accent)
                        .padding(8)
                        .background(MosaicColor.accent.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Move to Today")
            }
        }
        .padding(MosaicSpacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .contextMenu {
            if isRecurring, let onStopRepeating {
                Button("Stop Repeating", role: .destructive) {
                    onStopRepeating()
                }
            }
        }
    }
}
