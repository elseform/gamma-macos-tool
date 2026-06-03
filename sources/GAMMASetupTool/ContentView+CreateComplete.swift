import SwiftUI
import AppKit

extension ContentView {
    var createStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                    ForEach(model.setupSummaryItems) { item in
                        SetupSummaryRow(item: item)
                    }
                }
                .font(.system(size: 15))
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: Layout.setupContentWidth, alignment: .topLeading)

            if !model.isRunning && !createButtonSubmitted {
                createActionPanel
            }

            runStatus
        }
        .frame(width: Layout.setupContentWidth, alignment: .topLeading)
    }

    var completeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.green)
                        Text("Wrapper created successfully")
                            .font(.headline)
                    }

                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                        GridRow {
                            Text("App location")
                                .foregroundStyle(.secondary)
                            Text(model.outputAppPath)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                        if model.saveVerboseLog {
                            GridRow {
                                Text("Log saved to")
                                    .foregroundStyle(.secondary)
                                if model.savedLogPath.isEmpty {
                                    Text("Log path was not reported.")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Button {
                                        model.openSavedLog()
                                    } label: {
                                        Text(model.savedLogPath)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    .buttonStyle(.link)
                                    .help("Open log")
                                }
                            }
                        }
                    }
                    .font(.callout)

                }
                .padding(.horizontal, Layout.setupPanelHorizontalPadding)
                .padding(.vertical, Layout.setupPanelVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: Layout.completeMaxWidth, alignment: .topLeading)

            completeActionPanel
        }
        .frame(width: Layout.completeMaxWidth, alignment: .topLeading)
    }

    var createActionPanel: some View {
        // GroupBox {
        //     HStack {
        //         Spacer()
                Button {
                    createButtonSubmitted = true
                    Task {
                        let created = await model.create()
                        createButtonSubmitted = false
                        if created {
                            step = .complete
                        }
                    }
                } label: {
                    Label(model.primaryButtonTitle, systemImage: "play.circle")
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.isRunning || !model.environmentOK || !model.driveMappingReady)
            //     Spacer()
            // }
            .padding(.horizontal, Layout.setupPanelHorizontalPadding)
            .padding(.vertical, Layout.setupPanelVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .center)
        // }
        .frame(width: Layout.setupContentWidth, alignment: .topLeading)
    }

    var completeActionPanel: some View {
        // GroupBox {
        //     HStack {
        //         Spacer()
                Button {
                    model.showCreatedAppAndQuit()
                } label: {
                    HStack(spacing: 6) {
                        HazardIcon()
                        Text("Show .app")
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .help("Show wrapper in Finder")
                // Spacer()
            // }
            .padding(.horizontal, Layout.setupPanelHorizontalPadding)
            .padding(.vertical, Layout.setupPanelVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .center)
        // }
        .frame(width: Layout.completeMaxWidth, alignment: .topLeading)
    }

    var runStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isRunning || model.installFailed {
                installStages
                if model.isRunning {
                    ProgressView(value: model.progress)
                }
                if model.installFailed {
                    installFailureView
                }
            }

            if model.saveVerboseLog && (model.isRunning || !model.logText.isEmpty) {
                DisclosureGroup("Output", isExpanded: $model.showOutput) {
                    TextEditor(text: $model.logText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 160)
                        .border(Color(nsColor: .separatorColor))
                }
            }
        }
        .frame(width: Layout.setupContentWidth, alignment: .topLeading)
    }

    var installFailureView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 5) {
                Text("Installation failed")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.red)
                if model.savedLogPath.isEmpty {
                    Text("No log path was reported. Open Output and copy the visible log.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Text("Log:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            model.openSavedLog()
                        } label: {
                            Text(model.savedLogPath)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .buttonStyle(.link)
                        .help("Open log")
                    }
                }
                Text("Go to the Discord support thread and attach the log.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
    }

    var installStages: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(installStageRows.enumerated()), id: \.offset) { index, row in
                installStageRow(index: index, row: row)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    var installStageRows: [(title: String, detail: String)] {
        [
            (model.wrapperStageTitle, ""),
            ("Engine", model.engineLabel),
            ("Prefix", "Initialize Wine prefix"),
            ("Drive mapping", model.plannedWineDriveMapping),
            ("Winetricks", model.requiredWinetricksSummary),
            ("Finalize", "")
        ]
    }

    func installStageRow(index: Int, row: (title: String, detail: String)) -> some View {
        HStack(spacing: 8) {
            stageIcon(for: index)
            Text(row.title)
                .font(.caption.weight(.semibold))
            if !row.detail.isEmpty {
                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .frame(height: 18)
    }

    func stageIcon(for index: Int) -> some View {
        return Group {
            if model.installFailed && index == model.installStageIndex {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            } else if index <= model.installStageCompletedIndex {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if index == model.installStageIndex {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 16)
    }
}
