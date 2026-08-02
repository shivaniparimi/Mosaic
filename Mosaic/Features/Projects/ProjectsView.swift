import SwiftUI

struct ProjectsView: View {
    @State private var viewModel: ProjectsViewModel

    init(viewModel: ProjectsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MosaicSpacing.lg) {
                if let insight = viewModel.insight {
                    InsightCard(message: insight.message)
                }

                if viewModel.projects.isEmpty {
                    EmptyStateView(
                        iconSystemName: "square.stack",
                        title: "No Projects Yet",
                        message: "Create a project to start organizing your tasks."
                    )
                    .padding(.top, MosaicSpacing.xl)
                } else {
                    VStack(spacing: MosaicSpacing.sm) {
                        ForEach(viewModel.projects) { project in
                            projectCard(for: project)
                        }
                    }
                }
            }
            .padding(MosaicSpacing.md)
        }
        .background(MosaicColor.canvas)
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("Projects")
                .font(.system(size: 34, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MosaicSpacing.md)
                .padding(.top, MosaicSpacing.md)
                .padding(.bottom, MosaicSpacing.sm)
                .background(MosaicColor.canvas.ignoresSafeArea(edges: .top))
        }
        .task {
            await viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
    }

    private func projectCard(for project: Project) -> some View {
        let progress = viewModel.progress(for: project)
        return ProjectCard(
            name: project.name,
            colorHex: project.colorHex,
            completed: progress.completed,
            total: progress.total,
            onDelete: {
                Task { await viewModel.delete(project) }
            }
        )
    }
}

#Preview {
    let container = AppDependencyContainer.preview()
    let websiteProject = Project(name: "Website Redesign", colorHex: "#4C6EF5")
    let mobileProject = Project(name: "Mobile App", colorHex: "#51CF66")
    try? container.projectRepository.create(websiteProject)
    try? container.projectRepository.create(mobileProject)
    try? container.taskRepository.create(TaskItem(title: "Wireframes", isCompleted: true, project: websiteProject))
    try? container.taskRepository.create(TaskItem(title: "Homepage copy", project: websiteProject))
    try? container.taskRepository.create(TaskItem(title: "App icon", project: mobileProject))

    return ProjectsView(viewModel: container.makeProjectsViewModel())
        .environment(\.dependencies, container)
}
