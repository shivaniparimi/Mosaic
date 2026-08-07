import SwiftUI

struct SearchView: View {
    @State private var viewModel: SearchViewModel
    @State private var selectedTask: TaskItem?
    @Environment(\.dependencies) private var dependencies
    @Environment(\.tabRouter) private var router

    init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MosaicSpacing.lg) {
                SearchField(text: $viewModel.query, onSubmit: {
                    viewModel.submitSearch()
                })
                .onChange(of: viewModel.query) { _, _ in
                    viewModel.scheduleSearch()
                }

                content
            }
            .padding(MosaicSpacing.md)
        }
        .background(MosaicColor.canvas)
        .navigationDestination(item: $selectedTask) { task in
            TaskDetailView(viewModel: dependencies.makeTaskDetailViewModel(task: task))
        }
        .onChange(of: selectedTask) { _, newValue in
            router.setDetailPresented(newValue != nil, for: .search)
        }
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

    @ViewBuilder
    private var content: some View {
        let trimmedQuery = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedQuery.isEmpty {
            if viewModel.recentSearches.isEmpty {
                EmptyStateView(
                    iconSystemName: "magnifyingglass",
                    title: "Search Mosaic",
                    message: "Find tasks and tags."
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
                        hasReminder: task.hasReminder,
                        hasAttachments: !task.attachments.isEmpty,
                        onTap: { selectedTask = task },
                        onToggleCompletion: {}
                    )
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
    try? container.taskRepository.create(TaskItem(title: "Design review meeting"))
    _ = try? container.tagRepository.findOrCreate(name: "design")

    return SearchView(viewModel: container.makeSearchViewModel())
        .environment(\.dependencies, container)
}
