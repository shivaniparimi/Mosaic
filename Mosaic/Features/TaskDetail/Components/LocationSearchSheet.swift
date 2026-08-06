import SwiftUI
import MapKit

struct LocationSearchSheet: View {
    @State private var viewModel = LocationSearchViewModel()
    @State private var selectedTrigger: LocationTrigger
    @State private var isResolving = false
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ResolvedPlace, LocationTrigger) async -> Void

    init(trigger: LocationTrigger, onSelect: @escaping (ResolvedPlace, LocationTrigger) async -> Void) {
        _selectedTrigger = State(initialValue: trigger)
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchField(text: $viewModel.query, placeholder: "Search for a place")
                    .padding(MosaicSpacing.md)

                SegmentedPillControl(options: LocationTrigger.allCases, label: { $0.label }, selection: $selectedTrigger)
                    .padding(.horizontal, MosaicSpacing.md)
                    .padding(.bottom, MosaicSpacing.sm)

                if viewModel.results.isEmpty {
                    EmptyStateView(
                        iconSystemName: "mappin.and.ellipse",
                        title: "Search for a place",
                        message: "Find a location to get reminded when you arrive or leave."
                    )
                } else {
                    List(Array(viewModel.results.enumerated()), id: \.offset) { _, completion in
                        Button {
                            Task {
                                isResolving = true
                                if let place = await viewModel.resolve(completion) {
                                    await onSelect(place, selectedTrigger)
                                    dismiss()
                                }
                                isResolving = false
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: MosaicSpacing.xs) {
                                Text(completion.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(completion.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(MosaicColor.canvas)
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .disabled(isResolving)
        }
    }
}

#Preview {
    LocationSearchSheet(trigger: .arriving) { _, _ in }
}
