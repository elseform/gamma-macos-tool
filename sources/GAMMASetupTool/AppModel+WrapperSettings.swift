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
        let batchURL = driveC.appendingPathComponent(plistProgramBatch.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        let activeBatch = readText(batchURL)
        let userReg = readText(prefix.appendingPathComponent("user.reg"))

        var values: [String: String] = [:]
        values["engine"] = engineLabel(fromWineVersion: readText(sharedSupport.appendingPathComponent("wine/version")))
        values["programBatch"] = plistProgramBatch
        values["renderer"] = rendererName(from: plist)
        values["launchUsesModOrganizerEnvironment"] = activeBatch.localizedCaseInsensitiveContains("QT_OPENGL") ? "true" : "false"

        if plistProgramBatch == "/mo2.bat" {
            values["launchExecutable"] = preflight?.mo2Path ?? nativeLaunchExecutable(from: activeBatch, prefix: prefix) ?? plistProgramBatch
        } else {
            values["launchExecutable"] = nativeLaunchExecutable(from: activeBatch, prefix: prefix) ?? plistProgramBatch
        }

        if !userReg.isEmpty {
            if managedWineDisplayEnabled(in: userReg) {
                values["displayMode"] = "forced"
                if let virtualDesktopResolution = wineVirtualDesktopResolution(in: userReg) {
                    values["displayResolution"] = virtualDesktopResolution
                    values["wineDisplay"] = displayResolutionLabel(from: virtualDesktopResolution)
                } else {
                    values["wineDisplay"] = "Forced"
                }
            } else {
                values["displayMode"] = "defaultWine"
                values["wineDisplay"] = "Default Wine"
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

        values["usvfs"] = usvfsBinariesMatchInstalledWrapper() ? "Update binaries" : "Missing or stale"
        values["gptk4"] = gptk4PayloadMatchesInstalledWrapper(app: app) ? "Install" : "Not installed"
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

    func inferredModOrganizerPathFromCurrentWrapper() -> String? {
        let settings = currentManagedSettings()
        guard let executable = settings["launchExecutable"] else { return nil }
        return AppSettingsStore.isValidModOrganizerExecutable(executable) ? executable : nil
    }

    private func resetWrapperDerivedSettings() {
        let defaults = SetupConfiguration()
        engine = defaults.engine
        renderer = defaults.renderer
        updateUSVFS = defaults.updateUSVFS
        installGPTK4Binaries = defaults.installGPTK4Binaries
        programBatch = defaults.programBatch
        launchBatches = defaults.launchBatches
        driveMappingMode = defaults.driveMappingMode
        displayMode = defaults.displayMode
        displayResolutionMode = defaults.displayResolutionMode
        customDisplayResolutionWidth = defaults.customDisplayResolutionWidth
        customDisplayResolutionHeight = defaults.customDisplayResolutionHeight
    }

    private func hasDetectedWrapperSettings(_ settings: [String: String]) -> Bool {
        if let engine = settings["engine"], engine != "Unknown" {
            return true
        }
        if let renderer = settings["renderer"], renderer != "Unknown" {
            return true
        }
        if settings["programBatch"] != nil {
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
        case "DXMT":
            renderer = "dxmt"
        case "D3DMetal":
            renderer = "d3dmetal"
        default:
            break
        }

        if let mode = settings["displayMode"] {
            displayMode = mode == "forced" ? "forced" : "defaultWine"
        }
        if let resolution = settings["displayResolution"] {
            applyDisplayResolution(resolution)
        }
        if let gptk4 = settings["gptk4"] {
            installGPTK4Binaries = gptk4 == "Install"
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

    // MARK: - Registry And File Parsing

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
        return requiredDllOverrides.compactMap { name, expected in
            guard let actual = overrides[name.lowercased()] else { return name }
            if actual == expected { return nil }
            if expected == "native", actual == "native,builtin" { return nil }
            return name
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

    private func wineVirtualDesktopResolution(in registry: String) -> String? {
        registryValue(in: registry, section: #"Software\\Wine\\Explorer\\Desktops"#, key: "Default")
    }

    private func managedWineDisplayEnabled(in registry: String) -> Bool {
        registryValue(in: registry, section: #"Software\\Wine\\Mac Driver"#, key: "RetinaMode") == "n"
            && registryValue(in: registry, section: #"Control Panel\\Desktop"#, key: "LogPixels") == "dword:00000060"
            && registryValue(in: registry, section: #"Control Panel\\Desktop"#, key: "Win8DpiScaling") == "dword:00000000"
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
            if let detectedDisplay,
               Int(parts[0]) == detectedDisplay.backingWidth,
               Int(parts[1]) == detectedDisplay.backingHeight {
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
    }

    private func readText(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private func boolLike(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.intValue != 0 }
        if let value = value as? String { return value == "1" || value.lowercased() == "true" }
        return false
    }

    private func rendererName(from plist: [String: Any]) -> String {
        if boolLike(plist["DXVK"]) { return "DXVK" }
        if boolLike(plist["DXMT"]) { return "DXMT" }
        if boolLike(plist["D3DMETAL"]) { return "D3DMetal" }
        return "Unknown"
    }

    private func engineLabel(fromWineVersion version: String) -> String {
        let normalized = version.lowercased()
        if normalized.contains("sikarugir 10.0") && normalized.contains("revision 6") {
            return "Wine Sikarugir 10.0"
        }
        if normalized.contains("24.0.7") && (normalized.contains("cx") || normalized.contains("crossover")) {
            return "Wine CX 24.0.7"
        }
        return version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown" : version.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nativeLaunchExecutable(from batch: String, prefix: URL) -> String? {
        guard let windowsPath = windowsExecutablePath(from: batch) else { return nil }
        return nativePath(fromWindowsPath: windowsPath, prefix: prefix)
    }

    private func windowsExecutablePath(from batch: String) -> String? {
        for line in batch.split(whereSeparator: \.isNewline).map(String.init).reversed() {
            guard line.localizedCaseInsensitiveContains("start") else { continue }
            let quoted = quotedSegments(in: line)
            if let exe = quoted.last(where: { $0.lowercased().hasSuffix(".exe") }) {
                return exe
            }
        }
        return nil
    }

    private func quotedSegments(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuote = false
        for character in text {
            if character == "\"" {
                if insideQuote {
                    result.append(current)
                    current = ""
                }
                insideQuote.toggle()
            } else if insideQuote {
                current.append(character)
            }
        }
        return result
    }

    private func nativePath(fromWindowsPath path: String, prefix: URL) -> String? {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        guard normalized.count >= 3,
              normalized[normalized.index(after: normalized.startIndex)] == ":" else {
            return nil
        }
        let letter = String(normalized.prefix(1)).lowercased()
        let relative = String(normalized.dropFirst(2)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if letter == "c" {
            return prefix.appendingPathComponent("drive_c").appendingPathComponent(relative).path
        }
        let link = prefix.appendingPathComponent("dosdevices/\(letter):")
        guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) else {
            return nil
        }
        return URL(fileURLWithPath: destination).appendingPathComponent(relative).path
    }

    private func usvfsBinariesMatchInstalledWrapper() -> Bool {
        guard let preflight,
              let source = bundledResourceDirectory("usvfs") else {
            return false
        }
        let mo2Dir = URL(fileURLWithPath: preflight.mo2Path).deletingLastPathComponent()
        for file in ["usvfs_x64.dll", "usvfs_proxy_x64.exe", "usvfs_x86.dll", "usvfs_proxy_x86.exe"] {
            let target = mo2Dir.appendingPathComponent(file)
            let bundled = source.appendingPathComponent(file)
            guard FileManager.default.fileExists(atPath: target.path),
                  FileManager.default.contentsEqual(atPath: target.path, andPath: bundled.path) else {
                return false
            }
        }
        return true
    }

    private func d3dMetalVersion(in app: URL) -> String {
        let versionURL = app
            .appendingPathComponent("Contents/Frameworks/renderer/d3dmetal/external/D3DMetal.framework/Resources/version.plist")
        guard let plist = NSDictionary(contentsOf: versionURL) as? [String: Any] else {
            return ""
        }
        return plist["CFBundleShortVersionString"] as? String ?? ""
    }

    private func gptk4PayloadMatchesInstalledWrapper(app: URL) -> Bool {
        guard d3dMetalVersion(in: app) == "4.0b1",
              let source = bundledResourceDirectory("gptk4/d3dmetal") else {
            return false
        }
        let target = app.appendingPathComponent("Contents/Frameworks/renderer/d3dmetal")
        return directoryPayloadMatches(source: source, target: target)
    }

    private func directoryPayloadMatches(source: URL, target: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: source.path),
              FileManager.default.fileExists(atPath: target.path),
              let enumerator = FileManager.default.enumerator(
                at: source,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
              ) else {
            return false
        }

        for case let sourceURL as URL in enumerator {
            let relative = String(sourceURL.path.dropFirst(source.path.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !relative.isEmpty else { continue }
            let targetURL = target.appendingPathComponent(relative)
            guard payloadEntryMatches(source: sourceURL, target: targetURL) else {
                return false
            }
        }
        return true
    }

    private func payloadEntryMatches(source: URL, target: URL) -> Bool {
        if isSymlink(source) {
            return (try? FileManager.default.destinationOfSymbolicLink(atPath: source.path))
                == (try? FileManager.default.destinationOfSymbolicLink(atPath: target.path))
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDir) else {
            return false
        }
        if isDir.boolValue {
            return FileManager.default.fileExists(atPath: target.path, isDirectory: &isDir) && isDir.boolValue
        }
        return FileManager.default.fileExists(atPath: target.path)
            && FileManager.default.contentsEqual(atPath: source.path, andPath: target.path)
    }

    private func bundledResourceDirectory(_ name: String) -> URL? {
        if let url = AppResources.bundle.resourceURL?.appendingPathComponent(name),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        if let url = Bundle.main.resourceURL?.appendingPathComponent(name),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            cwd.appendingPathComponent(name),
            cwd.appendingPathComponent("sources/GAMMASetupTool/Resources/\(name)"),
            cwd.appendingPathComponent("../../sources/GAMMASetupTool/Resources/\(name)")
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func driveLetter(from value: String) -> String {
        String(value.trimmingCharacters(in: CharacterSet(charactersIn: ":")).prefix(1)).uppercased()
    }
}
