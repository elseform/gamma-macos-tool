import Foundation

final class AppSettingsStoreTests {
    func testManualGammaSelectionFindsDirectModOrganizer() throws {
        let temp = try makeTempDir("gamma-settings-direct")
        FileManager.default.createFile(atPath: temp.appendingPathComponent("ModOrganizer.exe").path, contents: Data())

        XCTAssertEqual(
            AppSettingsStore.detectedModOrganizerPath(in: temp),
            temp.appendingPathComponent("ModOrganizer.exe").path
        )
        try? FileManager.default.removeItem(at: temp)
    }

    func testManualGammaSelectionFindsNestedModOrganizer() throws {
        let temp = try makeTempDir("gamma-settings-nested")
        let gamma = temp.appendingPathComponent("GAMMA")
        try FileManager.default.createDirectory(at: gamma, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gamma.appendingPathComponent("ModOrganizer.exe").path, contents: Data())

        let actual = AppSettingsStore.detectedModOrganizerPath(in: temp)
            .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        let expected = gamma.appendingPathComponent("ModOrganizer.exe").standardizedFileURL.path
        XCTAssertEqual(actual, expected)
        try? FileManager.default.removeItem(at: temp)
    }

    func testManualGammaSelectionRejectsInvalidFolder() throws {
        let temp = try makeTempDir("gamma-settings-invalid")

        XCTAssertNil(AppSettingsStore.detectedModOrganizerPath(in: temp))
        try? FileManager.default.removeItem(at: temp)
    }

    func testModOrganizerValidationRequiresExecutableNameAndFile() throws {
        let temp = try makeTempDir("gamma-settings-mo2-validation")
        let mo2 = temp.appendingPathComponent("ModOrganizer.exe")
        let other = temp.appendingPathComponent("Other.exe")
        FileManager.default.createFile(atPath: mo2.path, contents: Data())
        FileManager.default.createFile(atPath: other.path, contents: Data())

        XCTAssertTrue(AppSettingsStore.isValidModOrganizerExecutable(mo2.path))
        XCTAssertFalse(AppSettingsStore.isValidModOrganizerExecutable(other.path))
        XCTAssertFalse(AppSettingsStore.isValidModOrganizerExecutable(temp.appendingPathComponent("ModOrganizer.exe").path + ".missing"))
        try? FileManager.default.removeItem(at: temp)
    }

    func testAppSettingsSaveAndLoadManualModOrganizerPath() throws {
        let temp = try makeTempDir("gamma-settings-save")
        let settingsURL = temp.appendingPathComponent("settings/settings.json")
        let gamma = temp.appendingPathComponent("GAMMA")
        try FileManager.default.createDirectory(at: gamma, withIntermediateDirectories: true)

        try AppSettingsStore.save(gammaPath: gamma.path, to: settingsURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: settingsURL.path))
        XCTAssertEqual(
            AppSettingsStore.loadManualModOrganizerPath(from: settingsURL),
            gamma.appendingPathComponent("ModOrganizer.exe").path
        )
        try? FileManager.default.removeItem(at: temp)
    }

    func testAppSettingsLoadIgnoresMissingAndMalformedFiles() throws {
        let temp = try makeTempDir("gamma-settings-malformed")
        let missing = temp.appendingPathComponent("missing.json")
        let malformed = temp.appendingPathComponent("malformed.json")
        try "{bad json}\n".write(to: malformed, atomically: true, encoding: .utf8)

        XCTAssertEqual(AppSettingsStore.loadManualModOrganizerPath(from: missing), "")
        XCTAssertEqual(AppSettingsStore.loadManualModOrganizerPath(from: malformed), "")
        XCTAssertEqual(AppSettingsStore.loadRecommendedSettings(from: missing), RecommendedSettings())
        XCTAssertEqual(AppSettingsStore.loadRecommendedSettings(from: malformed), RecommendedSettings())
        try? FileManager.default.removeItem(at: temp)
    }

    func testRecommendedSettingsDefaults() {
        let defaults = RecommendedSettings()
        XCTAssertEqual(defaults.engine, SetupConfiguration.sikarugir10Engine)
        XCTAssertEqual(defaults.renderer, "d3dmetal")
        XCTAssertEqual(defaults.displayMode, "retinaOff")
        XCTAssertEqual(defaults.driveMappingMode, "preserve")
        XCTAssertEqual(defaults.compatibilityProfile, .xrayD3DMetal)
        XCTAssertTrue(defaults.updateUSVFS)
        XCTAssertTrue(defaults.installGPTK4Binaries)
        XCTAssertFalse(defaults.installDXMTBinaries)
        XCTAssertFalse(defaults.installDirectXBinaries)
        XCTAssertFalse(defaults.saveVerboseLog)
        XCTAssertEqual(defaults.winetricks, SetupCompatibilityProfile.xrayD3DMetal.requiredVerbs)
        XCTAssertEqual(defaults.additionalWinetricks, "")
    }

    func testSaveAndLoadCustomRecommendedSettings() throws {
        let temp = try makeTempDir("gamma-settings-custom-rec")
        let settingsURL = temp.appendingPathComponent("settings.json")

        var custom = RecommendedSettings()
        custom.engine = SetupConfiguration.crossOverEngine
        custom.renderer = "dxmt"
        custom.displayMode = "defaultWine"
        custom.driveMappingMode = "shorten"
        custom.compatibilityProfile = .standard
        custom.updateUSVFS = false
        custom.installGPTK4Binaries = false
        custom.installDXMTBinaries = true
        custom.installDirectXBinaries = true
        custom.saveVerboseLog = true
        custom.winetricks = ["corefonts", "vcrun2026"]
        custom.additionalWinetricks = "faudio d3dx10"

        let settings = AppSettings(gammaPath: "/Games/GAMMA", recommended: custom)
        try AppSettingsStore.save(settings: settings, to: settingsURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: settingsURL.path))
        let loaded = AppSettingsStore.loadSettings(from: settingsURL)
        XCTAssertEqual(loaded.gammaPath, "/Games/GAMMA")
        XCTAssertEqual(loaded.recommended, custom)
        try? FileManager.default.removeItem(at: temp)
    }

    func testPartialRecommendedSettingsFallBackToDefaults() throws {
        let temp = try makeTempDir("gamma-settings-partial")
        let settingsURL = temp.appendingPathComponent("settings.json")
        let json = """
        {
          "recommended": {
            "renderer": "dxvk",
            "saveVerboseLog": true
          }
        }
        """
        try json.write(to: settingsURL, atomically: true, encoding: .utf8)

        let loaded = AppSettingsStore.loadRecommendedSettings(from: settingsURL)
        XCTAssertEqual(loaded.renderer, "dxvk")
        XCTAssertTrue(loaded.saveVerboseLog)
        XCTAssertEqual(loaded.engine, SetupConfiguration.sikarugir10Engine)
        XCTAssertEqual(loaded.displayMode, "retinaOff")
        XCTAssertEqual(loaded.driveMappingMode, "preserve")
        XCTAssertEqual(loaded.compatibilityProfile, .xrayD3DMetal)
        XCTAssertTrue(loaded.updateUSVFS)
        try? FileManager.default.removeItem(at: temp)
    }

    func testSaveGammaPathPreservesExistingRecommendedSettings() throws {
        let temp = try makeTempDir("gamma-settings-preserve-rec")
        let settingsURL = temp.appendingPathComponent("settings.json")

        var custom = RecommendedSettings()
        custom.renderer = "dxmt"
        custom.saveVerboseLog = true
        try AppSettingsStore.save(settings: AppSettings(gammaPath: nil, recommended: custom), to: settingsURL)

        try AppSettingsStore.save(gammaPath: "/New/Path/GAMMA", to: settingsURL)

        let loaded = AppSettingsStore.loadSettings(from: settingsURL)
        XCTAssertEqual(loaded.gammaPath, "/New/Path/GAMMA")
        XCTAssertEqual(loaded.recommended?.renderer, "dxmt")
        XCTAssertEqual(loaded.recommended?.saveVerboseLog, true)
        try? FileManager.default.removeItem(at: temp)
    }

    func testEnsureSettingsFileExistsCreatesDefaultJson() throws {
        let temp = try makeTempDir("gamma-settings-ensure")
        let settingsURL = temp.appendingPathComponent("settings.json")

        XCTAssertFalse(FileManager.default.fileExists(atPath: settingsURL.path))
        AppSettingsStore.ensureSettingsFileExists(at: settingsURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: settingsURL.path))

        let loaded = AppSettingsStore.loadSettings(from: settingsURL)
        XCTAssertNil(loaded.gammaPath)
        XCTAssertNil(loaded.recommended)
        try? FileManager.default.removeItem(at: temp)
    }

    func testBundledRecommendedSettingsLoadedFromResourceFile() {
        let bundled = AppSettingsStore.loadBundledRecommendedSettings()
        XCTAssertEqual(bundled.engine, SetupConfiguration.sikarugir10Engine)
        XCTAssertEqual(bundled.renderer, "d3dmetal")
        XCTAssertEqual(bundled.displayMode, "retinaOff")
        XCTAssertEqual(bundled.compatibilityProfile, .xrayD3DMetal)
        XCTAssertEqual(bundled.winetricks, ["d3dx9_43", "d3dx11_43", "d3dcompiler_47", "vcrun2026", "win10", "sound=coreaudio"])
    }

    private func makeTempDir(_ prefix: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
