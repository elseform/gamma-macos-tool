import SwiftUI
import AppKit

struct CreatePage: View {
    @ObservedObject var model: AppModel
    @Binding var createButtonSubmitted: Bool
    var minimalSummary = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.isRunning || createButtonSubmitted || model.installFailed {
                runStatus
            } else {
                setupReviewCard(items: minimalSummary ? model.minimalSetupSummaryItems : model.setupSummaryItems)
            }
        }
        .frame(width: Layout.setupContentWidth, alignment: .topLeading)
    }

    // MARK: - Setup Review

    private func setupReviewCard(items: [SetupSummaryItem]) -> some View {
        WizardCard {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                ForEach(items) { item in
                    SetupSummaryRow(item: item)
                }
            }
            .font(.system(size: 15))
            .padding(.vertical, 4)
        }
        .frame(width: Layout.setupContentWidth, alignment: .topLeading)
    }

    // MARK: - Run Status

    private var runStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isRunning || model.installFailed {
                WizardCard {
                    installStages
                }
                .frame(width: Layout.setupContentWidth, alignment: .topLeading)

                ProgressView(value: model.progress)

                if model.installFailed {
                    installFailureView
                }
            }

            if model.saveVerboseLog && (model.isRunning || !model.logText.isEmpty) {
                DisclosureGroup("Output", isExpanded: $model.showOutput) {
                    TextEditor(text: $model.logText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 130)
                        .border(Color(nsColor: .separatorColor))
                }
            }
        }
        .frame(width: Layout.setupContentWidth, alignment: .topLeading)
    }

    private var installFailureView: some View {
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

    private var installStages: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(installStageRows.enumerated()), id: \.offset) { _, row in
                installStageRow(row: row)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var installStageRows: [(stage: Int, title: String, detail: String)] {
        var rows: [(stage: Int, title: String, detail: String)] = [
            (0, model.wrapperStageTitle, ""),
            (1, "Engine", model.engineLabel)
        ]
        if model.updateUSVFS {
            rows.append((1, "ModOrganizer usvfs", "Update binaries"))
        }
        if model.installGPTK4Binaries {
            rows.append((1, "GPTK4 binaries", "Install or update bundled files"))
        }
        rows.append((2, "Prefix", "Initialize Wine prefix"))
        if model.driveMappingMode == "shorten" {
            rows.append((3, "Drive mapping", model.plannedWineDriveMapping))
        }
        rows += [
            (4, "Winetricks", model.requiredWinetricksSummary),
            (5, "Finalize", "")
        ]
        return rows
    }

    private func installStageRow(row: (stage: Int, title: String, detail: String)) -> some View {
        HStack(spacing: 8) {
            stageIcon(for: row.stage)
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
        .frame(height: 16)
    }

    private func stageIcon(for index: Int) -> some View {
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

struct CompletePage: View {
    @ObservedObject var model: AppModel

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WizardCard {
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

                    Text("Run created app to open MO2.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: Layout.completeMaxWidth, alignment: .topLeading)
        }
        .frame(width: Layout.completeMaxWidth, alignment: .topLeading)
    }
}
