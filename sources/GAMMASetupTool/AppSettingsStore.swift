import Foundation

struct AppSettings: Codable {
    var gammaPath: String
}

enum AppSettingsStore {
    static func defaultSettingsURL(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("gamma-setup-tool", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    static func loadManualModOrganizerPath(from settingsURL: URL?) -> String {
        guard let settingsURL,
              let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return ""
        }

        let gammaPath = settings.gammaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gammaPath.isEmpty else { return "" }
        return URL(fileURLWithPath: gammaPath).appendingPathComponent("ModOrganizer.exe").path
    }

    static func save(gammaPath: String, to settingsURL: URL?) throws {
        guard let settingsURL else { return }
        try FileManager.default.createDirectory(
            at: settingsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let settings = AppSettings(gammaPath: gammaPath)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: settingsURL, options: .atomic)
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
}
