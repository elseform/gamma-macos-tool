import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var model = AppModel()
    @State private var step: WizardStep = .environment
    @State private var environmentCompleted = false
    @State private var furthestUnlockedStep = WizardStep.setup

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    currentStepView
                }
                .frame(maxWidth: 1180, alignment: .topLeading)
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            Divider()
            footer
        }
        .frame(minWidth: 920, minHeight: 660)
        .task { await model.refreshPreflight() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(headerTitle)
                        .font(.title2.weight(.semibold))
                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if step == .environment {
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
                        .font(.subheadline)
                    }
                }
                Spacer()
                if model.statusText == "Wrapper created" {
                    Label("Wrapper created", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if environmentCompleted {
                HStack(spacing: 8) {
                    ForEach(visibleSteps) { item in
                        Button {
                            step = item
                        } label: {
                            Label(item.title, systemImage: item.icon)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(step == item ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canNavigate(to: item))
                        .opacity(canNavigate(to: item) ? 1 : 0.45)
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var headerTitle: String {
        switch step {
        case .environment:
            return "Check environment"
        case .setup:
            return "Configure wrapper"
        case .create:
            return "Create GAMMA wrapper"
        case .complete:
            return "Wrapper created"
        }
    }

    private var headerSubtitle: String {
        switch step {
        case .environment:
            return "Verify required tools and detected GAMMA paths before continuing."
        case .setup:
            return "Set the app location, renderer, Wine prefix options, and optional fixes."
        case .create:
            return "Review the selected options and start wrapper creation."
        case .complete:
            return "Launch the wrapper or start another setup."
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case .environment:
            environmentStep
        case .setup:
            setupStep
        case .create:
            createStep
        case .complete:
            completeStep
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("v0.6")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if step != .environment && step != .setup && step != .complete {
                Button("Back") {
                    if let previous = previousStep {
                        step = previous
                    }
                }
                .disabled(previousStep == nil || model.isRunning)
            }

            Spacer()

            Text("Source:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link(destination: URL(string: "https://github.com/elseform/gamma-macos-tool")!) {
                BrandIcon(resourceName: "github", fallbackSystemName: "chevron.left.forwardslash.chevron.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("GitHub repository")
            Text("Support thread:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link(destination: URL(string: "https://discord.com/channels/912320241713958912/1315449108797980762")!) {
                BrandIcon(resourceName: "discord", fallbackSystemName: "bubble.left.and.bubble.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Discord thread")

            Spacer()

            if step == .complete {
                Button {
                    model.resetForNewWrapper()
                    furthestUnlockedStep = .setup
                    step = .setup
                } label: {
                    Label("Create New Wrapper", systemImage: "plus.circle")
                }
            } else if step == .create {
                Button {
                    Task {
                        if await model.create() {
                            step = .complete
                        }
                    }
                } label: {
                    Label(model.primaryButtonTitle, systemImage: "play.circle")
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.isRunning || !model.environmentOK)
            } else {
                Button("Continue") {
                    if step == .environment, model.environmentOK {
                        environmentCompleted = true
                        furthestUnlockedStep = .setup
                        step = .setup
                    } else if let next = nextStep {
                        furthestUnlockedStep = next.rawValue > furthestUnlockedStep.rawValue ? next : furthestUnlockedStep
                        step = next
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!canContinue)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }

    private var visibleSteps: [WizardStep] {
        if environmentCompleted && step != .complete {
            return [.setup, .create]
        }
        return []
    }

    private var currentStepIndex: Int? {
        visibleSteps.firstIndex(of: step)
    }

    private var previousStep: WizardStep? {
        guard let index = currentStepIndex, index > 0 else { return nil }
        return visibleSteps[index - 1]
    }

    private var nextStep: WizardStep? {
        guard let index = currentStepIndex, index + 1 < visibleSteps.count else { return nil }
        return visibleSteps[index + 1]
    }

    private func canNavigate(to target: WizardStep) -> Bool {
        if target == .environment {
            return !environmentCompleted
        }
        guard environmentCompleted else { return false }
        if model.isRunning {
            return target == step || target.rawValue < step.rawValue
        }
        return model.environmentOK && target.rawValue <= furthestUnlockedStep.rawValue
    }

    private var canContinue: Bool {
        if model.isRunning {
            return false
        }
        if step == .environment {
            return model.environmentOK
        }
        return nextStep != nil
    }

    private var environmentStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                Button {
                    Task { await model.refreshPreflight() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh preflight")
            }

            if let preflight = model.preflight {
                HStack(alignment: .top, spacing: 18) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 0) {
                            CheckRow(
                                label: "stalker-gamma-cli",
                                status: preflight.stalkerGammaFound && preflight.settingsFound ? "Installed" : "Missing",
                                ok: preflight.stalkerGammaFound && preflight.settingsFound,
                                detail: preflight.settingsFound ? "Config: \(preflight.settingsFile)" : "Config missing"
                            )
                            Divider()
                            CheckRow(label: "Homebrew", status: preflight.homebrewFound ? "Installed" : "Required", ok: preflight.homebrewFound)
                            Divider()
                            CheckRow(label: "Sikarugir tap", status: preflight.sikarugirTapInstalled ? "Installed" : "Will install", ok: preflight.sikarugirTapInstalled, warning: true)
                            Divider()
                            CheckRow(label: "Sikarugir Creator", status: preflight.sikarugirInstalled ? "Installed" : "Will install", ok: preflight.sikarugirInstalled, warning: true)
                            Divider()
                            CheckRow(label: "winetricks", status: preflight.winetricksFound ? "Installed" : "Will install", ok: preflight.winetricksFound, warning: true)
                        }
                        .padding(.vertical, 1)
                    } label: {
                        Text("Tools")
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    GroupBox {
                        VStack(alignment: .leading, spacing: 0) {
                            CheckRow(label: "Anomaly", status: preflight.anomalyFound ? "Found" : "Missing", ok: preflight.anomalyFound, warning: true, detail: preflight.anomalyPath)
                            Divider()
                            CheckRow(label: "GAMMA", status: preflight.gammaFound ? "Found" : "Missing", ok: preflight.gammaFound, detail: preflight.gammaPath)
                            Divider()
                            CheckRow(
                                label: "ModOrganizer",
                                status: preflight.mo2Found && preflight.modOrganizerIniFound ? "Found" : "Missing",
                                ok: preflight.mo2Found && preflight.modOrganizerIniFound,
                                detail: "\(preflight.mo2Path)\n\(preflight.modOrganizerIni)"
                            )
                            if preflight.zRewriteRequired {
                                Divider()
                                CheckRow(label: "ModOrganizer drive repair", status: "Needed", ok: false, warning: true, detail: "Z: paths need repair before non-interactive setup.")
                            }
                        }
                        .padding(.vertical, 1)
                    } label: {
                        Text("Detected Installation")
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                environmentGate
            } else {
                Text(model.preflightError.isEmpty ? "Detecting setup state..." : model.preflightError)
                    .foregroundStyle(model.preflightError.isEmpty ? Color.secondary : Color.red)
                    .textSelection(.enabled)
            }
        }
    }

    private var environmentGate: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: model.environmentOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(model.environmentOK ? .green : .yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.environmentOK ? "Environment OK" : "Environment needs attention")
                            .font(.body.weight(.semibold))
                        Text(model.environmentOK ? "Continue to wrapper settings." : model.environmentMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if model.canInstallComponents {
                        Button {
                            Task { await model.installComponents() }
                        } label: {
                            Label("Install Components", systemImage: "arrow.down.circle")
                        }
                        .disabled(model.isRunning)
                    }
                }

                if model.isInstallingComponents || (!model.logText.isEmpty && (model.statusText == "Install failed" || model.statusText == "Rechecking environment")) {
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
                                .frame(height: 140)
                                .border(Color(nsColor: .separatorColor))
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var setupStep: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 9) {
                        GridRow {
                            Text("App name")
                            TextField("stalker-gamma", text: $model.appName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { Task { await model.refreshPreflight() } }
                        }
                        GridRow {
                            Text("Dir")
                            HStack {
                                TextField("~/Applications/Sikarugir", text: $model.installDirectory)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { Task { await model.refreshPreflight() } }
                                Button {
                                    model.chooseInstallDirectory()
                                } label: {
                                    Image(systemName: "folder")
                                }
                                .help("Choose install directory")
                            }
                        }
                        GridRow {
                            Text("App status")
                            Text(model.outputAppStatus)
                                .font(.caption)
                                .foregroundStyle(model.outputAppExists ? .yellow : .secondary)
                        }
                    }
                    .padding(.vertical, 2)
                } label: {
                    Text("Wrapper")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                            GridRow {
                                Text("Renderer")
                                Picker("Renderer", selection: $model.renderer) {
                                    Text("D3DMetal").tag("d3dmetal")
                                    Text("DXMT").tag("dxmt")
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                            }
                        }

                        Toggle("MoltenVK-CX", isOn: .constant(true))
                            .disabled(true)
                            .help("The original setup enables Sikarugir's MoltenVK-CX support and this tool keeps it locked on.")

                        Toggle("MoltenVK fast math", isOn: $model.moltenVKFastMath)
                        Toggle("Metal HUD", isOn: $model.metalHUD)
                    }
                    .padding(.vertical, 2)
                } label: {
                    Text("Renderer")
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 14) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                    Text("Winetricks")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 6)], alignment: .leading, spacing: 5) {
                        ForEach(model.requiredWinetricks, id: \.self) { verb in
                            Toggle(verb, isOn: .constant(true))
                                .disabled(true)
                        }
                    }
                    .font(.caption)

                    TextField("Additional winetricks verbs", text: $model.extraWinetricks)
                        .textFieldStyle(.roundedBorder)

                    if let preflight = model.preflight {
                        StatusRow(
                            label: "Planned Wine drive mapping",
                            value: "\(preflight.wineDriveLetter): -> \(preflight.wineDriveRoot)",
                            ok: true,
                            warning: true,
                            help: "This mapping will be created inside the wrapper so Windows paths used by ModOrganizer resolve to the detected macOS install location."
                        )
                        if preflight.zRewriteRequired {
                            StatusRow(label: "ModOrganizer drive repair", value: "Will rewrite reserved Z: paths before setup", ok: true, warning: true)
                        }
                    } else {
                        Text("Waiting for environment detection.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    }
                    .padding(.vertical, 2)
                } label: {
                    Text("Prefix")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                    if model.renderer == "dxmt" {
                        Toggle("MetalFX spatial upscaling", isOn: $model.dxmtMetalFXSpatial)
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                            GridRow {
                                Text("Max FPS")
                                TextField("Default", text: $model.dxmtMaxFrameRate)
                                    .textFieldStyle(.roundedBorder)
                            }
                            GridRow {
                                Text("Log level")
                                Picker("Log level", selection: $model.dxmtLogLevel) {
                                    Text("Default").tag("default")
                                    Text("None").tag("none")
                                    Text("Error").tag("error")
                                    Text("Warn").tag("warn")
                                    Text("Info").tag("info")
                                    Text("Debug").tag("debug")
                                }
                                .labelsHidden()
                            }
                        }
                    } else {
                        Text("DXMT options appear when DXMT is selected.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    }
                    .padding(.vertical, 2)
                } label: {
                    Text("DXMT Options")
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 14) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("D3DMetal DXMT reticle fix", isOn: $model.applyReticleFix)
                        if model.applyReticleFix {
                            Text("The mod will be copied into the GAMMA mods folder. Enable it in ModOrganizer after wrapper creation.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 2)
                } label: {
                    Text("Additional Fixes")
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .disabled(!model.environmentOK || model.isRunning)
        .opacity((model.environmentOK && !model.isRunning) ? 1 : 0.45)
    }

    private var createStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "Create", help: "Review the selected wrapper settings, then start creation.")

            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                    SummaryRow(label: "App", value: model.outputAppPath)
                    SummaryRow(label: "Mode", value: model.createModeLabel)
                    SummaryRow(label: "Renderer", value: model.renderer == "d3dmetal" ? "D3DMetal" : "DXMT")
                    SummaryRow(label: "MoltenVK fast math", value: model.moltenVKFastMath ? "Enabled" : "Disabled")
                    SummaryRow(label: "Metal HUD", value: model.metalHUD ? "Enabled" : "Disabled")
                    if model.renderer == "dxmt" {
                        SummaryRow(label: "DXMT MetalFX spatial", value: model.dxmtMetalFXSpatial ? "Enabled" : "Disabled")
                        SummaryRow(label: "DXMT max FPS", value: model.dxmtMaxFrameRate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Default" : model.dxmtMaxFrameRate)
                        SummaryRow(label: "DXMT log level", value: model.dxmtLogLevel == "default" ? "Default" : model.dxmtLogLevel)
                    }
                    SummaryRow(label: "Extra winetricks", value: model.extraWinetricks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "None" : model.extraWinetricks)
                    SummaryRow(label: "Fixes", value: model.applyReticleFix ? "D3DMetal DXMT reticle fix" : "None")
                }
                .font(.system(size: 15))
                .padding(.vertical, 4)
            } label: {
                Text("Summary")
            }

            runOptions
            runStatus
        }
    }

    private var completeStep: some View {
        GroupBox {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wrapper created")
                        .font(.headline)
                    Text(model.outputAppPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Spacer()
                Button {
                    model.openCreatedApp()
                } label: {
                    Label("Start Wrapper", systemImage: "play.circle")
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var runOptions: some View {
        GroupBox {
            HStack(spacing: 18) {
                Toggle("Save log", isOn: $model.writeLog)
                    .disabled(model.isRunning || !model.environmentOK)

                Toggle("Verbose install", isOn: $model.verboseInstall)
                    .disabled(model.isRunning || !model.environmentOK)

                Spacer()
            }
            .padding(.vertical, 4)
        } label: {
            Text("Install Output")
        }
    }

    private var runStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.statusText != "Ready" {
                Text(model.statusText)
                    .font(.headline)
                    .foregroundStyle(model.statusText == "Wrapper created" ? .green : .secondary)
            }

            if model.isRunning {
                ProgressView(value: model.progress)
            }

            if model.isRunning || !model.logText.isEmpty {
                DisclosureGroup("Output", isExpanded: $model.showOutput) {
                    TextEditor(text: $model.logText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 160)
                        .border(Color(nsColor: .separatorColor))
                }
            }
        }
    }
}
