import SwiftUI

struct SearchView: View {
    @State private var viewModel: SearchViewModel

    init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        let projectFilters = viewModel.availableProjectFilters

        ScrollView {
            VStack(alignment: .leading, spacing: MosaicSpacing.lg) {
                SearchField(text: $viewModel.query, onSubmit: {
                    viewModel.submitSearch()
                })
                .onChange(of: viewModel.query) { _, _ in
                    viewModel.scheduleSearch()
                }

                if !projectFilters.isEmpty {
                    filterChipRow(projectFilters: projectFilters)
                }

                content
            }
            .padding(MosaicSpacing.md)
        }
        .background(MosaicColor.canvas)
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("Search")
                .font(.system(size: 34, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MosaicSpacing.md)
                .padding(.top, MosaicSpacing.md)
                .padding(.bottom, MosaicSpacing.sm)
                .background(MosaicColor.canvas.ignoresSafeArea(edges: .top))
        }
    }

    private func filterChipRow(projectFilters: [Project]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MosaicSpacing.sm) {
                ForEach(projectFilters) { project in
                    ProjectFilterChip(
                        name: project.name,
                        colorHex: project.colorHex,
                        isSelected: viewModel.selectedProjectFilter?.id == project.id,
                        onTap: {
                            Task {
                                if viewModel.selectedProjectFilter?.id == project.id {
                                    await viewModel.clearProjectFilter()
                                } else {
                                    await viewModel.selectProjectFilter(project)
                                }
                            }
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let trimmedQuery = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedQuery.isEmpty {
            if viewModel.recentSearches.isEmpty {
                EmptyStateView(
                    iconSystemName: "magnifyingglass",
                    title: "Search Mosaic",
                    message: "Find tasks, projects, and tags."
                )
                .padding(.top, MosaicSpacing.xl)
            } else {
                recentSearchesSection
            }
        } else if viewModel.hasResults {
            groupedResults
        } else {
            EmptyStateView(
                iconSystemName: "magnifyingglass",
                title: "No Results",
                message: "Try a different search term."
            )
            .padding(.top, MosaicSpacing.xl)
        }
    }

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: MosaicSpacing.sm) {
            SectionHeader(title: "Recent Searches")
            ForEach(viewModel.recentSearches, id: \.self) { search in
                Button {
                    Task { await viewModel.selectRecentSearch(search) }
                } label: {
                    HStack(spacing: MosaicSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text(search)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.vertical, MosaicSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var groupedResults: some View {
        if !viewModel.taskResults.isEmpty {
            VStack(alignment: .leading, spacing: MosaicSpacing.sm) {
                SectionHeader(title: "Tasks")
                ForEach(viewModel.taskResults) { task in
                    TaskCard(
                        title: task.title,
                        isCompleted: task.isCompleted,
                        time: task.dueTime.map { Self.timeFormatter.string(from: $0) },
                        projectName: task.project?.name,
                        projectColor: task.project.map { Color(hex: $0.colorHex) },
                        hasReminder: task.hasReminder,
                        hasAttachments: !task.attachments.isEmpty,
                        onToggleCompletion: {}
                    )
                }
            }
        }

        if !viewModel.projectResults.isEmpty {
            VStack(alignment: .leading, spacing: MosaicSpacing.sm) {
                SectionHeader(title: "Projects")
                ForEach(viewModel.projectResults) { project in
                    HStack(spacing: MosaicSpacing.sm) {
                        Circle()
                            .fill(Color(hex: project.colorHex))
                            .frame(width: 10, height: 10)
                        Text(project.name)
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                    }
                    .padding(MosaicSpacing.md)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                }
            }
        }

        if !viewModel.tagResults.isEmpty {
            VStack(alignment: .leading, spacing: MosaicSpacing.sm) {
                SectionHeader(title: "Tags")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MosaicSpacing.sm) {
                        ForEach(viewModel.tagResults, id: \.name) { tag in
                            TagPill(name: tag.name)
                        }
                    }
                }
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

#Preview {
    let container = AppDependencyContainer.preview()
    let designProject = Project(name: "Design Sprint", colorHex: "#4C6EF5")
    try? container.projectRepository.create(designProject)
    try? container.projectRepository.create(Project(name: "Marketing Launch", colorHex: "#51CF66"))
    try? container.taskRepository.create(TaskItem(title: "Design review meeting", project: designProject))
    _ = try? container.tagRepository.findOrCreate(name: "design")

    return SearchView(viewModel: container.makeSearchViewModel())
        .environment(\.dependencies, container)
}
