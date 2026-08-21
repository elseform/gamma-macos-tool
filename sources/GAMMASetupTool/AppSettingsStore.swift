import Foundation

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct RecommendedSettings: Codable, Equatable {
    var engine: String
    var renderer: String
    var displayMode: String
    var driveMappingMode: String
    var compatibilityProfile: SetupCompatibilityProfile
    var updateUSVFS: Bool
    var installGPTK4Binaries: Bool
    var installDXMTBinaries: Bool
    var installDirectXBinaries: Bool
    var saveVerboseLog: Bool
    var winetricks: [String]
    var additionalWinetricks: String

    init(
        engine: String = SetupConfiguration.sikarugir10Engine,
        renderer: String = "d3dmetal",
        displayMode: String = "retinaOff",
        driveMappingMode: String = "preserve",
        compatibilityProfile: SetupCompatibilityProfile = .xrayD3DMetal,
        updateUSVFS: Bool = true,
        installGPTK4Binaries: Bool = true,
        installDXMTBinaries: Bool = false,
        installDirectXBinaries: Bool = false,
        saveVerboseLog: Bool = false,
        winetricks: [String] = SetupCompatibilityProfile.xrayD3DMetal.requiredVerbs,
        additionalWinetricks: String = ""
    ) {
        self.engine = engine
        self.renderer = renderer
        self.displayMode = displayMode
        self.driveMappingMode = driveMappingMode
        self.compatibilityProfile = compatibilityProfile
        self.updateUSVFS = updateUSVFS
        self.installGPTK4Binaries = installGPTK4Binaries
        self.installDXMTBinaries = installDXMTBinaries
        self.installDirectXBinaries = installDirectXBinaries
        self.saveVerboseLog = saveVerboseLog
        self.winetricks = winetricks
        self.additionalWinetricks = additionalWinetricks
    }

    enum CodingKeys: String, CodingKey {
        case engine
        case renderer
        case displayMode
        case driveMappingMode
        case compatibilityProfile
        case updateUSVFS
        case installGPTK4Binaries
        case installDXMTBinaries
        case installDirectXBinaries
        case saveVerboseLog
        case winetricks
        case additionalWinetricks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.engine = try container.decodeIfPresent(String.self, forKey: .engine) ?? SetupConfiguration.sikarugir10Engine
        self.renderer = try container.decodeIfPresent(String.self, forKey: .renderer) ?? "d3dmetal"
        self.displayMode = try container.decodeIfPresent(String.self, forKey: .displayMode) ?? "retinaOff"
        self.driveMappingMode = try container.decodeIfPresent(String.self, forKey: .driveMappingMode) ?? "preserve"
        self.compatibilityProfile = try container.decodeIfPresent(SetupCompatibilityProfile.self, forKey: .compatibilityProfile) ?? .xrayD3DMetal
        self.updateUSVFS = try container.decodeIfPresent(Bool.self, forKey: .updateUSVFS) ?? true
        self.installGPTK4Binaries = try container.decodeIfPresent(Bool.self, forKey: .installGPTK4Binaries) ?? true
        self.installDXMTBinaries = try container.decodeIfPresent(Bool.self, forKey: .installDXMTBinaries) ?? false
        self.installDirectXBinaries = try container.decodeIfPresent(Bool.self, forKey: .installDirectXBinaries) ?? false
        self.saveVerboseLog = try container.decodeIfPresent(Bool.self, forKey: .saveVerboseLog) ?? false
        self.winetricks = try container.decodeIfPresent([String].self, forKey: .winetricks) ?? SetupCompatibilityProfile.xrayD3DMetal.requiredVerbs
        self.additionalWinetricks = try container.decodeIfPresent(String.self, forKey: .additionalWinetricks) ?? ""
    }
}

struct AppSettings: Codable, Equatable {
    var gammaPath: String?
    var recommended: RecommendedSettings?

    init(gammaPath: String? = nil, recommended: RecommendedSettings? = nil) {
        self.gammaPath = gammaPath
        self.recommended = recommended
    }

    enum CodingKeys: String, CodingKey {
        case gammaPath
        case recommended
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.gammaPath = try container.decodeIfPresent(String.self, forKey: .gammaPath)
        self.recommended = try container.decodeIfPresent(RecommendedSettings.self, forKey: .recommended)
    }
}

enum AppSettingsStore {
    static let defaultInstallDirectory = NSString(string: "~/Applications").expandingTildeInPath

    static func defaultSettingsURL(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("gamma-setup-tool", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    static func defaultBundledSettingsURL() -> URL? {
        if let bundled = AppResources.bundle.url(forResource: "recommended-settings", withExtension: "json") {
            return bundled
        }
        if let mainBundled = Bundle.main.url(forResource: "recommended-settings", withExtension: "json") {
            return mainBundled
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourcePath = cwd.appendingPathComponent("sources/GAMMASetupTool/Resources/recommended-settings.json")
        if FileManager.default.fileExists(atPath: sourcePath.path) {
            return sourcePath
        }
        return nil
    }

    static func loadBundledRecommendedSettings() -> RecommendedSettings {
        guard let url = defaultBundledSettingsURL(),
              let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(RecommendedSettings.self, from: data) else {
            return RecommendedSettings()
        }
        return settings
    }

    static func loadSettings(from settingsURL: URL?) -> AppSettings {
        guard let settingsURL,
              let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    static func loadManualModOrganizerPath(from settingsURL: URL?) -> String {
        let settings = loadSettings(from: settingsURL)
        guard let gammaPath = settings.gammaPath?.trimmingCharacters(in: .whitespacesAndNewlines), !gammaPath.isEmpty else {
            return ""
        }
        return URL(fileURLWithPath: gammaPath).appendingPathComponent("ModOrganizer.exe").path
    }

    static func loadRecommendedSettings(from settingsURL: URL?) -> RecommendedSettings {
        loadSettings(from: settingsURL).recommended ?? loadBundledRecommendedSettings()
    }

    static func save(settings: AppSettings, to settingsURL: URL?) throws {
        guard let settingsURL else { return }
        try FileManager.default.createDirectory(
            at: settingsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: settingsURL, options: .atomic)
    }

    static func save(gammaPath: String, to settingsURL: URL?) throws {
        var settings = loadSettings(from: settingsURL)
        settings.gammaPath = gammaPath
        try save(settings: settings, to: settingsURL)
    }

    static func ensureSettingsFileExists(at settingsURL: URL?) {
        guard let settingsURL else { return }
        if !FileManager.default.fileExists(atPath: settingsURL.path) {
            let initialSettings = AppSettings(gammaPath: nil, recommended: nil)
            try? save(settings: initialSettings, to: settingsURL)
        }
    }

    static func detectedModOrganizerPath(in selectedFolder: URL, fileManager: FileManager = .default) -> String? {
        let direct = selectedFolder.appendingPathComponent("ModOrganizer.exe")
        if fileManager.fileExists(atPath: direct.path) {
            return direct.path
        }

        guard let children = try? fileManager.contentsOfDirectory(
            at: selectedFolder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for child in children {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let candidate = child.appendingPathComponent("ModOrganizer.exe")
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate.path
            }
        }
        return nil
    }

    static func isValidModOrganizerExecutable(_ path: String, fileManager: FileManager = .default) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let url = URL(fileURLWithPath: trimmed)
        return url.lastPathComponent.caseInsensitiveCompare("ModOrganizer.exe") == .orderedSame
            && fileManager.fileExists(atPath: url.path)
    }

}
