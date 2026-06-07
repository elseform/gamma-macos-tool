import SwiftUI

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct SetupPage: View {
    @ObservedObject var model: AppModel
    @Binding var showWinetricksList: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: Layout.setupColumnSpacing) {
                setupOptionsCard
                    .frame(width: Layout.setupLeftColumnWidth, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 12) {
                    rendererCard
                    rendererOptionsCard
                    modsCard
                }
                .frame(width: Layout.setupRightColumnWidth, alignment: .topLeading)
            }
            .frame(width: Layout.setupContentWidth, alignment: .topLeading)
        }
        .frame(width: Layout.setupContentWidth, alignment: .topLeading)
        .disabled(!model.environmentOK || model.isRunning)
        .opacity((model.environmentOK && !model.isRunning) ? 1 : 0.45)
    }

    var setupOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            appPanel
            prefixPanel
            winetricksCard
            displayCard
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    var appPanel: some View {
        WizardCard {
            VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                CardHeading(title: "App")

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Name")
                    TextField("stalker-gamma", text: $model.appName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await model.refreshPreflight() } }
                    Button {
                        model.chooseInstallDirectory()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Choose install directory")
                }

                if model.outputAppExists {
                    Text("Already created; will be updated")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    var prefixPanel: some View {
        WizardCard {
            VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                engineControls
                Divider()
                driveMappingControls
            }
        }
    }

    var engineControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Engine")
                Picker("Engine", selection: $model.engine) {
                    Text("Wine CX 24.0.7").tag(SetupConfiguration.defaultEngine)
                    Text("Wine Sikarugir 10.0").tag(SetupConfiguration.sikarugir10Engine)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
    }

    var updateUSVFSBinding: Binding<Bool> {
        Binding(
            get: {
                model.engine == SetupConfiguration.sikarugir10Engine || model.updateUSVFS
            },
            set: { value in
                model.updateUSVFS = value
            }
        )
    }

    var rendererCard: some View {
        WizardCard {
            VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                CardHeading(title: "Renderer")
                Picker("Translation layer", selection: $model.renderer) {
                    Text("D3DMetal")
                        .help(rendererHelp(for: "d3dmetal"))
                        .tag("d3dmetal")
                    Text("DXVK")
                        .help(rendererHelp(for: "dxvk"))
                        .tag("dxvk")
                    Text("DXMT")
                        .help(rendererHelp(for: "dxmt"))
                        .tag("dxmt")
                }
                .pickerStyle(.segmented)

                metalFXControls
                performanceHUDToggle
            }
        }
    }

    var rendererOptionsCard: some View {
        WizardCard {
            VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                CardHeading(title: "Runtime")
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("MoltenVK-CX", isOn: .constant(true))
                            .disabled(true)
                        Toggle("MoltenVK fast math", isOn: $model.moltenVKFastMath)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("ESync", isOn: $model.wineESync)
                        Toggle("MSync", isOn: $model.wineMSync)
                        Toggle("Mouse input compatibility", isOn: $model.enableHIDDevices)
                            .help("Use when mouse capture, aiming, or extra mouse buttons behave incorrectly. Enables Wine winebus HID/raw-input overrides; off restores Wine defaults.")
                    }
                }
            }
        }
    }

    var displayCard: some View {
        WizardCard {
            VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                CardHeading(title: "Display")

                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 7) {
                    GridRow {
                        Text("Resolution")
                        Picker("Resolution", selection: $model.displayMode) {
                            Text("Default Wine").tag("defaultWine")
                            Text("Forced").tag("forced")
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    if model.displayMode == "forced" {
                        GridRow {
                            Text("Value")
                            Picker("Value", selection: $model.displayResolutionMode) {
                                if let detectedResolutionLabel {
                                    Text(detectedResolutionLabel).tag("detected")
                                }
                                Text("1920 x 1080").tag("1920x1080")
                                Text("2560 x 1440").tag("2560x1440")
                                Text("3840 x 2160").tag("3840x2160")
                                Text("Custom").tag("custom")
                            }
                            .labelsHidden()
                        }

                        if model.displayResolutionMode == "custom" {
                            GridRow {
                                Text("Custom")
                                HStack(spacing: 6) {
                                    TextField("Width", text: $model.customDisplayResolutionWidth)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 72)
                                    Text("x")
                                        .foregroundStyle(.secondary)
                                    TextField("Height", text: $model.customDisplayResolutionHeight)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 72)
                                }
                            }
                        }
                    }
                }

                if let display = model.detectedDisplay {
                    Text("macOS: \(display.summary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let preflight = model.preflight, preflight.userLtxFound {
                    Text("Game config: \(gameResolutionText(preflight))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(preflight.userLtxPath)
                } else if model.preflight?.anomalyFound == true {
                    Text("Game resolution not detected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    func rendererHelp(for renderer: String) -> String {
        switch renderer {
        case "dxmt":
            return "Best performance. Can cause visual bugs if advanced features like MetalFX are enabled. Experimental."
        case "dxvk":
            return "Average performance. Most accurate if you use a lot of shader mods."
        default:
            return "Best first choice for compatibility."
        }
    }

    var detectedResolutionLabel: String? {
        guard let width = model.preflight?.gameResolutionWidth,
              let height = model.preflight?.gameResolutionHeight else {
            return nil
        }
        return "Use detected: \(width) x \(height)"
    }

    func gameResolutionText(_ preflight: Preflight) -> String {
        if let width = preflight.gameResolutionWidth,
           let height = preflight.gameResolutionHeight {
            return "\(width) x \(height)"
        }
        return "Not detected"
    }

    @ViewBuilder
    var driveMappingControls: some View {
        if let preflight = model.preflight {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
                if preflight.zShortenAvailable {
                    GridRow {
                        Text("Drive mapping")
                        Picker("Drive mapping", selection: $model.driveMappingMode) {
                            Text("Use ModOrganizer.ini").tag("preserve")
                            Text("Shorten mapping").tag("shorten")
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                }
                GridRow {
                    Text("Drive mapping")
                    Text(model.plannedWineDriveMapping)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            if model.willRewriteModOrganizerIni {
                Text("Paths in ModOrganizer.ini will be rewritten.")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .fixedSize(horizontal: false, vertical: true)
            } else if preflight.zRewriteRequired {
                Text(preflight.zShortenAvailable ? "Z: paths cannot be preserved; select Shorten mapping or update the ini manually." : "Z: paths need manual repair.")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var metalFXControls: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Toggle("MetalFX Spatial Upscale", isOn: $model.dxmtMetalFXSpatial)
                .disabled(!dxmtOptionsAvailable)
                .opacity(rendererOptionOpacity(dxmtOptionsAvailable))

            if model.dxmtMetalFXSpatial {
                metalFXFactorControls
            } else {
                metalFXFactorControls
                    .hidden()
            }
        }
    }

    var performanceHUDToggle: some View {
        Toggle("Performance HUD", isOn: $model.metalHUD)
            .help(model.renderer == "dxvk" ? "Enable DXVK HUD. The wrapper stores this through Sikarugir's METAL_HUD key." : "Enable Sikarugir's performance HUD.")
    }

    var metalFXFactorControls: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Scale factor")
                .font(.caption)
                .foregroundStyle(dxmtOptionsAvailable ? .secondary : .tertiary)
            TextField("2.0", text: $model.dxmtMetalFXScaleFactor)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .disabled(!dxmtOptionsAvailable)
                .opacity(rendererOptionOpacity(dxmtOptionsAvailable))
        }
    }

    var dxmtOptionsAvailable: Bool {
        model.renderer == "dxmt"
    }

    func rendererOptionOpacity(_ available: Bool) -> Double {
        available ? 1 : 0.45
    }

    var winetricksStatusIcon: String {
        switch model.winetricksWrapperState {
        case .installed:
            return "checkmark.circle.fill"
        case .needsUpdate:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .planned:
            return "arrow.down.circle.fill"
        }
    }

    var winetricksStatusText: String {
        switch model.winetricksWrapperState {
        case .installed:
            return "Present"
        case .needsUpdate:
            return "Verify"
        case .planned:
            return model.requiredWinetricksSummary
        }
    }

    var winetricksStatusColor: Color {
        SetupStatusTone.winetricks(model.winetricksWrapperState).color
    }

    var winetricksCard: some View {
        WizardCard(verticalPadding: Layout.winetricksPanelVerticalPadding) {
            winetricksCardContent
        }
    }

    var winetricksCardContent: some View {
        VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
            CardHeading(title: "Winetricks")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: winetricksStatusIcon)
                    .foregroundStyle(winetricksStatusColor)
                Text(winetricksStatusText)
                    .font(.caption)
                    .foregroundStyle(winetricksStatusColor)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()

                Button {
                    showWinetricksList.toggle()
                } label: {
                    Label("List", systemImage: "list.bullet")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .popover(isPresented: $showWinetricksList, arrowEdge: .bottom) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 6)], alignment: .leading, spacing: 5) {
                        ForEach(model.requiredWinetricks, id: \.self) { verb in
                            Text(verb)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(width: 300, alignment: .leading)
                }
            }
        }
    }

    var modsCard: some View {
        WizardCard {
            VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                CardHeading(title: "Fixes")

                Toggle("Update usvfs binaries", isOn: updateUSVFSBinding)
                    .disabled(model.engine == SetupConfiguration.sikarugir10Engine)

                if model.renderer == "dxvk" {
                    Toggle("Fix missing reticles", isOn: .constant(false))
                        .disabled(true)
                    Text("Bug not present if DXVK is used.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Toggle("Fix missing reticles", isOn: $model.applyReticleFix)
                }
                if model.renderer != "dxvk", model.applyReticleFix {
                    Text("Set highest priority in MO2 & delete shaders_cache")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
