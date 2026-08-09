import SwiftUI
import AppKit
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

extension AppModel {
    // MARK: - Saved Settings

    private var settingsURL: URL? {
        AppSettingsStore.defaultSettingsURL()
    }

    func loadSettings() {
        manualModOrganizerPath = AppSettingsStore.loadManualModOrganizerPath(from: settingsURL)
    }

    func saveSettings(gammaPath: String) {
        do {
            try AppSettingsStore.save(gammaPath: gammaPath, to: settingsURL)
        } catch {
            preflightError = "Could not save settings: \(error.localizedDescription)"
        }
    }

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
            modOrganizerSelectionError = "ModOrganizer.exe not found in selected folder."
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

    func prepareNewWrapperFlow() {
        appName = "stalker-gamma"
        installDirectory = SetupConfiguration.defaultInstallDirectory
        driveMappingMode = "preserve"
        useDefaultLaunchConfiguration()
        modOrganizerSelectionError = ""
    }

    func chooseLaunchExecutable() {
        let panel = NSOpenPanel()
        panel.title = "Select any Windows Executable"
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
            useModOrganizerLaunch()
        } else {
            setLaunchExecutable(url.path)
        }
    }

    func useModOrganizerLaunch() {
        programBatch = "/mo2.bat"
        installDirectXBinaries = false
        launchBatches.removeAll()
    }

    func useDefaultLaunchConfiguration() {
        useModOrganizerLaunch()
        launchArguments = ""
    }

    func setLaunchExecutable(_ executablePath: String) {
        let executable = URL(fileURLWithPath: executablePath)
        let batchPath = uniqueBatchPath(for: executable)
        let detectedMO2 = manualModOrganizerPath.isEmpty ? preflight?.mo2Path : manualModOrganizerPath
        let matchesDetectedMO2 = detectedMO2.map {
            URL(fileURLWithPath: $0).standardizedFileURL == executable.standardizedFileURL
        } ?? false
        let usesMOEnv = matchesDetectedMO2
            || executable.lastPathComponent.caseInsensitiveCompare("ModOrganizer.exe") == .orderedSame
        let batch = LaunchBatch(
            batchPath: batchPath,
            executablePath: executablePath,
            workingDirectory: executable.deletingLastPathComponent().path,
            usesModOrganizerEnvironment: usesMOEnv
        )
        launchBatches = [batch]
        programBatch = batch.batchPath
    }

    private func normalizedBatchPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "/mo2.bat" }
        return trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
    }

    private func uniqueBatchPath(for executable: URL) -> String {
        let folderName = executable
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let executableName = executable.deletingPathExtension().lastPathComponent.lowercased()
        var name = folderName.isEmpty ? executable.deletingPathExtension().lastPathComponent : folderName
        if executableName.contains("avx") {
            name += " - AVX"
        }
        var candidate = normalizedBatchPath("\(name).bat")
        var index = 2
        let existing = Set(["/mo2.bat"] + launchBatches.map(\.batchPath))
        while existing.contains(candidate) {
            candidate = normalizedBatchPath("\(name) \(index).bat")
            index += 1
        }
        return candidate
    }

    func create() async -> Bool {
        isRunning = true
        frozenSetupSummaryItems = setupSummaryItems
        installStageIndex = 0
        installStageCompletedIndex = -1
        installFailed = false
        receivedInstallStageEvents = false
        progress = 0
        logText = ""
        savedLogPath = ""
        statusText = "Creating"
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
                logText += "\nerror: setup exited while running \(installStageName(at: installStageIndex)).\n"
            }
            if result.exitCode == 0 {
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
