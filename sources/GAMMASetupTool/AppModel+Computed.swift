import SwiftUI
import AppKit
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

extension AppModel {
    // MARK: - Wrapper Status

    var requiredWinetricksSummary: String {
        "corefonts, d3dx9_43, d3dx11_43, d3dcompiler_47, vcrun2026"
    }

    var winetricksWrapperState: WinetricksWrapperState {
        guard outputAppExists else { return .planned }
        guard let registry = currentUserRegistryText(), !registry.isEmpty else {
            return .planned
        }
        let overrides = currentDllOverrides(in: registry)
        if overrides.isEmpty {
            return .planned
        }
        return missingDllOverrides(in: overrides).isEmpty ? .installed : .needsUpdate
    }

    // MARK: - Configuration

    var configuration: SetupConfiguration {
        SetupConfiguration(
            appName: appName,
            installDirectory: installDirectory,
            engine: engine,
            renderer: renderer,
            updateUSVFS: updateUSVFS,
            installGPTK4Binaries: installGPTK4Binaries,
            programBatch: programBatch,
            launchBatches: launchBatches,
            saveVerboseLog: saveVerboseLog,
            driveMappingMode: driveMappingMode,
            displayMode: displayMode,
            displayResolutionMode: displayResolutionMode,
            customDisplayResolutionWidth: customDisplayResolutionWidth,
            customDisplayResolutionHeight: customDisplayResolutionHeight,
            manualModOrganizerPath: manualModOrganizerPath,
            preflight: preflight,
            detectedDisplay: detectedDisplay,
            outputAppExists: outputAppExists
        )
    }

    var engineURL: URL {
        if let bundled = AppResources.bundle.url(forResource: "gamma-setup-engine", withExtension: nil) {
            return bundled
        }
        if let bundled = Bundle.main.url(forResource: "gamma-setup-engine", withExtension: nil) {
            return bundled
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let builtEngine = cwd.appendingPathComponent("dist/intermediates/gamma-setup-engine")
        if FileManager.default.isExecutableFile(atPath: builtEngine.path) {
            return builtEngine
        }
        return cwd.appendingPathComponent("gamma-setup-engine")
    }

    var outputAppPath: String {
        SetupConfiguration(appName: appName, installDirectory: installDirectory).outputAppPath
    }

    var outputAppExists: Bool {
        FileManager.default.fileExists(atPath: outputAppPath)
    }

    var hasSelectedExistingWrapper: Bool {
        !selectedExistingWrapperPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && FileManager.default.fileExists(atPath: selectedExistingWrapperPath)
    }

    var createModeLabel: String {
        createModeOverride ?? plannedCreateModeLabel
    }

    var plannedCreateModeLabel: String {
        if outputAppExists {
            return engineRecreateWarning == nil ? "Update existing wrapper" : "Recreate wrapper"
        }
        return "Create new wrapper"
    }

    var wrapperStageTitle: String {
        switch createModeLabel {
        case "Update existing wrapper":
            return "Update wrapper"
        case "Recreate wrapper":
            return "Recreate wrapper"
        default:
            return "Create wrapper"
        }
    }

    var engineRecreateWarning: String? {
        guard outputAppExists else { return nil }
        let current = currentManagedSettings()["engine"] ?? "Unknown"
        guard current != engineLabel else { return nil }
        if current == "Unknown" {
            return "Unknown engine state. Wrapper will be recreated."
        }
        return "Engine change requires full recreation of wrapper."
    }

    var existingWrapperSettingsActive: Bool {
        outputAppExists
            && existingWrapperSettingsDetected
            && appliedWrapperSettingsPath == outputAppPath
    }

    var rendererLabel: String {
        configuration.rendererLabel
    }

    var engineLabel: String {
        configuration.engineLabel
    }

    var environmentOK: Bool {
        configuration.environmentOK
    }

    var wrapperNameIsValid: Bool {
        configuration.wrapperNameIsValid
    }

    var wrapperNameValidationMessage: String {
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Enter a wrapper name."
        }
        if !SetupConfiguration.isValidWrapperName(appName) {
            return "Use a name without / or : characters."
        }
        return ""
    }

    var createFlowEnvironmentOK: Bool {
        configuration.createFlowEnvironmentOK
    }

    var setupReady: Bool {
        configuration.createFlowEnvironmentOK && driveMappingReady
    }

    var selectedModOrganizerExecutableFound: Bool {
        configuration.selectedModOrganizerExecutableFound
    }

    var selectedModOrganizerDetail: String {
        let trimmed = manualModOrganizerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedModOrganizerExecutableFound {
            return trimmed
        }
        if !modOrganizerSelectionError.isEmpty {
            return modOrganizerSelectionError
        }
        if !trimmed.isEmpty {
            return "ModOrganizer.exe not found at \(trimmed)"
        }
        return "Select the folder that contains ModOrganizer.exe."
    }

    var canInstallComponents: Bool {
        configuration.canInstallComponents
    }

    var requiredToolsOK: Bool {
        configuration.requiredToolsOK
    }

    var primaryButtonTitle: String {
        switch createModeLabel {
        case "Update existing wrapper":
            return "Update GAMMA wrapper"
        case "Recreate wrapper":
            return "Recreate GAMMA wrapper"
        default:
            return "Create GAMMA wrapper"
        }
    }

    var createHeaderTitle: String {
        if installFailed {
            return "Installation failed"
        }
        if isRunning {
            return "Installing wrapper"
        }
        return "Review settings"
    }

    var createHeaderSubtitle: String {
        if installFailed {
            return "Check the output log for the failed setup step."
        }
        if isRunning {
            return statusText.isEmpty ? "Applying wrapper changes." : statusText
        }
        return "Confirm wrapper options before installation."
    }

    var setupSummaryItems: [SetupSummaryItem] {
        if let frozenSetupSummaryItems {
            return frozenSetupSummaryItems
        }
        let current = currentSettingsOverride ?? (outputAppExists ? currentManagedSettings() : [:])
        return makeSetupSummaryItems(current: current, includeCurrent: true)
    }

    var minimalSetupSummaryItems: [SetupSummaryItem] {
        var rows = [
            SetupSummaryItem(label: "App", planned: outputAppPath, current: nil),
            SetupSummaryItem(label: "ModOrganizer", planned: configuration.selectedLaunchExecutablePath, current: nil),
            SetupSummaryItem(label: "Engine", planned: engineLabel, current: nil),
            SetupSummaryItem(label: "Renderer", planned: rendererLabel, current: nil)
        ]
        if installGPTK4Binaries {
            rows.append(SetupSummaryItem(label: "GPTK4 binaries", planned: "Install or update bundled files", current: nil))
        }
        if updateUSVFS {
            rows.append(SetupSummaryItem(label: "ModOrganizer usvfs", planned: "Update binaries", current: nil))
        }
        rows.append(SetupSummaryItem(label: "Installation", planned: "Default settings", current: nil))
        return rows
    }

    func makeSetupSummaryItems(current: [String: String], includeCurrent: Bool) -> [SetupSummaryItem] {
        var rows: [SetupSummaryItem] = []

        func add(_ label: String, _ planned: String, currentKey: String? = nil) {
            rows.append(SetupSummaryItem(
                label: label,
                planned: planned,
                current: includeCurrent ? currentKey.flatMap { current[$0] } : nil
            ))
        }

        add("App", outputAppPath)
        add("Executable", configuration.selectedLaunchExecutablePath, currentKey: "launchExecutable")
        if let engineRecreateWarning {
            add("Warning", engineRecreateWarning)
        }
        add("Engine", engineLabel, currentKey: "engine")
        add("Renderer", rendererLabel, currentKey: "renderer")

        if preflight != nil, driveMappingMode == "shorten" {
            add("Drive mapping", plannedWineDriveMapping, currentKey: "driveMapping")
            if willRewriteModOrganizerIni {
                add("ModOrganizer.ini", "Rewrite Z: paths to short mapping")
            }
        }

        if selectedDisplayResolution != nil {
            add("Wine display", displayResolutionLabel, currentKey: "wineDisplay")
        }

        if updateUSVFS {
            add("ModOrganizer usvfs", "Update binaries", currentKey: "usvfs")
        }
        if installGPTK4Binaries {
            add("GPTK4 binaries", "Install", currentKey: "gptk4")
        }

        return rows
    }

    var plannedWineDriveMapping: String {
        configuration.plannedWineDriveMapping
    }

    var willRewriteModOrganizerIni: Bool {
        configuration.willRewriteModOrganizerIni
    }

    var driveMappingReady: Bool {
        configuration.driveMappingReady
    }

    var selectedDisplayResolution: (width: Int, height: Int)? {
        configuration.selectedDisplayResolution
    }

    var displayResolutionLabel: String {
        configuration.displayResolutionLabel
    }

    var gammaFolderSelectionError: String? {
        let trimmed = preflightError.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.localizedCaseInsensitiveContains("ModOrganizer.exe not found") else { return nil }
        return "Selected folder is not a valid GAMMA folder. Select the GAMMA folder that contains ModOrganizer.exe."
    }

    var environmentMessage: String {
        if !selectedModOrganizerExecutableFound {
            return "Select the ModOrganizer folder."
        }
        return ""
    }
}
