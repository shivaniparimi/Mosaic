import SwiftUI

struct ScheduleCard: View {
    @Bindable var task: TaskItem
    let onChange: () -> Void
    let onSetDueDate: (Date?) -> Void
    let onSetDueTime: (Date?) -> Void
    let onAddLocation: () -> Void
    let onClearLocation: () -> Void
    let onSetLocationTrigger: (LocationTrigger) -> Void

    var body: some View {
        GroupedCard {
            IconRow(icon: "calendar", title: "Due Date") {
                if let dueDate = task.dueDate {
                    HStack(spacing: MosaicSpacing.xs) {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { dueDate },
                                set: { onSetDueDate($0) }
                            ),
                            displayedComponents: .date
                        )
                        .labelsHidden()

                        Button {
                            onSetDueDate(nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Button("Set Date") {
                        onSetDueDate(.now)
                    }
                    .font(.system(size: 13))
                }
            }
            IconRow(icon: "clock", title: "Due Time") {
                if let dueTime = task.dueTime {
                    HStack(spacing: MosaicSpacing.xs) {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { dueTime },
                                set: { onSetDueTime($0) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()

                        Button {
                            onSetDueTime(nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Button("Set Time") {
                        onSetDueTime(.now)
                    }
                    .font(.system(size: 13))
                }
            }
            ToggleRow(
                icon: "bell",
                title: "Reminder",
                isOn: Binding(
                    get: { task.hasReminder },
                    set: { task.hasReminder = $0; onChange() }
                )
            )
            IconRow(icon: "location", title: "Location") {
                if let locationReminder = task.locationReminder {
                    VStack(alignment: .trailing, spacing: MosaicSpacing.xs) {
                        HStack(spacing: MosaicSpacing.xs) {
                            Text(locationReminder.name)
                                .font(.system(size: 13))
                            Button {
                                onClearLocation()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        SegmentedPillControl(
                            options: LocationTrigger.allCases,
                            label: { $0.label },
                            selection: Binding(
                                get: { locationReminder.trigger },
                                set: { onSetLocationTrigger($0) }
                            )
                        )
                    }
                } else {
                    Button("Add Location") {
                        onAddLocation()
                    }
                    .font(.system(size: 13))
                }
            }
        }
    }
}
