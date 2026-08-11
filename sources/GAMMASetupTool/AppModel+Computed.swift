import SwiftUI
import AppKit
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

extension AppModel {
    // MARK: - Wrapper Status

    var requiredWinetricksSummary: String {
        requiredWinetricks.joined(separator: ", ")
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
            installDirectXBinaries: installDirectXBinaries,
            compatibilityProfile: compatibilityProfile,
            programBatch: programBatch,
            launchBatches: launchBatches,
            launchArguments: launchArguments,
            saveVerboseLog: saveVerboseLog,
            driveMappingMode: driveMappingMode,
            displayMode: displayMode,
            manualModOrganizerPath: manualModOrganizerPath,
            preflight: preflight
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
            return "Enter an app name."
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
            && selectedLaunchExecutableFound
            && configuration.launchArgumentsAreValid
    }

    var selectedModOrganizerExecutableFound: Bool {
        configuration.selectedModOrganizerExecutableFound
    }

    var selectedLaunchExecutablePath: String {
        configuration.selectedLaunchExecutablePath
    }

    var selectedLaunchExecutableLabel: String {
        configuration.selectedLaunchExecutableLabel
    }

    var selectedLaunchExecutableFound: Bool {
        configuration.selectedLaunchExecutableFound
    }

    var launchConfigurationIsValid: Bool {
        selectedLaunchExecutableFound && configuration.launchArgumentsAreValid
    }

    var launchSelectionMessage: String {
        if !configuration.launchArgumentsAreValid {
            return "Launch flags must be a single line."
        }
        if !selectedLaunchExecutableFound {
            return "Selected executable was not found."
        }
        return "The executable and flags are written to the wrapper's launch batch."
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
        "Create wrapper"
    }

    var createHeaderTitle: String {
        if installFailed {
            return "Installation failed"
        }
        if isRunning {
            return "Installation in progress"
        }
        return "Review settings"
    }

    var createHeaderSubtitle: String {
        if installFailed {
            return "Check the logs for the failed setup step."
        }
        if isRunning {
            return statusText.isEmpty ? "Applying changes" : statusText
        }
        return "Confirm options"
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
            rows.append(SetupSummaryItem(label: SetupOptionCopy.gptkBinaries, planned: SetupOptionCopy.installAction))
        }
        if installDirectXBinaries {
            rows.append(SetupSummaryItem(label: SetupOptionCopy.dxBinaries, planned: SetupOptionCopy.installAction))
        }
        if updateUSVFS {
            rows.append(SetupSummaryItem(label: SetupOptionCopy.usvfsBinaries, planned: SetupOptionCopy.installBundledAction))
        }
        rows.append(SetupSummaryItem(label: "Settings", planned: "Recommended"))
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
        let arguments = launchArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        if !arguments.isEmpty {
            add("Flags", arguments)
        }
        add("Engine", engineLabel)
        add("Renderer", rendererLabel)

        if driveMappingMode == "shorten" {
            add("Drive mapping", plannedWineDriveMapping)
        }

        if displayMode == "retinaOff" {
            add("Wine display", "Force Retina off")
        }

        if updateUSVFS {
            add(SetupOptionCopy.usvfsBinaries, SetupOptionCopy.installBundledAction)
        }
        if installGPTK4Binaries {
            add(SetupOptionCopy.gptkBinaries, SetupOptionCopy.installAction)
        }

        if saveVerboseLog {
            add(SetupOptionCopy.logTitle, SetupOptionCopy.logAction)
        }

        return rows
    }

    var plannedWineDriveMapping: String {
        configuration.plannedWineDriveMapping
    }

    var driveMappingReady: Bool {
        configuration.driveMappingReady
    }

    var gammaFolderSelectionError: String? {
        let trimmed = preflightError.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.localizedCaseInsensitiveContains("ModOrganizer.exe not found") else { return nil }
        return "Selected folder is not a valid MO2 folder. Select the path that contains ModOrganizer.exe."
    }

    var environmentMessage: String {
        if !selectedModOrganizerExecutableFound {
            return "Select the ModOrganizer folder."
        }
        return ""
    }

}
