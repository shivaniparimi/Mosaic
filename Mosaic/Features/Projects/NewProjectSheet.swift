import SwiftUI

struct NewProjectSheet: View {
    @State private var viewModel: NewProjectViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    init(viewModel: NewProjectViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MosaicSpacing.lg) {
                TextField("Project name", text: $viewModel.name)
                    .font(.system(size: 19, weight: .medium))
                    .focused($isNameFocused)

                ColorSwatchPicker(selectedHex: viewModel.selectedColorHex, onSelect: viewModel.selectColor)

                Spacer()
            }
            .padding(MosaicSpacing.md)
            .background(MosaicColor.canvas)
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if viewModel.createProject() {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.canCreate)
                }
            }
            .onAppear {
                isNameFocused = true
            }
            .alert("Couldn't Create Project", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.clearError()
                    }
                }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

#Preview {
    let container = AppDependencyContainer.preview()
    return NewProjectSheet(viewModel: container.makeNewProjectViewModel())
        .environment(\.dependencies, container)
}
