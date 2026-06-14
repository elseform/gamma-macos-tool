import SwiftUI
import AppKit
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

extension AppModel {
    // MARK: - Selection

    func chooseInstallDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: installDirectory)
        if panel.runModal() == .OK, let url = panel.url {
            installDirectory = url.path
            Task { await refreshPreflight() }
        }
    }

    func chooseGammaFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select GAMMA Path"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        let currentPath = manualModOrganizerPath.isEmpty ? preflight?.mo2Path : manualModOrganizerPath
        if let currentPath, !currentPath.isEmpty {
            let url = URL(fileURLWithPath: currentPath)
            panel.directoryURL = url.deletingLastPathComponent()
        }
        if panel.runModal() == .OK, let url = panel.url {
            let modOrganizerPath = AppSettingsStore.detectedModOrganizerPath(in: url) ?? url.appendingPathComponent("ModOrganizer.exe").path
            manualModOrganizerPath = modOrganizerPath
            saveSettings(gammaPath: URL(fileURLWithPath: modOrganizerPath).deletingLastPathComponent().path)
            Task { await refreshPreflight() }
        }
    }

    func chooseLaunchExecutable() {
        let panel = NSOpenPanel()
        panel.title = "Select Windows Executable"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        if let exeType = UTType(filenameExtension: "exe") {
            panel.allowedContentTypes = [exeType]
        }
        if let preflight, !preflight.anomalyPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: preflight.anomalyPath)
        } else if let preflight, !preflight.gammaPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: preflight.gammaPath)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        addLaunchBatch(forExecutable: url.path)
    }

    func selectLaunchBatch(_ batchPath: String) {
        programBatch = normalizedBatchPath(batchPath)
    }

    func removeLaunchBatch(_ batch: LaunchBatch) {
        launchBatches.removeAll { $0.batchPath == batch.batchPath }
        if programBatch == batch.batchPath {
            programBatch = "/mo2.bat"
        }
    }

    func addLaunchBatch(forExecutable executablePath: String) {
        let executable = URL(fileURLWithPath: executablePath)
        let batchPath = uniqueBatchPath(for: executable)
        let batch = LaunchBatch(
            batchPath: batchPath,
            executablePath: executablePath,
            workingDirectory: executable.deletingLastPathComponent().path
        )
        if !launchBatches.contains(where: { $0.batchPath == batch.batchPath }) {
            launchBatches.append(batch)
        }
        programBatch = batch.batchPath
    }

    // MARK: - Setup Flow

    func refreshPreflight() async {
        preflightError = ""
        do {
            let result = try await runEngine(command: "preflight", request: engineRequest(), stream: false)
            guard result.exitCode == 0 else {
                preflight = nil
                preflightError = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                return
            }
            preflight = try JSONDecoder().decode(Preflight.self, from: Data(result.output.utf8))
            updateDetectedDisplayDefaults()
            applyExistingWrapperSettingsIfNeeded()
        } catch {
            preflight = nil
            preflightError = error.localizedDescription
        }
    }

    func create() async -> Bool {
        let startedWithExistingWrapper = outputAppExists
        isRunning = true
        isInstallingComponents = false
        createModeOverride = plannedCreateModeLabel
        currentSettingsOverride = startedWithExistingWrapper ? currentManagedSettings() : nil
        frozenSetupSummaryItems = makeSetupSummaryItems(current: [:], includeCurrent: false)
        installStageIndex = 0
        installStageCompletedIndex = -1
        installFailed = false
        receivedInstallStageEvents = false
        progress = 0
        logText = ""
        savedLogPath = ""
        statusText = "Creating wrapper"
        pendingEngineEventText = ""
        do {
            let result = try await runEngine(command: "create", request: engineRequest(), stream: true)
            isRunning = false
            progress = result.exitCode == 0 ? 1 : progress
            if result.exitCode == 0 {
                installStageCompletedIndex = installStageCount - 1
                installStageIndex = installStageCount
            }
            statusText = result.exitCode == 0 ? WrapperCreatedCopy.title : "Failed"
            if result.exitCode != 0 && !logText.localizedCaseInsensitiveContains("error:") {
                logText += "\nerror: setup exited while running \(installStageName(at: installStageIndex)). Attach this log in Discord.\n"
            }
            if result.exitCode == 0 {
                await refreshPreflight()
                currentSettingsOverride = nil
                createModeOverride = nil
                frozenSetupSummaryItems = nil
                installStageIndex = -1
                installStageCompletedIndex = -1
                installFailed = false
            } else {
                installFailed = true
            }
            return result.exitCode == 0
        } catch {
            isRunning = false
            logText += "\n\(error.localizedDescription)"
            statusText = "Failed"
            installFailed = true
            return false
        }
    }

    func resetForNewWrapper() {
        logText = ""
        savedLogPath = ""
        statusText = "Ready"
        progress = 0
        isInstallingComponents = false
        createModeOverride = nil
        currentSettingsOverride = nil
        frozenSetupSummaryItems = nil
        installStageIndex = -1
        installStageCompletedIndex = -1
        installFailed = false
        showOutput = false
    }

    func openCreatedApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: outputAppPath))
    }

    func showCreatedAppAndQuit() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: outputAppPath)])
        NSApp.terminate(nil)
    }

    func openSavedLog() {
        let trimmed = savedLogPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let logURL = URL(fileURLWithPath: trimmed)
        let textEditURL = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        if FileManager.default.fileExists(atPath: textEditURL.path) {
            NSWorkspace.shared.open([logURL], withApplicationAt: textEditURL, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(logURL)
        }
    }

    func installComponents() async {
        isInstallingComponents = true
        isRunning = false
        installingComponent = nil
        progress = 0
        logText = ""
        savedLogPath = ""
        statusText = "Installing components"
        pendingEngineEventText = ""
        do {
            let result = try await runEngine(command: "install-dependencies", request: engineRequest(), stream: true)
            if result.exitCode == 0 {
                progress = 1
                statusText = "Rechecking environment"
                await refreshPreflight()
                isInstallingComponents = false
                installingComponent = nil
                logText = ""
                statusText = "Ready"
                progress = 0
                showOutput = false
            } else {
                isInstallingComponents = false
                installingComponent = nil
                statusText = "Install failed"
            }
        } catch {
            isInstallingComponents = false
            installingComponent = nil
            logText += "\n\(error.localizedDescription)"
            statusText = "Install failed"
        }
    }

    func installComponent(_ component: SetupComponent) async {
        isInstallingComponents = true
        isRunning = false
        installingComponent = component
        progress = 0
        logText = ""
        savedLogPath = ""
        statusText = "Installing \(component.rawValue)"
        pendingEngineEventText = ""
        do {
            let result = try await runEngine(
                command: "install-dependency",
                request: engineRequest(),
                extraArguments: ["--name", component.rawValue],
                stream: true
            )
            if result.exitCode == 0 {
                progress = 1
                statusText = "Rechecking environment"
                await refreshPreflight()
                isInstallingComponents = false
                installingComponent = nil
                logText = ""
                statusText = "Ready"
                progress = 0
                showOutput = false
            } else {
                isInstallingComponents = false
                installingComponent = nil
                statusText = "Install failed"
            }
        } catch {
            isInstallingComponents = false
            installingComponent = nil
            logText += "\n\(error.localizedDescription)"
            statusText = "Install failed"
        }
    }
}
