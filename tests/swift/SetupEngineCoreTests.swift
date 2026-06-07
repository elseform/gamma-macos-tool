import Foundation

final class SetupEngineCoreTests {
    func testAppendWordsSplitsSpacesAndCommas() {
        XCTAssertEqual(SetupPathTools.appendWords("corefonts,d3dx9 dxvk"), ["corefonts", "d3dx9", "dxvk"])
    }

    func testPathHelpers() throws {
        XCTAssertTrue(SetupPathTools.pathIsUnder("/tmp/root/child", parent: "/tmp/root"))
        XCTAssertTrue(SetupPathTools.pathIsUnder("/tmp/root", parent: "/tmp/root"))
        XCTAssertFalse(SetupPathTools.pathIsUnder("/tmp/rooted", parent: "/tmp/root"))
        XCTAssertEqual(SetupPathTools.commonParent("/Users/me/Games/GAMMA", "/Users/me/Games/Anomaly"), "/Users/me/Games")
        XCTAssertEqual(SetupPathTools.decodeModOrganizerIniValue(#"@ByteArray("Z:/Games/Anomaly")"#), "Z:/Games/Anomaly")
        XCTAssertEqual(SetupPathTools.windowsPathDrive(#"Z:\Games\Anomaly"#), "z")
        XCTAssertEqual(SetupPathTools.windowsPathRelative(#"Z:\Games\Anomaly"#), "Games/Anomaly")
        XCTAssertEqual(try SetupPathTools.nativeToWindowsPath("/Users/me/Games/GAMMA/ModOrganizer.exe", driveRoot: "/Users/me/Games", driveLetter: "g"), "G:/GAMMA/ModOrganizer.exe")
    }

    func testRegistryKeyValueEditorUpdatesSection() {
        let input = #"""
        [Existing]
        "Keep"="1"

        [Software\\Wine\\DllOverrides] 1780780400
        "*old"="builtin"
        """#

        let output = SetupTextEditor.ensureSectionKeyValues(
            text: input,
            section: #"Software\\Wine\\DllOverrides"#,
            entries: [
                "*d3dcompiler_47": "native,builtin",
                "*vcruntime140": "native,builtin"
            ]
        )

        XCTAssertTrue(output.contains(#""*d3dcompiler_47"="native,builtin""#))
        XCTAssertTrue(output.contains(#""*vcruntime140"="native,builtin""#))
        XCTAssertFalse(output.contains(#"[Software\\Wine\\DllOverrides]"# + "\n" + #""*d3dcompiler_47""#))
        XCTAssertTrue(output.contains("[Existing]"))
    }

    func testRegistryRawLineEditorUpdatesSection() {
        let input = #"""
        [System\\CurrentControlSet\\Services\\winebus] 1780780400
        "DisableInput"=dword:00000000
        """#

        let output = SetupTextEditor.ensureSectionRawLines(
            text: input,
            section: #"System\\CurrentControlSet\\Services\\winebus"#,
            lines: [
                #""DisableInput"=dword:00000001"#,
                #""Enable SDL"=dword:00000001"#
            ]
        )

        XCTAssertTrue(output.contains(#""DisableInput"=dword:00000001"#))
        XCTAssertTrue(output.contains(#""Enable SDL"=dword:00000001"#))
    }

    func testRegistryKeyValueEditorCreatesMissingSection() {
        let output = SetupTextEditor.ensureSectionKeyValues(
            text: "[Existing]\n\"Keep\"=\"1\"\n",
            section: #"Software\\Wine\\Drivers"#,
            entries: ["Graphics": "mac"]
        )

        XCTAssertContains(output, #"[Software\\Wine\\Drivers]"#)
        XCTAssertContains(output, #""Graphics"="mac""#)
        XCTAssertContains(output, "[Existing]")
    }

    func testEnginePreflightReportsManualMO2Fixture() throws {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gamma-setup-engine-tests-\(UUID().uuidString)")
        let gamma = temp.appendingPathComponent("GAMMA")
        let anomaly = temp.appendingPathComponent("Anomaly")
        try FileManager.default.createDirectory(at: gamma, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: anomaly, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gamma.appendingPathComponent("ModOrganizer.exe").path, contents: Data())
        try """
        [General]
        gamePath=G:/Anomaly
        """.write(to: gamma.appendingPathComponent("ModOrganizer.ini"), atomically: true, encoding: .utf8)

        let request = SetupRequest(
            outputApp: temp.appendingPathComponent("stalker-gamma.app").path,
            mo2Path: gamma.appendingPathComponent("ModOrganizer.exe").path,
            gammaPath: gamma.path,
            anomalyPath: anomaly.path,
            settingsFile: temp.appendingPathComponent("missing-settings.json").path
        )
        let report = try GAMMASetupEngine(executablePath: "/tmp/gamma-setup-engine").preflight(request: request)

        XCTAssertEqual(report.gammaPath, gamma.path)
        XCTAssertEqual(report.mo2Path, gamma.appendingPathComponent("ModOrganizer.exe").path)
        XCTAssertEqual(report.modOrganizerGamePath, "G:/Anomaly")
        XCTAssertEqual(report.wineDriveLetter, "G")
        XCTAssertEqual(report.wineDriveRoot, temp.path)
        try? FileManager.default.removeItem(at: temp)
    }

    func testEnginePreflightLoadsStalkerGammaSettingsJSON() throws {
        let fixture = try makeGammaFixture(gamePath: "G:/Anomaly")
        let settings = fixture.temp.appendingPathComponent("settings.json")
        try """
        {
          "Profiles": [
            {
              "Active": false,
              "Gamma": "\(fixture.temp.appendingPathComponent("Unused").path)",
              "Anomaly": "\(fixture.temp.appendingPathComponent("UnusedAnomaly").path)",
              "Mo2Profile": "Unused"
            },
            {
              "Active": true,
              "Gamma": "\(fixture.gamma.path)",
              "Anomaly": "\(fixture.anomaly.path)",
              "Mo2Profile": "Default"
            }
          ]
        }
        """.write(to: settings, atomically: true, encoding: .utf8)

        let request = SetupRequest(
            outputApp: fixture.temp.appendingPathComponent("stalker-gamma.app").path,
            settingsFile: settings.path
        )
        let report = try GAMMASetupEngine(executablePath: "/tmp/gamma-setup-engine").preflight(request: request)

        XCTAssertTrue(report.settingsFound)
        XCTAssertEqual(report.gammaPath, fixture.gamma.path)
        XCTAssertEqual(report.mo2Path, fixture.gamma.appendingPathComponent("ModOrganizer.exe").path)
        XCTAssertEqual(report.anomalyPath, fixture.anomaly.path)
        XCTAssertEqual(report.mo2Profile, "Default")
        XCTAssertEqual(report.modlistPath, fixture.gamma.appendingPathComponent("profiles/Default/modlist.txt").path)
        XCTAssertTrue(report.modlistFound)
        XCTAssertEqual(report.userLtxPath, fixture.anomaly.appendingPathComponent("appdata/user.ltx").path)
        XCTAssertTrue(report.userLtxFound)
        XCTAssertEqual(report.gameResolutionWidth, 1920)
        XCTAssertEqual(report.gameResolutionHeight, 1080)
        try? FileManager.default.removeItem(at: fixture.temp)
    }

    func testEnginePreflightReportsMissingSettingsWithoutFailing() throws {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gamma-setup-engine-missing-settings-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)

        let missingSettings = temp.appendingPathComponent("settings.json")
        let request = SetupRequest(
            outputApp: temp.appendingPathComponent("stalker-gamma.app").path,
            settingsFile: missingSettings.path
        )
        let report = try GAMMASetupEngine(executablePath: "/tmp/gamma-setup-engine").preflight(request: request)

        XCTAssertFalse(report.settingsFound)
        XCTAssertEqual(report.gammaPath, "")
        XCTAssertFalse(report.gammaFound)
        XCTAssertEqual(report.mo2Path, "")
        XCTAssertFalse(report.mo2Found)
        try? FileManager.default.removeItem(at: temp)
    }

    func testEnginePreflightDetectsZRewriteRequirement() throws {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gamma-setup-engine-z-rewrite-\(UUID().uuidString)")
        let gamma = temp.appendingPathComponent("GAMMA")
        let anomaly = temp.appendingPathComponent("Anomaly")
        try FileManager.default.createDirectory(at: gamma, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: anomaly, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gamma.appendingPathComponent("ModOrganizer.exe").path, contents: Data())
        try """
        [General]
        gamePath=Z:\(anomaly.path)
        """.write(to: gamma.appendingPathComponent("ModOrganizer.ini"), atomically: true, encoding: .utf8)

        let request = SetupRequest(
            outputApp: temp.appendingPathComponent("stalker-gamma.app").path,
            mo2Path: gamma.appendingPathComponent("ModOrganizer.exe").path,
            gammaPath: gamma.path,
            settingsFile: temp.appendingPathComponent("missing-settings.json").path
        )
        let report = try GAMMASetupEngine(executablePath: "/tmp/gamma-setup-engine").preflight(request: request)

        XCTAssertEqual(report.wineDriveLetter, "Z")
        XCTAssertEqual(report.wineDriveRoot, "/")
        XCTAssertTrue(report.zRewriteRequired)
        XCTAssertTrue(report.zShortenAvailable)
        XCTAssertEqual(report.shortWineDriveRoot, temp.path)
        try? FileManager.default.removeItem(at: temp)
    }

    func testDryRunCreateAcceptsTemplateDriveCSymlink() throws {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gamma-setup-engine-template-\(UUID().uuidString)")
        let template = temp.appendingPathComponent("Template-1.0.11.app")
        let contents = template.appendingPathComponent("Contents")
        let gamma = temp.appendingPathComponent("GAMMA")
        let anomaly = temp.appendingPathComponent("Anomaly")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("Resources"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("SharedSupport/Logs"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("Configure.app"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("Frameworks"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: gamma, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: anomaly, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gamma.appendingPathComponent("ModOrganizer.exe").path, contents: Data())
        FileManager.default.createFile(atPath: contents.appendingPathComponent("PkgInfo").path, contents: Data())
        try Data().write(to: contents.appendingPathComponent("Info.plist"))
        try FileManager.default.createSymbolicLink(
            atPath: contents.appendingPathComponent("drive_c").path,
            withDestinationPath: "SharedSupport/prefix/drive_c"
        )
        try """
        [General]
        gamePath=G:/Anomaly
        """.write(to: gamma.appendingPathComponent("ModOrganizer.ini"), atomically: true, encoding: .utf8)

        let request = SetupRequest(
            outputApp: temp.appendingPathComponent("stalker-gamma.app").path,
            mo2Path: gamma.appendingPathComponent("ModOrganizer.exe").path,
            gammaPath: gamma.path,
            anomalyPath: anomaly.path,
            dryRun: true,
            settingsFile: temp.appendingPathComponent("missing-settings.json").path
        )
        let engine = GAMMASetupEngine(
            executablePath: temp.appendingPathComponent("gamma-setup-engine").path,
            reporter: JSONEventReporter(streamEvents: false)
        )
        try engine.createForTesting(request: request, templateSource: template, templateName: "Template-1.0.11")
        try? FileManager.default.removeItem(at: temp)
    }

    func testUSVFSDefaultSourceIsNotUserSpecific() {
        XCTAssertEqual(SetupDefaults.defaultUSVFSSource, "")
    }

    private func makeGammaFixture(gamePath: String) throws -> (temp: URL, gamma: URL, anomaly: URL) {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gamma-setup-engine-fixture-\(UUID().uuidString)")
        let gamma = temp.appendingPathComponent("GAMMA")
        let anomaly = temp.appendingPathComponent("Anomaly")
        try FileManager.default.createDirectory(at: gamma.appendingPathComponent("profiles/Default"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: anomaly.appendingPathComponent("appdata"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: anomaly, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gamma.appendingPathComponent("ModOrganizer.exe").path, contents: Data())
        FileManager.default.createFile(atPath: gamma.appendingPathComponent("profiles/Default/modlist.txt").path, contents: Data())
        try "vid_mode 1920x1080\n".write(to: anomaly.appendingPathComponent("appdata/user.ltx"), atomically: true, encoding: .utf8)
        try """
        [General]
        gamePath=\(gamePath)
        """.write(to: gamma.appendingPathComponent("ModOrganizer.ini"), atomically: true, encoding: .utf8)
        return (temp, gamma, anomaly)
    }
}
