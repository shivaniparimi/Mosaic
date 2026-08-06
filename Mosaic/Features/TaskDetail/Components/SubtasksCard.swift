import SwiftUI

struct SubtasksCard: View {
    let subtasks: [Subtask]
    let onAdd: (String) -> Void
    let onToggle: (Subtask) -> Void
    let onDelete: (Subtask) -> Void

    @State private var newSubtaskTitle = ""

    var body: some View {
        GroupedCard {
            ForEach(subtasks, id: \.id) { subtask in
                HStack(spacing: MosaicSpacing.sm) {
                    Button {
                        onToggle(subtask)
                    } label: {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(subtask.isCompleted ? MosaicColor.accent : .secondary)
                    }
                    .buttonStyle(.plain)

                    Text(subtask.title)
                        .font(.system(size: 14))
                        .strikethrough(subtask.isCompleted)
                        .foregroundStyle(subtask.isCompleted ? .secondary : .primary)

                    Spacer()

                    Button {
                        onDelete(subtask)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(MosaicSpacing.md)
            }

            HStack(spacing: MosaicSpacing.sm) {
                TextField("Add a subtask", text: $newSubtaskTitle)
                    .font(.system(size: 14))
                    .onSubmit {
                        onAdd(newSubtaskTitle)
                        newSubtaskTitle = ""
                    }
                Button("Add") {
                    onAdd(newSubtaskTitle)
                    newSubtaskTitle = ""
                }
                .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(MosaicSpacing.md)
        }
    }
}
