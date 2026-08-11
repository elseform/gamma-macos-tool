import SwiftUI

struct WelcomePage: View {
    let createAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WizardCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Full GAMMA installation required. Enter an app name and locate ModOrganizer.exe.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        createAction()
                    } label: {
                        Label("Create wrapper", systemImage: "plus.app")
                    }
                    .controlSize(.large)
                }
            }
            .frame(width: Layout.wizardContentWidth, alignment: .leading)
        }
        .frame(width: Layout.wizardContentWidth, alignment: .leading)
    }
}

struct WrapperNamePage: View {
    @ObservedObject var model: AppModel

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
        }
        .frame(width: Layout.environmentPanelWidth, alignment: .leading)
    }
}

struct InstallChoicePage: View {
    var defaultDisabled = false
    let defaultAction: () -> Void
    let advancedAction: () -> Void
    let xrayD3DMetalAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WizardCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("You can configure the wrapper later using the \"Configure\" application.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button {
                            defaultAction()
                        } label: {
                            Label("Recommended", systemImage: "checkmark.circle")
                        }
                        .controlSize(.large)
                        .disabled(defaultDisabled)

                        Button {
                            advancedAction()
                        } label: {
                            Label("Advanced", systemImage: "slider.horizontal.3")
                        }
                        .controlSize(.large)

                        Button {
                            xrayD3DMetalAction()
                        } label: {
                            Label("X-Ray D3DMetal", systemImage: "testtube.2")
                        }
                        .controlSize(.large)
                        .help("Open Advanced settings with GPTK4 D3DMetal and source-verified X-Ray dependencies.")
                    }

                    if defaultDisabled {
                        Text("Drive mapping is not valid, fix using Advanced settings.")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(width: Layout.environmentPanelWidth, alignment: .topLeading)
        }
        .frame(width: Layout.environmentPanelWidth, alignment: .topLeading)
    }
}
