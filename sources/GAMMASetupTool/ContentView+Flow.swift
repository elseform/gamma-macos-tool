import SwiftUI

struct WelcomePage: View {
    let createAction: () -> Void
    let updateAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WizardCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Placeholder welcome text. Replace this with a short explanation of what the setup tool will do.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button {
                            createAction()
                        } label: {
                            Label("Create new wrapper", systemImage: "plus.app")
                        }
                        .controlSize(.large)

                        Button {
                            updateAction()
                        } label: {
                            Label("Update or refresh wrapper", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .controlSize(.large)
                    }
                }
            }
            .frame(width: Layout.wizardContentWidth, alignment: .topLeading)
        }
        .frame(width: Layout.wizardContentWidth, alignment: .topLeading)
    }
}

struct WrapperNamePage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WizardCard {
                VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                    CardHeading(title: "Wrapper name")
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
            .frame(width: Layout.environmentPanelWidth, alignment: .topLeading)
        }
        .frame(width: Layout.environmentPanelWidth, alignment: .topLeading)
    }
}

struct ExistingWrapperPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WizardCard {
                VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                    CardHeading(title: "Existing wrapper")
                    Button {
                        model.chooseExistingWrapper()
                    } label: {
                        Label("Select wrapper", systemImage: "app")
                    }

                    if model.hasSelectedExistingWrapper {
                        Text(model.selectedExistingWrapperPath)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.green)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    } else {
                        Text("Select the Sikarugir .app wrapper you want to update or refresh.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(width: Layout.environmentPanelWidth, alignment: .topLeading)
        }
        .frame(width: Layout.environmentPanelWidth, alignment: .topLeading)
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
                    Text("Placeholder install choice text. Replace this with the final explanation of default and advanced setup.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button {
                            defaultAction()
                        } label: {
                            Label("Default installation", systemImage: "checkmark.circle")
                        }
                        .controlSize(.large)
                        .disabled(defaultDisabled)

                        Button {
                            advancedAction()
                        } label: {
                            Label("Advanced installation", systemImage: "slider.horizontal.3")
                        }
                        .controlSize(.large)
                    }

                    if defaultDisabled {
                        Text("Default installation is unavailable until drive mapping is ready. Use Advanced installation to review drive mapping.")
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
