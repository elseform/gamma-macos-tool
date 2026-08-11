import SwiftUI

struct WrapperNamePage: View {
    @ObservedObject var model: AppModel
    let recommendedDisabled: Bool
    let advancedDisabled: Bool
    let recommendedAction: () -> Void
    let advancedAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WizardCard {
                VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                    CardHeading(title: "Application name")
                    TextField("stalker-gamma", text: $model.appName)
                        .textFieldStyle(.roundedBorder)
                    if !model.wrapperNameValidationMessage.isEmpty {
                        Text(model.wrapperNameValidationMessage)
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    Text(model.outputAppPath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
            .frame(width: Layout.environmentPanelWidth, alignment: .leading)

            WizardCard(
                horizontalPadding: Layout.environmentPanelHorizontalPadding,
                verticalPadding: Layout.environmentPanelVerticalPadding
            ) {
                    modOrganizerRow()
            }
            .frame(width: Layout.environmentPanelWidth, alignment: .topLeading)

            WizardCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("You can configure the wrapper later using the \"Configure\" application.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button {
                            recommendedAction()
                        } label: {
                            Label("Recommended", systemImage: "checkmark.circle")
                        }
                        .controlSize(.large)
                        .disabled(recommendedDisabled || advancedDisabled)
                        .help("GPTK4 D3DMetal with source-verified X-Ray dependencies.")

                        Button {
                            advancedAction()
                        } label: {
                            Label("Advanced", systemImage: "slider.horizontal.3")
                        }
                        .controlSize(.large)
                        .disabled(advancedDisabled)
                    }

                    if recommendedDisabled && !advancedDisabled {
                        Text("Drive mapping is not valid, fix using Advanced settings.")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(width: Layout.environmentPanelWidth, alignment: .topLeading)
        }
        .frame(width: Layout.environmentPanelWidth, alignment: .leading)
    }

    private func modOrganizerRow() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CheckRow(
                label: model.selectedLaunchExecutableLabel,
                status: "",
                ok: model.selectedModOrganizerExecutableFound,
                warning: true,
                detail: model.selectedLaunchExecutablePath
            ) {
                Button {
                    model.chooseLaunchExecutable()
                } label: {
                    Label("Choose…", systemImage: "folder")
                }
            }

            HStack(spacing: 8) {
                Text("Flags")
                    .frame(width: 44, alignment: .leading)
                TextField("Optional launch flags", text: $model.launchArguments)
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.programBatch == "/mo2.bat")
            }
            .padding(.bottom, 8)
        }
    }
}

