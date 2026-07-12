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
        .planned
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
            detectedDisplay: detectedDisplay
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

    var wrapperStageTitle: String {
        "Create wrapper"
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
        configuration.wrapperNameIsValid && !FileManager.default.fileExists(atPath: outputAppPath)
    }

    var wrapperNameValidationMessage: String {
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Enter a wrapper name."
        }
        if !SetupConfiguration.isValidWrapperName(appName) {
            return "Use a name without / or : characters."
        }
        if FileManager.default.fileExists(atPath: outputAppPath) {
            return "An app with this name already exists. Choose another name."
        }
        return ""
    }

    var createFlowEnvironmentOK: Bool {
        configuration.createFlowEnvironmentOK
    }

    var setupReady: Bool {
        configuration.createFlowEnvironmentOK
            && driveMappingReady
            && wrapperNameIsValid
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
        "Create GAMMA wrapper"
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
        return makeSetupSummaryItems()
    }

    var minimalSetupSummaryItems: [SetupSummaryItem] {
        var rows = [
            SetupSummaryItem(label: "App", planned: outputAppPath),
            SetupSummaryItem(label: "ModOrganizer", planned: configuration.selectedLaunchExecutablePath),
            SetupSummaryItem(label: "Engine", planned: engineLabel),
            SetupSummaryItem(label: "Renderer", planned: rendererLabel)
        ]
        if installGPTK4Binaries {
            rows.append(SetupSummaryItem(label: "GPTK4 binaries", planned: "Install or update bundled files"))
        }
        if updateUSVFS {
            rows.append(SetupSummaryItem(label: "ModOrganizer usvfs", planned: "Update binaries"))
        }
        rows.append(SetupSummaryItem(label: "Installation", planned: "Default settings"))
        return rows
    }

    func makeSetupSummaryItems() -> [SetupSummaryItem] {
        var rows: [SetupSummaryItem] = []

        func add(_ label: String, _ planned: String) {
            rows.append(SetupSummaryItem(
                label: label,
                planned: planned
            ))
        }

        add("App", outputAppPath)
        add("Executable", configuration.selectedLaunchExecutablePath)
        add("Engine", engineLabel)
        add("Renderer", rendererLabel)

        if driveMappingMode == "shorten" {
            add("Drive mapping", plannedWineDriveMapping)
        }

        if selectedDisplayResolution != nil {
            add("Wine display", displayResolutionLabel)
        }

        if updateUSVFS {
            add("ModOrganizer usvfs", "Update binaries")
        }
        if installGPTK4Binaries {
            add("GPTK4 binaries", "Install")
        }

        return rows
    }

    var plannedWineDriveMapping: String {
        configuration.plannedWineDriveMapping
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

    func updateDetectedDisplayDefaults() {
        detectedDisplay = MacDisplaySettings.detectMainDisplay()
    }
}
