import Foundation

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct SetupConfiguration {
    static let defaultInstallDirectory = AppSettingsStore.defaultInstallDirectory
    static let defaultEngine = SetupDefaults.defaultEngine
    static let crossOverEngine = SetupDefaults.crossOverEngine
    static let sikarugir10Engine = SetupDefaults.sikarugir10Engine
    static let supportedEngines = SetupDefaults.supportedEngines
    var appName = "stalker-gamma"
    var installDirectory = SetupConfiguration.defaultInstallDirectory
    var engine = SetupConfiguration.defaultEngine
    var renderer = "d3dmetal"
    var updateUSVFS = true
    var installGPTK4Binaries = true
    var programBatch = "/mo2.bat"
    var launchBatches: [LaunchBatch] = []
    var launchArguments = ""
    var saveVerboseLog = false
    var driveMappingMode = "preserve"
    var displayMode = "defaultWine"
    var displayResolutionMode = "detected"
    var customDisplayResolutionWidth = ""
    var customDisplayResolutionHeight = ""
    var manualModOrganizerPath = ""
    var preflight: Preflight?
    var detectedDisplay: MacDisplaySettings?

    var outputAppPath: String {
        let cleanName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = cleanName.hasSuffix(".app") ? String(cleanName.dropLast(4)) : cleanName
        let name = "\(baseName).app"
        return URL(fileURLWithPath: installDirectory).appendingPathComponent(name).path
    }

    var wrapperNameIsValid: Bool {
        Self.isValidWrapperName(appName)
    }

    static func isValidWrapperName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed != "." && trimmed != ".." else { return false }
        return trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: "/:")) == nil
    }

    var selectedLaunchExecutablePath: String {
        if programBatch == "/mo2.bat" {
            let manualPath = manualModOrganizerPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !manualPath.isEmpty { return manualPath }
            if let detectedPath = preflight?.mo2Path, !detectedPath.isEmpty { return detectedPath }
            return "ModOrganizer.exe"
        }
        return launchBatches.first { $0.batchPath == programBatch }?.executablePath ?? programBatch
    }

    var selectedLaunchExecutableLabel: String {
        if programBatch == "/mo2.bat" { return "ModOrganizer" }
        return URL(fileURLWithPath: selectedLaunchExecutablePath).lastPathComponent
    }

    var selectedLaunchExecutableFound: Bool {
        if programBatch == "/mo2.bat" {
            return selectedModOrganizerExecutableFound
        }
        let path = selectedLaunchExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(fileURLWithPath: path).pathExtension.caseInsensitiveCompare("exe") == .orderedSame
            && FileManager.default.fileExists(atPath: path)
    }

    var launchArgumentsAreValid: Bool {
        !SetupLaunchBatchTools.containsLineBreak(launchArguments)
    }

    var rendererLabel: String {
        switch renderer {
        case "dxmt":
            return "DXMT"
        case "dxvk":
            return "DXVK"
        default:
            return "D3DMetal"
        }
    }

    var engineLabel: String {
        switch engine {
        case Self.crossOverEngine:
            return "Wine CX 24.0.7"
        default:
            return "Wine Sikarugir 10.0"
        }
    }

    var environmentOK: Bool {
        selectedModOrganizerExecutableFound
    }

    var requiredToolsOK: Bool {
        true
    }

    var selectedModOrganizerExecutableFound: Bool {
        AppSettingsStore.isValidModOrganizerExecutable(manualModOrganizerPath)
    }

    var createFlowEnvironmentOK: Bool {
        selectedModOrganizerExecutableFound
    }

    var canInstallComponents: Bool {
        false
    }

    var plannedWineDriveMapping: String {
        if driveMappingMode == "shorten", !optionalGDriveRoot.isEmpty {
            return "G: -> \(optionalGDriveRoot)"
        }
        return "Z: -> /"
    }

    var optionalGDriveRoot: String {
        let selected = manualModOrganizerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty else { return "" }
        return URL(fileURLWithPath: selected)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .standardizedFileURL.path
    }

    var driveMappingReady: Bool {
        driveMappingMode != "shorten" || !optionalGDriveRoot.isEmpty
    }

    var selectedDisplayResolution: (width: Int, height: Int)? {
        guard displayMode == "forced" else { return nil }
        switch displayResolutionMode {
        case "detected":
            guard let display = detectedDisplay,
                  display.backingWidth > 0,
                  display.backingHeight > 0 else {
                return nil
            }
            return (display.backingWidth, display.backingHeight)
        case "1920x1080":
            return (1920, 1080)
        case "2560x1440":
            return (2560, 1440)
        case "3840x2160":
            return (3840, 2160)
        case "custom":
            guard let width = Int(customDisplayResolutionWidth.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let height = Int(customDisplayResolutionHeight.trimmingCharacters(in: .whitespacesAndNewlines)),
                  width > 0,
                  height > 0 else {
                return nil
            }
            return (width, height)
        default:
            return nil
        }
    }

    var displayResolutionLabel: String {
        guard let resolution = selectedDisplayResolution else {
            return "Wine default"
        }
        return "\(resolution.width) x \(resolution.height)"
    }

    var setupRequest: SetupRequest {
        let modOrganizerPath = manualModOrganizerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let arguments = launchArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolution = selectedDisplayResolution

        return SetupRequest(
            appName: appName.trimmingCharacters(in: .whitespacesAndNewlines),
            outputApp: outputAppPath,
            engine: engine,
            renderer: renderer,
            updateUSVFS: updateUSVFS,
            installGPTK4Binaries: installGPTK4Binaries,
            mo2Path: modOrganizerPath,
            programBatch: programBatch,
            launchBatches: launchBatches,
            launchArguments: arguments.isEmpty ? nil : arguments,
            driveMappingMode: driveMappingMode,
            displayResolutionWidth: resolution?.width,
            displayResolutionHeight: resolution?.height,
            resetWineDisplay: displayMode == "defaultWine",
            writeLog: saveVerboseLog,
            verbose: saveVerboseLog
        )
    }

}
