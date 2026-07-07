import SwiftUI

struct EnvironmentPage: View {
    @ObservedObject var model: AppModel

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WizardCard(
                horizontalPadding: Layout.environmentPanelHorizontalPadding,
                verticalPadding: Layout.environmentPanelVerticalPadding
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    modOrganizerRow(label: "GAMMA's ModOrganizer")
                }
            }
            .frame(width: Layout.environmentPanelWidth, alignment: .topLeading)
        }
        .frame(width: Layout.environmentPanelWidth, alignment: .topLeading)
    }

    // MARK: - Status Helpers

    private func modOrganizerRow(label: String) -> some View {
        CheckRow(
            label: label,
            status: "",
            ok: model.selectedModOrganizerExecutableFound,
            warning: true,
            detail: model.selectedModOrganizerDetail
        ) {
            Button {
                model.chooseModOrganizerFolder()
            } label: {
                Label(model.selectedModOrganizerExecutableFound ? "Change" : "Select", systemImage: "folder")
            }
        }
    }
}
