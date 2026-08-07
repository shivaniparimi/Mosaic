import SwiftUI

struct CalendarPickerView: View {
    @State private var viewModel: CalendarPickerViewModel

    init(viewModel: CalendarPickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List(viewModel.calendars) { calendar in
            Button {
                viewModel.toggleSelection(for: calendar)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: MosaicSpacing.xs) {
                        Text(calendar.title)
                            .foregroundStyle(.primary)
                        Text(calendar.sourceName)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if viewModel.isSelected(calendar) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(MosaicColor.accent)
                    }
                }
            }
        }
        .navigationTitle("Choose Calendars")
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        CalendarPickerView(viewModel: AppDependencyContainer.preview().makeCalendarPickerViewModel())
    }
}
