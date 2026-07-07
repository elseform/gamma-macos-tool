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
            targetAppPathDidChange()
        }
    }

    @discardableResult
    func chooseModOrganizerFolder() -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Select ModOrganizer Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        let currentPath = manualModOrganizerPath.isEmpty ? preflight?.mo2Path : manualModOrganizerPath
        if let currentPath, !currentPath.isEmpty {
            let url = URL(fileURLWithPath: currentPath)
            panel.directoryURL = url.deletingLastPathComponent()
        }
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        let detected = AppSettingsStore.detectedModOrganizerPath(in: url)
        let modOrganizerPath = detected ?? url.appendingPathComponent("ModOrganizer.exe").path
        manualModOrganizerPath = modOrganizerPath
        if detected == nil {
            modOrganizerSelectionError = "Selected folder does not contain ModOrganizer.exe."
        } else {
            modOrganizerSelectionError = ""
            saveSettings(gammaPath: URL(fileURLWithPath: modOrganizerPath).deletingLastPathComponent().path)
        }
        if programBatch == "/mo2.bat" {
            launchBatches.removeAll()
        }
        return detected != nil
    }

    func chooseGammaFolder() {
        _ = chooseModOrganizerFolder()
    }

    @discardableResult
    func chooseExistingWrapper() -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Select Existing Wrapper"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        if let appType = UTType(filenameExtension: "app") {
            panel.allowedContentTypes = [appType]
        }
        panel.directoryURL = URL(fileURLWithPath: installDirectory)
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return selectExistingWrapper(at: url)
    }

    @discardableResult
    func selectExistingWrapper(at url: URL) -> Bool {
        guard let selection = AppSettingsStore.wrapperSelection(from: url) else {
            return false
        }
        installDirectory = selection.installDirectory
        appName = selection.appName
        selectedExistingWrapperPath = URL(fileURLWithPath: outputAppPath).standardizedFileURL.path
        targetAppPathDidChange()

        if let inferred = inferredModOrganizerPathFromCurrentWrapper() {
            manualModOrganizerPath = inferred
            modOrganizerSelectionError = ""
            saveSettings(gammaPath: URL(fileURLWithPath: inferred).deletingLastPathComponent().path)
        } else {
            manualModOrganizerPath = ""
            modOrganizerSelectionError = "Select the ModOrganizer folder used by this wrapper."
        }
        return true
    }

    func prepareNewWrapperFlow() {
        appName = "stalker-gamma"
        installDirectory = SetupConfiguration.defaultInstallDirectory
        selectedExistingWrapperPath = ""
        modOrganizerSelectionError = ""
        targetAppPathDidChange()
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
        let detectedModOrganizerPath = manualModOrganizerPath.isEmpty ? preflight?.mo2Path : manualModOrganizerPath
        if let detectedModOrganizerPath,
           URL(fileURLWithPath: detectedModOrganizerPath).standardizedFileURL == url.standardizedFileURL {
            programBatch = "/mo2.bat"
            launchBatches.removeAll()
        } else {
            setLaunchExecutable(url.path)
        }
    }

    func setLaunchExecutable(_ executablePath: String) {
        let executable = URL(fileURLWithPath: executablePath)
        let batchPath = uniqueBatchPath(for: executable)
        let detectedMO2 = manualModOrganizerPath.isEmpty ? preflight?.mo2Path : manualModOrganizerPath
        let usesMOEnv: Bool
        if let detectedMO2 {
            usesMOEnv = URL(fileURLWithPath: detectedMO2).standardizedFileURL == executable.standardizedFileURL
        } else {
            usesMOEnv = executable.lastPathComponent.caseInsensitiveCompare("ModOrganizer.exe") == .orderedSame
        }
        let batch = LaunchBatch(
            batchPath: batchPath,
            executablePath: executablePath,
            workingDirectory: executable.deletingLastPathComponent().path,
            usesModOrganizerEnvironment: usesMOEnv
        )
        launchBatches = [batch]
        programBatch = batch.batchPath
    }

    func create() async -> Bool {
        let startedWithExistingWrapper = outputAppExists
        isRunning = true
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

}
