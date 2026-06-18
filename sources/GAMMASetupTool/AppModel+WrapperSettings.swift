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

    func currentManagedSettings() -> [String: String] {
        let app = URL(fileURLWithPath: outputAppPath)
        let contents = app.appendingPathComponent("Contents")
        let sharedSupport = contents.appendingPathComponent("SharedSupport")
        let prefix = sharedSupport.appendingPathComponent("prefix")
        let driveC = prefix.appendingPathComponent("drive_c")
        let info = contents.appendingPathComponent("Info.plist")
        let plist = NSDictionary(contentsOf: info) as? [String: Any] ?? [:]
        let plistProgramBatch = (plist["Program Name and Path"] as? String).map(normalizedBatchPath) ?? "/mo2.bat"
        let activeBatch = readText(driveC.appendingPathComponent(plistProgramBatch.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
        let dxvkConf = readText(driveC.appendingPathComponent("dxvk.conf"))
        let dxmtConf = readText(driveC.appendingPathComponent("dxmt.conf"))
        let systemReg = readText(prefix.appendingPathComponent("system.reg"))
        let userReg = readText(prefix.appendingPathComponent("user.reg"))
        let marker = readText(sharedSupport.appendingPathComponent(".stalker-gamma-sikarugir-setup"))
        let cliCustomCommands = plist["CLI Custom Commands"] as? String ?? ""

        var values: [String: String] = [:]
        values["engine"] = engineLabel(from: marker)
        values["programBatch"] = plistProgramBatch
        let legacyLaunchExecutable = plistProgramBatch == "/mo2.bat" ? (preflight?.mo2Path ?? plistProgramBatch) : plistProgramBatch
        values["launchExecutable"] = markerValue("launch_executable", in: marker) ?? legacyLaunchExecutable
        values["launchUsesModOrganizerEnvironment"] = markerValue("launch_uses_modorganizer_environment", in: marker) ?? "false"
        let detectedRenderer = rendererName(from: plist, marker: marker)
        values["renderer"] = detectedRenderer
        if let esync = enabledValue(plist["WINEESYNC"]) {
            values["esync"] = esync
        } else if let markerESync = markerEnabledValue("wine_esync", in: marker) {
            values["esync"] = markerESync
        }
        if let msync = enabledValue(plist["WINEMSYNC"]) {
            values["msync"] = msync
        } else if let markerMSync = markerEnabledValue("wine_msync", in: marker) {
            values["msync"] = markerMSync
        }
        if !systemReg.isEmpty {
            values["hidDevices"] = hidDeviceOverridesEnabled(in: systemReg) ? "Compatibility mode" : "Wine default"
        } else if let mouseInput = markerValue("mouse_input", in: marker) ?? markerValue("controller_input", in: marker) {
            values["hidDevices"] = mouseInput == "compatibility" ? "Compatibility mode" : "Wine default"
        }
        if let fnToggle = enabledValue(plist["IsFnToggleEnabled"]) {
            values["fnToggle"] = fnToggle
        } else if let markerFnToggle = markerEnabledValue("fn_toggle", in: marker) {
            values["fnToggle"] = markerFnToggle
        }
        if let fastMath = enabledValue(plist["FASTMATH"]) {
            values["fastMath"] = fastMath
        } else if let markerFastMath = markerEnabledValue("moltenvk_fast_math", in: marker) {
            values["fastMath"] = markerFastMath
        }
        if let hud = enabledValue(plist["METAL_HUD"]) {
            values["hud"] = hud
        } else if let markerHUD = markerEnabledValue("metal_hud", in: marker) {
            values["hud"] = markerHUD
        }
        if cliCustomCommands.contains("DXMT_METALFX_SPATIAL_SWAPCHAIN=1") {
            values["dxmtSpatial"] = "Enabled"
        } else if let markerSpatial = markerEnabledValue("dxmt_metalfx_spatial", in: marker) {
            values["dxmtSpatial"] = markerSpatial
        } else if !activeBatch.isEmpty {
            values["dxmtSpatial"] = activeBatch.contains("DXMT_METALFX_SPATIAL_SWAPCHAIN=1") ? "Enabled" : "Disabled"
        }
        if let plistLog = commandValue(cliCustomCommands, key: "DXMT_LOG_LEVEL") {
            values["dxmtLog"] = plistLog
        } else if let markerLog = markerValue("dxmt_log", in: marker), !markerLog.isEmpty {
            values["dxmtLog"] = markerLog == "default" ? "Default" : markerLog
        } else if !activeBatch.isEmpty {
            values["dxmtLog"] = batchValue(activeBatch, key: "DXMT_LOG_LEVEL") ?? "Default"
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
            if managedWineDisplayEnabled(in: userReg) {
                values["displayMode"] = "forced"
            } else if let displayMode = markerValue("display_mode", in: marker), !displayMode.isEmpty {
                values["displayMode"] = displayMode
            }

            if let virtualDesktopResolution = wineVirtualDesktopResolution(in: userReg) {
                values["displayResolution"] = virtualDesktopResolution
                values["wineDisplay"] = displayResolutionLabel(from: virtualDesktopResolution)
            } else if managedWineDisplayEnabled(in: userReg), let preflightResolution = preflightGameResolution {
                values["displayResolution"] = preflightResolution
                values["wineDisplay"] = displayResolutionLabel(from: preflightResolution)
            } else if let displayResolution = markerValue("display_resolution", in: marker), !displayResolution.isEmpty {
                values["displayResolution"] = displayResolution
                values["wineDisplay"] = displayResolutionLabel(from: displayResolution)
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

    // MARK: - Existing Wrapper Detection

    func applyExistingWrapperSettingsIfNeeded() {
        guard outputAppExists else {
            if appliedWrapperSettingsPath != nil {
                resetWrapperDerivedSettings()
            }
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

    func targetAppPathDidChange() {
        guard appliedWrapperSettingsPath != outputAppPath else { return }
        if appliedWrapperSettingsPath != nil {
            resetWrapperDerivedSettings()
        }
        appliedWrapperSettingsPath = nil
        existingWrapperSettingsDetected = false
        applyExistingWrapperSettingsIfNeeded()
    }

    private func resetWrapperDerivedSettings() {
        engine = SetupConfiguration.defaultEngine
        renderer = "d3dmetal"
        wineESync = true
        wineMSync = true
        enableHIDDevices = false
        enableFnToggle = false
        moltenVKFastMath = false
        metalHUD = false
        dxmtMetalFXSpatial = false
        dxmtMetalFXScaleFactor = ""
        dxmtLogLevel = "default"
        dxvkHUD = "default"
        programBatch = "/mo2.bat"
        launchBatches = []
        extraWinetricks = ""
        applyReticleFix = true
        driveMappingMode = "preserve"
        displayMode = "forced"
        displayResolutionMode = "detected"
        customDisplayResolutionWidth = ""
        customDisplayResolutionHeight = ""
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
            engine = SetupConfiguration.crossOverEngine
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
        if let detectedProgramBatch = settings["programBatch"] {
            programBatch = normalizedBatchPath(detectedProgramBatch)
        }
        if programBatch != "/mo2.bat" {
            if let executablePath = settings["launchExecutable"], executablePath != programBatch {
                let executable = URL(fileURLWithPath: executablePath)
                launchBatches = [LaunchBatch(
                    batchPath: programBatch,
                    executablePath: executablePath,
                    workingDirectory: executable.deletingLastPathComponent().path,
                    usesModOrganizerEnvironment: settings["launchUsesModOrganizerEnvironment"] == "true"
                )]
            } else {
                programBatch = "/mo2.bat"
                launchBatches = []
            }
        }
    }

    // MARK: - Launch Batch Helpers

    func normalizedBatchPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "/mo2.bat" }
        return trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
    }

    func uniqueBatchPath(for executable: URL) -> String {
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

    // MARK: - Registry And Marker Parsing

    var winetricksMarkersInstalled: Bool {
        let markers = URL(fileURLWithPath: outputAppPath)
            .appendingPathComponent("Contents/SharedSupport/.stalker-gamma-sikarugir-markers")
        return FileManager.default.fileExists(atPath: markers.appendingPathComponent("winetricks-corefonts.done").path)
            && FileManager.default.fileExists(atPath: markers.appendingPathComponent("winetricks-vcrun2022.done").path)
            && FileManager.default.fileExists(atPath: markers.appendingPathComponent("winetricks-directx.done").path)
    }

    func currentUserRegistryText() -> String? {
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

    func missingDllOverrides(in overrides: [String: String]) -> [String] {
        return requiredDllOverrides.filter { name in
            overrides[name.lowercased()] != "native,builtin"
        }
    }

    func currentDllOverrides(in registry: String) -> [String: String] {
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

    func updateDetectedDisplayDefaults() {
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
            if value == SetupConfiguration.crossOverEngine {
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

    private func commandValue(_ text: String, key: String) -> String? {
        let prefix = "\(key)="
        return text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    private func driveLetter(from value: String) -> String {
        String(value.trimmingCharacters(in: CharacterSet(charactersIn: ":")).prefix(1)).uppercased()
    }
}
