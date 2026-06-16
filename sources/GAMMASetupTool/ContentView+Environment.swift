import SwiftUI

private enum InstallButtonRow {
    case sikarugir
    case winetricks
}

struct EnvironmentPage: View {
    @ObservedObject var model: AppModel

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let preflight = model.preflight {
                WizardCard(
                    horizontalPadding: Layout.environmentPanelHorizontalPadding,
                    verticalPadding: Layout.environmentPanelVerticalPadding
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        CheckRow(label: "Homebrew", status: preflight.homebrewFound ? "" : "Required", ok: preflight.homebrewFound)
                        Divider()
                        CheckRow(label: "Sikarugir", status: "", ok: sikarugirFound(preflight), warning: true) {
                            installAction(on: .sikarugir, preflight: preflight)
                        }
                        Divider()
                        CheckRow(label: "winetricks", status: "", ok: preflight.winetricksFound, warning: true) {
                            installAction(on: .winetricks, preflight: preflight)
                        }
                        Divider()
                        CheckRow(label: "GAMMA", status: "", ok: gammaInstallationFound(preflight), warning: true) {
                            if !gammaInstallationFound(preflight) {
                                Button {
                                    model.chooseGammaFolder()
                                } label: {
                                    Label("Select", systemImage: "folder")
                                }
                            }
                        }
                        if preflight.zRewriteRequired {
                            Divider()
                            CheckRow(label: "ModOrganizer drive repair", status: "Needed", ok: false, warning: true, detail: "Z: paths need repair before setup can continue.")
                        }
                    }
                }
                .frame(width: Layout.environmentPanelWidth, alignment: .topLeading)
                if shouldShowEnvironmentGate {
                    environmentGate
                }
                installDetailsLink
            } else if let gammaFolderSelectionError = model.gammaFolderSelectionError {
                WizardCard(
                    horizontalPadding: Layout.environmentPanelHorizontalPadding,
                    verticalPadding: Layout.environmentPanelVerticalPadding
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        CheckRow(
                            label: "GAMMA installation",
                            status: "",
                            ok: false,
                            detail: gammaFolderSelectionError
                        ) {
                            Button {
                                model.chooseGammaFolder()
                            } label: {
                                Label("Select", systemImage: "folder")
                            }
                        }
                    }
                }
                .frame(width: Layout.environmentPanelWidth, alignment: .topLeading)
            } else {
                Text(model.preflightError.isEmpty ? "Detecting setup state..." : model.preflightError)
                    .foregroundStyle(model.preflightError.isEmpty ? Color.secondary : Color.red)
                    .textSelection(.enabled)
            }
        }
        .frame(width: Layout.environmentPanelWidth, alignment: .topLeading)
    }

    // MARK: - Status Helpers

    private var installDetailsLink: some View {
        HStack(spacing: 4) {
            Text("Visit")
                .foregroundStyle(.secondary)
            Link(destination: URL(string: "https://github.com/FaithBeam/stalker-gamma-cli")!) {
                HStack(spacing: 4) {
                    BrandIcon(resourceName: "github", fallbackSystemName: "chevron.left.forwardslash.chevron.right")
                        .frame(width: 13, height: 13)
                    Text("stalker-gamma-cli")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .help("Visit stalker-gamma-cli on GitHub")
            Text("for installation details.")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.leading, 2)
    }

    private func sikarugirFound(_ preflight: Preflight) -> Bool {
        preflight.sikarugirInstalled
    }

    private func gammaInstallationFound(_ preflight: Preflight) -> Bool {
        preflight.gammaFound && preflight.mo2Found && preflight.modOrganizerIniFound
    }

    // MARK: - Install Actions

    private func shouldShowInstallButton(on row: InstallButtonRow, preflight: Preflight) -> Bool {
        guard model.canInstallComponents else {
            return false
        }
        let sikarugirMissing = !sikarugirFound(preflight)
        switch row {
        case .sikarugir:
            return sikarugirMissing
        case .winetricks:
            return !sikarugirMissing && !preflight.winetricksFound
        }
    }

    @ViewBuilder
    private func installAction(on row: InstallButtonRow, preflight: Preflight) -> some View {
        if model.isInstallingComponents && isMissingInstallableComponent(row, preflight: preflight) {
            installSpinner
        } else if shouldShowInstallButton(on: row, preflight: preflight) {
            installComponentsButton
        }
    }

    private func isMissingInstallableComponent(_ row: InstallButtonRow, preflight: Preflight) -> Bool {
        switch row {
        case .sikarugir:
            return !sikarugirFound(preflight)
        case .winetricks:
            return !preflight.winetricksFound
        }
    }

    private var installSpinner: some View {
        ProgressView()
            .controlSize(.small)
            .frame(width: 20, height: 20)
    }

    private var installComponentsButton: some View {
        Group {
            if model.isInstallingComponents {
                EmptyView()
            } else {
                Button {
                    Task { await model.installComponents() }
                } label: {
                    Label("Install", systemImage: "arrow.down.circle")
                }
            }
        }
    }

    // MARK: - Environment Gate

    private var environmentGate: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if !environmentGateMessage.isEmpty {
                    Text(environmentGateMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                if model.canInstallComponents {
                    Button {
                        Task { await model.installComponents() }
                    } label: {
                        Label("Install", systemImage: "arrow.down.circle")
                    }
                    .frame(minWidth: 96, alignment: .trailing)
                    .padding(.trailing, 10)
                    .disabled(model.isRunning)
                }
            }

            if model.saveVerboseLog && (model.isInstallingComponents || (!model.logText.isEmpty && (model.statusText == "Install failed" || model.statusText == "Rechecking environment"))) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(model.statusText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(model.statusText == "Install failed" ? .red : .secondary)
                        Spacer()
                        Text("\(Int(model.progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: model.progress)
                    DisclosureGroup("Output", isExpanded: $model.showOutput) {
                        TextEditor(text: $model.logText)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 130)
                            .border(Color(nsColor: .separatorColor))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var shouldShowEnvironmentGate: Bool {
        !model.requiredToolsOK || model.isInstallingComponents || model.statusText == "Install failed"
    }

    private var environmentGateMessage: String {
        if model.requiredToolsOK || model.isInstallingComponents || model.canInstallComponents {
            return ""
        }
        return model.environmentMessage
    }
}
