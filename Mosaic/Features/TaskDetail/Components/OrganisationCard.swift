import SwiftUI

struct OrganisationCard: View {
    @Bindable var task: TaskItem
    let availableProjects: [Project]
    let onSelectProject: (Project?) -> Void
    let onSelectPriority: (Priority) -> Void
    let onAddTag: (String) -> Void
    let onRemoveTag: (Tag) -> Void

    @State private var newTagText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpacing.sm) {
            GroupedCard {
                IconRow(icon: "folder", title: "Project") {
                    Menu(task.project?.name ?? "None") {
                        Button("None") { onSelectProject(nil) }
                        ForEach(availableProjects) { project in
                            Button(project.name) { onSelectProject(project) }
                        }
                    }
                    .font(.system(size: 13))
                }
                IconRow(icon: "flag", title: "Priority") {
                    PriorityInlineSelector(
                        selection: Binding(
                            get: { task.priority },
                            set: { onSelectPriority($0) }
                        )
                    )
                }
            }

            if !task.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MosaicSpacing.sm) {
                        ForEach(task.tags, id: \.name) { tag in
                            TagPill(name: tag.name, onRemove: { onRemoveTag(tag) })
                        }
                    }
                }
            }

            HStack(spacing: MosaicSpacing.sm) {
                TextField("Add a tag", text: $newTagText)
                    .font(.system(size: 14))
                    .onSubmit {
                        onAddTag(newTagText)
                        newTagText = ""
                    }
                Button("Add") {
                    onAddTag(newTagText)
                    newTagText = ""
                }
                .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(MosaicSpacing.md)
            .background(MosaicColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
