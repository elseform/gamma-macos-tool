import SwiftUI
import AppKit

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct ToolResult {
    var output: String
    var exitCode: Int32
}

enum SetupComponent: String {
    case sikarugir
    case winetricks
}

struct SetupSummaryItem: Identifiable {
    var id: String { label }
    let label: String
    let planned: String
    let current: String?

    var changed: Bool {
        guard let current else { return false }
        return current != planned
    }

    var displayValue: String {
        if let current, current != planned {
            return "\(current) -> \(planned)"
        }
        return planned
    }
}

final class OutputBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func stringValue() -> String {
        lock.lock()
        let current = data
        lock.unlock()
        return String(data: current, encoding: .utf8) ?? ""
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var appName = "stalker-gamma"
    @Published var installDirectory = NSString(string: "~/Applications").expandingTildeInPath
    @Published var engine = SetupConfiguration.defaultEngine
    @Published var renderer = "d3dmetal"
    @Published var wineESync = true
    @Published var wineMSync = true
    @Published var updateUSVFS = false
    @Published var enableHIDDevices = false
    @Published var enableFnToggle = false
    @Published var moltenVKFastMath = false
    @Published var metalHUD = false
    @Published var dxmtMetalFXSpatial = false
    @Published var dxmtMetalFXScaleFactor = ""
    @Published var dxmtLogLevel = "default"
    @Published var dxvkHUD = "default"
    @Published var extraWinetricks = ""
    @Published var applyReticleFix = true
    @Published var saveVerboseLog = true
    @Published var driveMappingMode = "preserve"
    @Published var displayMode = "forced"
    @Published var displayResolutionMode = "detected"
    @Published var customDisplayResolutionWidth = ""
    @Published var customDisplayResolutionHeight = ""
    @Published var detectedDisplay: MacDisplaySettings?
    @Published var manualModOrganizerPath = ""
    @Published var preflight: Preflight?
    @Published var preflightError = ""
    @Published var logText = ""
    @Published var savedLogPath = ""
    @Published var statusText = "Ready"
    @Published var isRunning = false
    @Published var isInstallingComponents = false
    @Published var installingComponent: SetupComponent?
    @Published var showOutput = false
    @Published var progress = 0.0
    @Published var createModeOverride: String?
    @Published var currentSettingsOverride: [String: String]?
    @Published var frozenSetupSummaryItems: [SetupSummaryItem]?
    @Published var installStageIndex = -1
    @Published var installStageCompletedIndex = -1
    @Published var installFailed = false
    @Published private(set) var existingWrapperSettingsDetected = false
    private var appliedWrapperSettingsPath: String?
    private var receivedInstallStageEvents = false
    private var pendingEngineEventText = ""

    let requiredWinetricks = [
        "corefonts",
        "vcrun2022",
        "d3dcompiler_42",
        "d3dcompiler_43",
        "d3dcompiler_46",
        "d3dcompiler_47",
        "d3dx9",
        "d3dx10",
        "d3dx11_42",
        "d3dx11_43"
    ]

    private let requiredDllOverrides = [
        "concrt140",
        "d3dcompiler_43",
        "d3dcompiler_47",
        "d3dx10",
        "d3dx10_33",
        "d3dx10_34",
        "d3dx10_35",
        "d3dx10_36",
        "d3dx10_37",
        "d3dx10_38",
        "d3dx10_39",
        "d3dx10_40",
        "d3dx10_41",
        "d3dx10_42",
        "d3dx10_43",
        "d3dx11_42",
        "d3dx11_43",
        "d3dx9_24",
        "d3dx9_25",
        "d3dx9_26",
        "d3dx9_27",
        "d3dx9_28",
        "d3dx9_29",
        "d3dx9_30",
        "d3dx9_31",
        "d3dx9_32",
        "d3dx9_33",
        "d3dx9_34",
        "d3dx9_35",
        "d3dx9_36",
        "d3dx9_37",
        "d3dx9_38",
        "d3dx9_39",
        "d3dx9_40",
        "d3dx9_41",
        "d3dx9_42",
        "d3dx9_43",
        "msvcp140",
        "msvcp140_1",
        "msvcp140_2",
        "msvcp140_atomic_wait",
        "msvcp140_codecvt_ids",
        "vcamp140",
        "vccorlib140",
        "vcomp140",
        "vcruntime140",
        "vcruntime140_1"
    ]

    var requiredWinetricksSummary: String {
        "corefonts, vcrun2022, DirectX runtimes"
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

    init() {
        loadSettings()
    }

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

    private func makeSetupSummaryItems(current: [String: String], includeCurrent: Bool) -> [SetupSummaryItem] {
        var rows: [SetupSummaryItem] = []

        func add(_ label: String, _ planned: String, currentKey: String? = nil) {
            rows.append(SetupSummaryItem(
                label: label,
                planned: planned,
                current: includeCurrent ? currentKey.flatMap { current[$0] } : nil
            ))
        }

        add("App", outputAppPath)
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

    private func engineRequest() -> SetupRequest {
        var request = configuration.setupRequest
        request.resourceRoot = AppResources.bundle.resourceURL?.path ?? Bundle.main.resourceURL?.path ?? ""
        if let icon = AppResources.bundle.url(forResource: "Anomaly", withExtension: "icns")
            ?? Bundle.main.url(forResource: "Anomaly", withExtension: "icns") {
            request.appIconSource = icon.path
        }
        return request
    }

    private var settingsURL: URL? {
        AppSettingsStore.defaultSettingsURL()
    }

    private func loadSettings() {
        manualModOrganizerPath = AppSettingsStore.loadManualModOrganizerPath(from: settingsURL)
    }

    private func saveSettings(gammaPath: String) {
        do {
            try AppSettingsStore.save(gammaPath: gammaPath, to: settingsURL)
        } catch {
            preflightError = "Could not save settings: \(error.localizedDescription)"
        }
    }

    private func currentManagedSettings() -> [String: String] {
        let app = URL(fileURLWithPath: outputAppPath)
        let contents = app.appendingPathComponent("Contents")
        let sharedSupport = contents.appendingPathComponent("SharedSupport")
        let prefix = sharedSupport.appendingPathComponent("prefix")
        let driveC = prefix.appendingPathComponent("drive_c")
        let info = contents.appendingPathComponent("Info.plist")
        let plist = NSDictionary(contentsOf: info) as? [String: Any] ?? [:]
        let mo2Bat = readText(driveC.appendingPathComponent("mo2.bat"))
        let dxvkConf = readText(driveC.appendingPathComponent("dxvk.conf"))
        let dxmtConf = readText(driveC.appendingPathComponent("dxmt.conf"))
        let systemReg = readText(prefix.appendingPathComponent("system.reg"))
        let userReg = readText(prefix.appendingPathComponent("user.reg"))
        let marker = readText(sharedSupport.appendingPathComponent(".stalker-gamma-sikarugir-setup"))

        var values: [String: String] = [:]
        values["engine"] = engineLabel(from: marker)
        let detectedRenderer = rendererName(from: plist, marker: marker)
        values["renderer"] = detectedRenderer
        if let markerESync = markerEnabledValue("wine_esync", in: marker) {
            values["esync"] = markerESync
        } else if let esync = enabledValue(plist["WINEESYNC"]) {
            values["esync"] = esync
        }
        if let markerMSync = markerEnabledValue("wine_msync", in: marker) {
            values["msync"] = markerMSync
        } else if let msync = enabledValue(plist["WINEMSYNC"]) {
            values["msync"] = msync
        }
        if let mouseInput = markerValue("mouse_input", in: marker) ?? markerValue("controller_input", in: marker) {
            values["hidDevices"] = mouseInput == "compatibility" ? "Compatibility mode" : "Wine default"
        } else if !systemReg.isEmpty {
            values["hidDevices"] = hidDeviceOverridesEnabled(in: systemReg) ? "Compatibility mode" : "Wine default"
        }
        if let markerFnToggle = markerEnabledValue("fn_toggle", in: marker) {
            values["fnToggle"] = markerFnToggle
        } else if let fnToggle = enabledValue(plist["IsFnToggleEnabled"]) {
            values["fnToggle"] = fnToggle
        }
        if let markerFastMath = markerEnabledValue("moltenvk_fast_math", in: marker) {
            values["fastMath"] = markerFastMath
        } else if let fastMath = enabledValue(plist["FASTMATH"]) {
            values["fastMath"] = fastMath
        }
        if let markerHUD = markerEnabledValue("metal_hud", in: marker) {
            values["hud"] = markerHUD
        } else if let hud = enabledValue(plist["METAL_HUD"]) {
            values["hud"] = hud
        }
        if let markerSpatial = markerEnabledValue("dxmt_metalfx_spatial", in: marker) {
            values["dxmtSpatial"] = markerSpatial
        } else if !mo2Bat.isEmpty {
            values["dxmtSpatial"] = mo2Bat.contains("DXMT_METALFX_SPATIAL_SWAPCHAIN=1") ? "Enabled" : "Disabled"
        }
        if let markerLog = markerValue("dxmt_log", in: marker), !markerLog.isEmpty {
            values["dxmtLog"] = markerLog == "default" ? "Default" : markerLog
        } else if !mo2Bat.isEmpty {
            values["dxmtLog"] = batchValue(mo2Bat, key: "DXMT_LOG_LEVEL") ?? "Default"
        }
        if let markerScale = markerValue("dxmt_scale", in: marker), !markerScale.isEmpty {
            values["dxmtScale"] = markerScale
        } else if !dxmtConf.isEmpty {
            values["dxmtScale"] = configValue(dxmtConf, key: "d3d11.metalSpatialUpscaleFactor") ?? "Default (2.0)"
        } else if detectedRenderer == "DXMT" {
            values["dxmtScale"] = "Default (2.0)"
        }
        if let markerDXVKHud = markerValue("dxvk_hud", in: marker), !markerDXVKHud.isEmpty {
            values["dxvkHud"] = markerDXVKHud == "default" ? "Default" : markerDXVKHud
        } else if !dxvkConf.isEmpty {
            values["dxvkHud"] = configValue(dxvkConf, key: "dxvk.hud") ?? "Default"
        } else if detectedRenderer == "DXVK" {
            values["dxvkHud"] = "Default"
        }
        if let reticleFix = markerEnabledValue("reticle_fix", in: marker) {
            values["reticleFix"] = reticleFix
        }
        if let extraWinetricks = markerValue("extra_winetricks", in: marker) {
            values["extraWinetricks"] = extraWinetricks
        }
        if !userReg.isEmpty {
            values["wineVirtualDesktop"] = wineVirtualDesktopEnabled(in: userReg) ? "Enabled" : "Disabled"
            if let displayMode = markerValue("display_mode", in: marker), !displayMode.isEmpty {
                values["displayMode"] = displayMode
            } else if managedWineDisplayEnabled(in: userReg) {
                values["displayMode"] = "forced"
            }

            if let displayResolution = markerValue("display_resolution", in: marker), !displayResolution.isEmpty {
                values["displayResolution"] = displayResolution
                values["wineDisplay"] = displayResolutionLabel(from: displayResolution)
            } else if let virtualDesktopResolution = wineVirtualDesktopResolution(in: userReg) {
                values["displayResolution"] = virtualDesktopResolution
                values["wineDisplay"] = displayResolutionLabel(from: virtualDesktopResolution)
            } else if managedWineDisplayEnabled(in: userReg), let preflightResolution = preflightGameResolution {
                values["displayResolution"] = preflightResolution
                values["wineDisplay"] = displayResolutionLabel(from: preflightResolution)
            }
        }
        if let preflight {
            let currentLetter = driveLetter(from: preflight.wineDriveLetter)
            let driveLink = prefix.appendingPathComponent("dosdevices/\(currentLetter.lowercased()):")
            if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: driveLink.path) {
                values["driveMapping"] = "\(currentLetter): -> \(destination)"
            } else if currentLetter == "Z" {
                values["driveMapping"] = "Z: -> /"
            } else {
                values["driveMapping"] = "Missing"
            }
        }
        return values
    }

    private func applyExistingWrapperSettingsIfNeeded() {
        guard outputAppExists else {
            appliedWrapperSettingsPath = nil
            existingWrapperSettingsDetected = false
            return
        }
        guard appliedWrapperSettingsPath != outputAppPath else { return }
        let settings = currentManagedSettings()
        apply(settings: settings)
        appliedWrapperSettingsPath = outputAppPath
        existingWrapperSettingsDetected = hasDetectedWrapperSettings(settings)
    }

    private func hasDetectedWrapperSettings(_ settings: [String: String]) -> Bool {
        if let engine = settings["engine"], engine != "Unknown" {
            return true
        }
        if let renderer = settings["renderer"], renderer != "Unknown" {
            return true
        }
        if settings["hidDevices"] != nil {
            return true
        }
        if settings["fnToggle"] != nil {
            return true
        }
        if settings["reticleFix"] != nil || settings["extraWinetricks"] != nil {
            return true
        }
        return false
    }

    private func apply(settings: [String: String]) {
        switch settings["engine"] {
        case "Wine Sikarugir 10.0":
            engine = SetupConfiguration.sikarugir10Engine
        case "Wine CX 24.0.7":
            engine = SetupConfiguration.defaultEngine
        default:
            break
        }

        switch settings["renderer"] {
        case "DXVK":
            renderer = "dxvk"
            applyReticleFix = false
        case "DXMT":
            renderer = "dxmt"
        case "D3DMetal":
            renderer = "d3dmetal"
        default:
            break
        }

        if let fastMath = settings["fastMath"] {
            moltenVKFastMath = fastMath == "Enabled"
        }
        if let esync = settings["esync"] {
            wineESync = esync == "Enabled"
        }
        if let msync = settings["msync"] {
            wineMSync = msync == "Enabled"
        }
        if let hidDevices = settings["hidDevices"] {
            enableHIDDevices = hidDevices == "Compatibility mode" || hidDevices == "Enabled"
        }
        if let fnToggle = settings["fnToggle"] {
            enableFnToggle = fnToggle == "Enabled"
        }
        if let hud = settings["hud"] {
            metalHUD = hud == "Enabled"
        }
        if let spatial = settings["dxmtSpatial"] {
            dxmtMetalFXSpatial = spatial == "Enabled"
        }
        if let scale = settings["dxmtScale"], !scale.hasPrefix("Default") {
            dxmtMetalFXScaleFactor = scale
        } else if settings["dxmtScale"] != nil {
            dxmtMetalFXScaleFactor = ""
        }
        if let logLevel = settings["dxmtLog"], logLevel != "Default" {
            dxmtLogLevel = logLevel.lowercased()
        } else if settings["dxmtLog"] != nil {
            dxmtLogLevel = "default"
        }
        if let hud = settings["dxvkHud"], hud != "Default" {
            dxvkHUD = hud
        } else if settings["dxvkHud"] != nil {
            dxvkHUD = "default"
        }
        if let mode = settings["displayMode"] {
            displayMode = (mode == "forced" || mode == "setCustom") ? "forced" : "defaultWine"
        }
        if let resolution = settings["displayResolution"] {
            applyDisplayResolution(resolution)
        }
        if let reticleFix = settings["reticleFix"] {
            applyReticleFix = reticleFix == "Enabled"
        }
        if let detectedExtraWinetricks = settings["extraWinetricks"] {
            extraWinetricks = detectedExtraWinetricks
        }
    }

    private var winetricksMarkersInstalled: Bool {
        let markers = URL(fileURLWithPath: outputAppPath)
            .appendingPathComponent("Contents/SharedSupport/.stalker-gamma-sikarugir-markers")
        return FileManager.default.fileExists(atPath: markers.appendingPathComponent("winetricks-corefonts.done").path)
            && FileManager.default.fileExists(atPath: markers.appendingPathComponent("winetricks-vcrun2022.done").path)
            && FileManager.default.fileExists(atPath: markers.appendingPathComponent("winetricks-directx.done").path)
    }

    private func currentUserRegistryText() -> String? {
        let app = URL(fileURLWithPath: outputAppPath)
        let candidates = [
            app.appendingPathComponent("Contents/SharedSupport/prefix/user.reg"),
            app.appendingPathComponent("Contents/drive_c/../user.reg")
        ]
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            let text = readText(candidate)
            if !text.isEmpty {
                return text
            }
        }
        return nil
    }

    private func missingDllOverrides(in overrides: [String: String]) -> [String] {
        return requiredDllOverrides.filter { name in
            overrides[name.lowercased()] != "native,builtin"
        }
    }

    private func currentDllOverrides(in registry: String) -> [String: String] {
        var inSection = false
        var values: [String: String] = [:]

        for line in registry.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let section = registrySectionName(trimmed) {
                inSection = section == #"Software\\Wine\\DllOverrides"#
                continue
            }
            guard inSection else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0]
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                .trimmingCharacters(in: CharacterSet(charactersIn: "*"))
                .lowercased()
            let value = parts[1]
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                .lowercased()
            values[key] = value
        }

        return values
    }

    private func hidDeviceOverridesEnabled(in registry: String) -> Bool {
        var inSection = false
        var values: [String: String] = [:]

        for line in registry.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let section = registrySectionName(trimmed) {
                inSection = section == #"System\\CurrentControlSet\\Services\\winebus"#
                continue
            }
            guard inSection else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            values[key] = String(parts[1]).lowercased()
        }

        return values["DisableHidraw"] == "dword:00000000"
            && values["DisableInput"] == "dword:00000000"
            && values["Enable SDL"] == "dword:00000000"
            && values["Map Controllers"] == "dword:00000000"
    }

    private func wineVirtualDesktopEnabled(in registry: String) -> Bool {
        registryValue(in: registry, section: #"Software\\Wine\\Explorer"#, key: "Desktop") == "Default"
    }

    private func wineVirtualDesktopResolution(in registry: String) -> String? {
        registryValue(in: registry, section: #"Software\\Wine\\Explorer\\Desktops"#, key: "Default")
    }

    private func managedWineDisplayEnabled(in registry: String) -> Bool {
        registryValue(in: registry, section: #"Software\\Wine\\Mac Driver"#, key: "RetinaMode") == "n"
            && registryValue(in: registry, section: #"Control Panel\\Desktop"#, key: "LogPixels") == "dword:00000060"
            && registryValue(in: registry, section: #"Control Panel\\Desktop"#, key: "Win8DpiScaling") == "dword:00000000"
    }

    private var preflightGameResolution: String? {
        guard let width = preflight?.gameResolutionWidth,
              let height = preflight?.gameResolutionHeight else {
            return nil
        }
        return "\(width)x\(height)"
    }

    private func applyDisplayResolution(_ resolution: String) {
        let normalized = resolution
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        switch normalized {
        case "1920x1080", "2560x1440", "3840x2160":
            displayResolutionMode = normalized
        default:
            let parts = normalized.split(separator: "x", maxSplits: 1)
            guard parts.count == 2,
                  Int(parts[0]) != nil,
                  Int(parts[1]) != nil else {
                return
            }
            if normalized == preflightGameResolution {
                displayResolutionMode = "detected"
            } else {
                displayResolutionMode = "custom"
                customDisplayResolutionWidth = String(parts[0])
                customDisplayResolutionHeight = String(parts[1])
            }
        }
    }

    private func displayResolutionLabel(from resolution: String) -> String {
        let normalized = resolution
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        let parts = normalized.split(separator: "x", maxSplits: 1)
        guard parts.count == 2 else { return resolution }
        return "\(parts[0]) x \(parts[1])"
    }

    private func registryValue(in registry: String, section: String, key: String) -> String? {
        var inSection = false

        for line in registry.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if registrySectionName(trimmed) == section {
                inSection = true
                continue
            }
            if registrySectionName(trimmed) != nil {
                inSection = false
                continue
            }
            guard inSection else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let currentKey = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            guard currentKey == key else { continue }
            return parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }

        return nil
    }

    private func registrySectionName(_ line: String) -> String? {
        guard line.hasPrefix("["),
              let end = line.firstIndex(of: "]") else {
            return nil
        }
        return String(line[line.index(after: line.startIndex)..<end])
    }

    private func updateDetectedDisplayDefaults() {
        detectedDisplay = MacDisplaySettings.detectMainDisplay()
        if displayResolutionMode == "detected",
           preflight?.gameResolutionWidth == nil || preflight?.gameResolutionHeight == nil {
            displayResolutionMode = "1920x1080"
            return
        }
        guard displayMode == "forced",
              displayResolutionMode == "1920x1080",
              preflight?.gameResolutionWidth != nil,
              preflight?.gameResolutionHeight != nil else {
            return
        }
        displayResolutionMode = "detected"
    }

    private func readText(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private func boolLike(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.intValue != 0 }
        if let value = value as? String { return value == "1" || value.lowercased() == "true" }
        return false
    }

    private func enabledValue(_ value: Any?) -> String? {
        guard value != nil else { return nil }
        return boolLike(value) ? "Enabled" : "Disabled"
    }

    private func rendererName(from plist: [String: Any], marker: String) -> String {
        if boolLike(plist["DXVK"]) { return "DXVK" }
        if boolLike(plist["DXMT"]) { return "DXMT" }
        if boolLike(plist["D3DMETAL"]) { return "D3DMetal" }
        switch markerValue("renderer", in: marker) {
        case "dxvk":
            return "DXVK"
        case "dxmt":
            return "DXMT"
        case "d3dmetal":
            return "D3DMetal"
        case let value? where !value.isEmpty:
            return value
        default:
            break
        }
        return "Unknown"
    }

    private func engineLabel(from marker: String) -> String {
        for line in marker.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("engine=") else { continue }
            let value = String(trimmed.dropFirst("engine=".count))
            if value == SetupConfiguration.sikarugir10Engine {
                return "Wine Sikarugir 10.0"
            }
            if value == SetupConfiguration.defaultEngine {
                return "Wine CX 24.0.7"
            }
            return value
        }
        return "Unknown"
    }

    private func markerValue(_ key: String, in marker: String) -> String? {
        let prefix = "\(key)="
        return marker
            .split(whereSeparator: \.isNewline)
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    private func markerEnabledValue(_ key: String, in marker: String) -> String? {
        guard let value = markerValue(key, in: marker) else { return nil }
        switch value.lowercased() {
        case "enabled", "true", "1":
            return "Enabled"
        case "disabled", "false", "0":
            return "Disabled"
        default:
            return nil
        }
    }

    private func configValue(_ text: String, key: String) -> String? {
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key)") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                return parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func batchValue(_ text: String, key: String) -> String? {
        let trimSet = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\""))
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let plainPrefix = "set \(key)="
            if trimmed.lowercased().hasPrefix(plainPrefix.lowercased()) {
                return String(trimmed.dropFirst(plainPrefix.count)).trimmingCharacters(in: trimSet)
            }
            let quotedPrefix = #"set "\#(key)="#
            if trimmed.lowercased().hasPrefix(quotedPrefix.lowercased()) {
                return String(trimmed.dropFirst(quotedPrefix.count)).trimmingCharacters(in: trimSet)
            }
        }
        return nil
    }

    private func driveLetter(from value: String) -> String {
        String(value.trimmingCharacters(in: CharacterSet(charactersIn: ":")).prefix(1)).uppercased()
    }

    private func runEngine(
        command: String,
        request: SetupRequest,
        extraArguments: [String] = [],
        stream: Bool
    ) async throws -> ToolResult {
        let engine = engineURL
        let requestURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gamma-setup-engine-\(UUID().uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(request).write(to: requestURL, options: .atomic)

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = engine
            process.arguments = [command, "--request-file", requestURL.path] + extraArguments
            process.currentDirectoryURL = engine.deletingLastPathComponent()

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let buffer = OutputBuffer()
            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                buffer.append(data)
                guard stream, let text = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    self?.appendLog(text)
                }
            }

            process.terminationHandler = { [process] proc in
                process.terminationHandler = nil
                handle.readabilityHandler = nil
                try? FileManager.default.removeItem(at: requestURL)
                let remaining = handle.readDataToEndOfFile()
                if !remaining.isEmpty {
                    buffer.append(remaining)
                    if stream, let text = String(data: remaining, encoding: .utf8) {
                        Task { @MainActor in
                            self.appendLog(text)
                        }
                    }
                }
                let output = buffer.stringValue()
                continuation.resume(returning: ToolResult(output: output, exitCode: proc.terminationStatus))
            }

            do {
                try process.run()
            } catch {
                handle.readabilityHandler = nil
                try? FileManager.default.removeItem(at: requestURL)
                continuation.resume(throwing: error)
            }
        }
    }

    private func appendLog(_ text: String) {
        pendingEngineEventText += text
        var lines = pendingEngineEventText.components(separatedBy: "\n")
        pendingEngineEventText = lines.popLast() ?? ""
        for line in lines where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if handleEngineEventLine(line) {
                continue
            }
            logText += line + "\n"
        }
    }

    private func handleEngineEventLine(_ line: String) -> Bool {
        guard let data = line.data(using: .utf8),
              let event = try? JSONDecoder().decode(SetupEngineEvent.self, from: data) else {
            return false
        }
        receivedInstallStageEvents = true

        switch event.type {
        case .log:
            let message = event.message ?? ""
            guard !message.isEmpty else { return true }
            logText += "==> \(message)\n"
            statusText = message
            progress = min(progress + 0.07, 0.95)
        case .artifact:
            if event.message == "Log file", let path = event.path {
                savedLogPath = path
                logText += "Log file: \(path)\n"
            }
        case .completed:
            if let message = event.message, !message.isEmpty {
                logText += "\(message)\n"
            }
        case .stageStarted, .stageFinished, .stageFailed:
            guard let stage = event.stage, let index = installStageIndex(for: stage) else {
                return true
            }
            switch event.type {
            case .stageStarted:
                installStageIndex = index
                statusText = installStageName(at: index)
            case .stageFinished:
                installStageCompletedIndex = max(installStageCompletedIndex, index)
                if installStageIndex == index {
                    installStageIndex = -1
                }
                progress = max(progress, Double(index + 1) / Double(installStageCount))
            case .stageFailed:
                installStageIndex = index
                installFailed = true
                if let message = event.message {
                    logText += "error: \(message)\n"
                }
            default:
                break
            }
        }
        return true
    }

    private func installStageIndex(for stage: SetupEngineStage) -> Int? {
        switch stage {
        case .wrapper: return 0
        case .engine: return 1
        case .prefix: return 2
        case .driveMapping: return 3
        case .winetricks: return 4
        case .finalize: return 5
        }
    }

    private func inferredInstallStageIndex(from status: String) -> Int {
        let status = status.lowercased()
        if status.contains("creating sikarugir wrapper")
            || status.contains("rebuilding")
            || status.contains("configuring existing")
            || status.contains("installing anomaly app icon")
            || status.contains("restoring sikarugir app frameworks")
            || status.contains("configuring sikarugir app plist") {
            return 0
        }
        if status.contains("installing sikarugir engine") || status.contains("usvfs") {
            return 1
        }
        if status.contains("initializing sikarugir wine prefix")
            || status.contains("configuring wine macos graphics driver") {
            return 2
        }
        if status.contains("configuring wine drive mapping")
            || status.contains("modorganizer.ini") {
            return 3
        }
        if status.contains("winetricks")
            || status.contains("corefonts")
            || status.contains("vcrun2022")
            || status.contains("directx")
            || status.contains("dll overrides") {
            return 4
        }
        if status.contains("wine hid")
            || status.contains("creating dxmt")
            || status.contains("creating dxvk")
            || status.contains("modorganizer launch batch")
            || status.contains("common fix")
            || status.contains("normalizing")
            || status.contains("registering")
            || status.contains("summary")
            || status.contains("touching") {
            return 5
        }
        return installStageIndex
    }

    private var installStageCount: Int {
        6
    }

    private func installStageName(at index: Int) -> String {
        switch index {
        case 0: return "wrapper creation"
        case 1: return "engine installation"
        case 2: return "prefix initialization"
        case 3: return "drive mapping"
        case 4: return "winetricks"
        case 5: return "finalization"
        default: return "setup"
        }
    }
}
