import SwiftUI

struct WelcomePage: View {
    let createAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WizardCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose an app name, locate ModOrganizer.exe, and use the recommended settings or review the advanced options.")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WizardCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Use the recommended settings, or review the Wine engine, renderer, display, and launch options using the advanced settings.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button {
                            defaultAction()
                        } label: {
                            Label("Use recommended settings", systemImage: "checkmark.circle")
                        }
                        .controlSize(.large)
                        .disabled(defaultDisabled)

                        Button {
                            advancedAction()
                        } label: {
                            Label("Review advanced settings", systemImage: "slider.horizontal.3")
                        }
                        .controlSize(.large)
                    }

                    if defaultDisabled {
                        Text("Recommended setup is unavailable until the drive mapping is valid. Review the advanced settings to correct it.")
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
