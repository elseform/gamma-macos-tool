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

    func testWrapperSelectionSplitsAppNameAndDirectory() throws {
        let temp = try makeTempDir("gamma-wrapper-selection")
        let wrapper = temp.appendingPathComponent("Custom GAMMA.app")
        try FileManager.default.createDirectory(at: wrapper, withIntermediateDirectories: true)

        let selection = AppSettingsStore.wrapperSelection(from: wrapper)

        XCTAssertEqual(selection?.appName, "Custom GAMMA")
        XCTAssertEqual(selection?.installDirectory, temp.standardizedFileURL.path)
        XCTAssertNil(AppSettingsStore.wrapperSelection(from: temp.appendingPathComponent("not-wrapper")))
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
        try? FileManager.default.removeItem(at: temp)
    }

    private func makeTempDir(_ prefix: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
