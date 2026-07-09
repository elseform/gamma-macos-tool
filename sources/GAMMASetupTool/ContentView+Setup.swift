import SwiftUI

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct SetupPage: View {
    @ObservedObject var model: AppModel
    @Binding var showWinetricksList: Bool

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: Layout.setupColumnSpacing) {
                setupOptionsCard
                    .frame(width: Layout.setupLeftColumnWidth, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 12) {
                    rendererCard
                    additionalOptionsCard
                }
                .frame(width: Layout.setupRightColumnWidth, alignment: .topLeading)
            }
            .frame(width: Layout.setupContentWidth, alignment: .topLeading)
        }
        .frame(width: Layout.setupContentWidth, alignment: .topLeading)
        .disabled(!model.selectedModOrganizerExecutableFound || model.isRunning)
        .opacity((model.selectedModOrganizerExecutableFound && !model.isRunning) ? 1 : 0.45)
        .onChange(of: model.outputAppPath) { _ in
            model.targetAppPathDidChange()
        }
    }

    // MARK: - App And Prefix

    private var setupOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            prefixPanel
            winetricksCard
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var prefixPanel: some View {
        WizardCard {
            VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                engineControls
                Divider()
                driveMappingControls
            }
        }
    }

    private var engineControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Engine")
                Picker("Engine", selection: $model.engine) {
                    Text("Wine CX 24.0.7").tag(SetupConfiguration.crossOverEngine)
                    Text("Wine Sikarugir 10.0").tag(SetupConfiguration.sikarugir10Engine)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            if let unsupported = model.unsupportedExistingWrapperEngine {
                Text("This wrapper uses an unsupported engine (\(unsupported)) and cannot be updated by this tool.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Renderer

    private var rendererCard: some View {
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
                displayControls
            }
        }
    }

    // MARK: - Display

    private var displayControls: some View {
        VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 7) {
                GridRow {
                    Text("Display")
                    Picker("Display", selection: $model.displayMode) {
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
        }
    }

    private func rendererHelp(for renderer: String) -> String {
        switch renderer {
        case "dxmt":
            return "Best performance. Experimental."
        case "dxvk":
            return "Average performance. Most accurate if you use a lot of shader mods."
        default:
            return "Best first choice for compatibility."
        }
    }

    private var detectedResolutionLabel: String? {
        guard let display = model.detectedDisplay,
              display.backingWidth > 0,
              display.backingHeight > 0 else {
            return nil
        }
        return "Use detected: \(display.backingWidth) x \(display.backingHeight)"
    }

    // MARK: - Drive Mapping

    @ViewBuilder
    private var driveMappingControls: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
            GridRow {
                Text("Drive mapping")
                Picker("Drive mapping", selection: $model.driveMappingMode) {
                    Text("Default Z:").tag("preserve")
                    Text("Add G:").tag("shorten")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
            GridRow {
                Text("Mapping")
                Text(model.plannedWineDriveMapping)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }

        Text(driveMappingExplanation)
            .font(.caption)
            .foregroundStyle(model.driveMappingMode == "shorten" ? .yellow : .secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var driveMappingExplanation: String {
        if model.driveMappingMode == "shorten" {
            return "Creates G: at the folder containing the selected GAMMA folder. ModOrganizer.ini is not modified; use this only when its existing paths already use G:."
        }
        return "Uses Wine's default Z: host mapping. ModOrganizer.ini is not modified. Choose Add G: if its existing paths already use G:."
    }

    // MARK: - Winetricks

    private var winetricksStatusIcon: String {
        switch model.winetricksWrapperState {
        case .installed:
            return "checkmark.circle.fill"
        case .needsUpdate:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .planned:
            return "arrow.down.circle.fill"
        }
    }

    private var winetricksStatusText: String {
        switch model.winetricksWrapperState {
        case .installed:
            return "Present"
        case .needsUpdate:
            return "Verify"
        case .planned:
            return model.requiredWinetricksSummary
        }
    }

    private var winetricksStatusColor: Color {
        SetupStatusTone.winetricks(model.winetricksWrapperState).color
    }

    private var winetricksCard: some View {
        WizardCard(verticalPadding: Layout.winetricksPanelVerticalPadding) {
            winetricksCardContent
        }
    }

    private var winetricksCardContent: some View {
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

    // MARK: - Additional Options

    private var additionalOptionsCard: some View {
        WizardCard {
            VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                CardHeading(title: "Additional Options")
                Toggle("Update ModOrganizer's usvfs binaries", isOn: $model.updateUSVFS)
                Toggle("Update GPTK4 binaries", isOn: $model.installGPTK4Binaries)
            }
        }
    }
}
