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
            return winetricksMarkersInstalled ? .installed : .planned
        }
        let overrides = currentDllOverrides(in: registry)
        if overrides.isEmpty {
            return winetricksMarkersInstalled ? .installed : .planned
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
            wineESync: wineESync,
            wineMSync: wineMSync,
            updateUSVFS: updateUSVFS,
            enableHIDDevices: enableHIDDevices,
            enableFnToggle: enableFnToggle,
            moltenVKFastMath: moltenVKFastMath,
            metalHUD: metalHUD,
            dxmtMetalFXSpatial: dxmtMetalFXSpatial,
            dxmtMetalFXScaleFactor: dxmtMetalFXScaleFactor,
            dxmtLogLevel: dxmtLogLevel,
            dxvkHUD: dxvkHUD,
            programBatch: programBatch,
            launchBatches: launchBatches,
            extraWinetricks: extraWinetricks,
            applyReticleFix: applyReticleFix,
            saveVerboseLog: saveVerboseLog,
            driveMappingMode: driveMappingMode,
            displayMode: displayMode,
            displayResolutionMode: displayResolutionMode,
            customDisplayResolutionWidth: customDisplayResolutionWidth,
            customDisplayResolutionHeight: customDisplayResolutionHeight,
            manualModOrganizerPath: manualModOrganizerPath,
            preflight: preflight,
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

    var canInstallComponents: Bool {
        configuration.canInstallComponents
    }

    var requiredToolsOK: Bool {
        guard let preflight else { return false }
        return preflight.homebrewFound
            && preflight.sikarugirInstalled
            && preflight.winetricksFound
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
        "Review settings"
    }

    var createHeaderSubtitle: String {
        "Confirm wrapper options before installation."
    }

    var setupSummaryItems: [SetupSummaryItem] {
        if let frozenSetupSummaryItems {
            return frozenSetupSummaryItems
        }
        let current = currentSettingsOverride ?? (outputAppExists ? currentManagedSettings() : [:])
        return makeSetupSummaryItems(current: current, includeCurrent: true)
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
        if wineESync {
            add("ESync", "Enabled", currentKey: "esync")
        }
        if wineMSync {
            add("MSync", "Enabled", currentKey: "msync")
        }
        add("Switch media keys", enableFnToggle ? "Enabled" : "Disabled", currentKey: "fnToggle")
        add("HID Fix", enableHIDDevices ? "Compatibility mode" : "Wine default", currentKey: "hidDevices")
        add("Renderer", rendererLabel, currentKey: "renderer")
        if moltenVKFastMath {
            add("MoltenVK fast math", "Enabled", currentKey: "fastMath")
        }
        if metalHUD {
            add(renderer == "dxvk" ? "DXVK HUD" : "Performance HUD", "Enabled", currentKey: "hud")
        }

        if preflight != nil {
            add("Drive mapping", plannedWineDriveMapping, currentKey: "driveMapping")
            if willRewriteModOrganizerIni {
                add("ModOrganizer.ini", "Rewrite Z: paths to short mapping")
            }
        }

        if selectedDisplayResolution != nil {
            add("Wine display", displayResolutionLabel, currentKey: "wineDisplay")
        }

        if renderer == "dxmt" {
            if dxmtMetalFXSpatial {
                add("DXMT MetalFX spatial", "Enabled", currentKey: "dxmtSpatial")
                if !dxmtMetalFXScaleFactor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    add("DXMT MetalFX scale", dxmtMetalFXScaleFactor, currentKey: "dxmtScale")
                }
            }
            if dxmtLogLevel != "default" {
                add("DXMT log level", dxmtLogLevel, currentKey: "dxmtLog")
            }
        } else if renderer == "dxvk" {
            if metalHUD {
                add("DXVK HUD contents", dxvkHUD == "default" ? "Default" : dxvkHUD, currentKey: "dxvkHud")
            }
        }

        if !extraWinetricks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add("Extra winetricks", extraWinetricks, currentKey: "extraWinetricks")
        }
        if renderer != "dxvk" && applyReticleFix {
            add("Fixes", "Enabled", currentKey: "reticleFix")
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
        guard let preflight else { return "Checking environment..." }
        if !preflight.homebrewFound {
            return "Install Homebrew first; it is required for Sikarugir and winetricks."
        }
        if !preflight.gammaFound || !preflight.mo2Found || !preflight.modOrganizerIniFound {
            return "Select the GAMMA path."
        }
        return "Install Homebrew-managed setup components, then recheck."
    }
}
