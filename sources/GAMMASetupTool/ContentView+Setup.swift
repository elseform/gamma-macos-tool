import SwiftUI

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct SetupPage: View {
    @ObservedObject var model: AppModel
    @Binding var showWinetricksList: Bool

    // MARK: - Body

    var body: some View {
        ViewThatFits(in: .horizontal) {
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

            VStack(alignment: .leading, spacing: 12) {
                setupOptionsCard
                rendererCard
                additionalOptionsCard
            }
            .frame(maxWidth: Layout.setupContentWidth, alignment: .topLeading)
        }
        .frame(maxWidth: Layout.setupContentWidth, alignment: .topLeading)
        .disabled(!model.selectedModOrganizerExecutableFound || model.isRunning)
        .opacity((model.selectedModOrganizerExecutableFound && !model.isRunning) ? 1 : 0.45)
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
                    Text("Wine display")
                    Picker("Wine display", selection: $model.displayMode) {
                        Text("Default").tag("defaultWine")
                        Text("Force Retina off").tag("retinaOff")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private func rendererHelp(for renderer: String) -> String {
        switch renderer {
        case "dxmt":
            return "Experimental Direct3D 11 renderer. Very unstable, use at your own risk."
        case "dxvk":
            return "Vulkan-based compatibility fallback. It is usually slower than D3DMetal or DXMT."
        default:
            return "Recommended renderer, use this unless you encounter issues."
        }
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
            return "Mount GAMMA directory into wine as G:"
        }
        return "Uses Wine's default Z: host mapping."
    }

    // MARK: - Winetricks

    private var winetricksStatusIcon: String {
        switch model.winetricksWrapperState {
        case .planned:
            return "arrow.down.circle.fill"
        }
    }

    private var winetricksStatusText: String {
        switch model.winetricksWrapperState {
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
            }

            TextField("e.g. faudio d3dx10", text: $model.additionalWinetricks)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Additional Options

    private var additionalOptionsCard: some View {
        WizardCard {
            VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                CardHeading(title: "Additional options")
                Toggle(SetupOptionCopy.installUSVFSBinaries, isOn: $model.updateUSVFS)
                Toggle(SetupOptionCopy.installGPTK4Binaries, isOn: $model.installGPTK4Binaries)
                Toggle(SetupOptionCopy.installDXMTBinaries, isOn: $model.installDXMTBinaries)
                
                if model.programBatch != "/mo2.bat" {
                    Toggle(SetupOptionCopy.installDirectXBinaries, isOn: $model.installDirectXBinaries)
                }
                
                Toggle(SetupOptionCopy.saveDetailedLog, isOn: $model.saveVerboseLog)
            }
        }
    }


}
