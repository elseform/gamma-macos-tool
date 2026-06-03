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
