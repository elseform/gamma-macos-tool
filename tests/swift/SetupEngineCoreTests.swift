import Foundation

final class SetupEngineCoreTests {
    func testXRayD3DMetalWinetricksProfileOmitsCoreFonts() {
        XCTAssertEqual(
            SetupCompatibilityProfile.xrayD3DMetal.requiredVerbs,
            ["d3dx9_43", "d3dx11_43", "d3dcompiler_47", "vcrun2026", "win10", "sound=coreaudio"]
        )
        XCTAssertFalse(SetupCompatibilityProfile.xrayD3DMetal.requiredVerbs.contains("corefonts"))
        XCTAssertTrue(SetupCompatibilityProfile.standard.requiredVerbs.contains("corefonts"))
    }

    func testXRayD3DMetalOverridesKeepBackendOwnedDllsUnforced() {
        let overrides = SetupRegistryDefaults.xrayD3DMetalDllOverrides

        XCTAssertEqual(overrides["*d3dx9_43"], "native,builtin")
        XCTAssertEqual(overrides["*d3dx11_43"], "native,builtin")
        XCTAssertEqual(overrides["*d3dcompiler_47"], "native,builtin")
        XCTAssertEqual(overrides["winemenubuilder.exe"], "")
        XCTAssertNil(overrides["*d3d11"])
        XCTAssertNil(overrides["*dxgi"])
        XCTAssertNil(overrides["*nvapi64"])
        XCTAssertNil(overrides["*d3dx10_43"])
        XCTAssertNil(overrides["*d3dcompiler_43"])
        XCTAssertNil(overrides["*xinput1_3"])
    }

    func testAppendWordsSplitsSpacesAndCommas() {
        XCTAssertEqual(SetupPathTools.appendWords("corefonts,d3dx9 dxvk"), ["corefonts", "d3dx9", "dxvk"])
    }

    func testWinetricksVerbSupportRequiresEveryExactVerb() {
        let output = """
        corefonts                 Microsoft Core Fonts
        d3dx9_43                  DirectX 9 helper
        d3dx11_43                 DirectX 11 helper
        d3dcompiler_47            Direct3D compiler
        vcrun2026                 Visual C++ 2017-2026 libraries
        """
        XCTAssertTrue(WinetricksTools.supports(
            ["corefonts", "d3dx9_43", "d3dx11_43", "d3dcompiler_47", "vcrun2026"],
            listOutput: output
        ))
        XCTAssertFalse(WinetricksTools.supports(["vcrun2022"], listOutput: output))

        let installed = """
        corefonts
        d3dx9_43
        d3dx11_43
        d3dcompiler_47
        vcrun2022
        """
        XCTAssertEqual(
            WinetricksTools.missingVerbs(
                ["corefonts", "d3dx9_43", "d3dx11_43", "d3dcompiler_47", "vcrun2026"],
                installedOutput: installed
            ),
            ["vcrun2026"]
        )
    }

    func testWinetricksCachesAreSharedAcrossWrappers() {
        let engine = GAMMASetupEngine(
            executablePath: "/tmp/gamma-setup-engine",
            reporter: JSONEventReporter(streamEvents: false)
        )
        let first = engine.winetricksCachePathsForTesting(
            request: SetupRequest(outputApp: "/tmp/first-wrapper.app")
        )
        let second = engine.winetricksCachePathsForTesting(
            request: SetupRequest(outputApp: "/tmp/second-wrapper.app")
        )

        XCTAssertEqual(first, second)
        XCTAssertTrue(first["script"]?.hasSuffix("/Library/Application Support/gamma-setup-tool/cache/winetricks/winetricks") == true)
        XCTAssertTrue(first["downloads"]?.hasSuffix("/Library/Application Support/gamma-setup-tool/cache/winetricks/downloads") == true)
        XCTAssertFalse(first.values.contains { $0.contains("first-wrapper.app") || $0.contains("second-wrapper.app") })
    }

    func testWinetricksCurrentVCRunChecksumsReplaceStaleValues() {
        let script = """
        w_download x86 e7267c1bdf9237c0b4a28cf027c382b97aa909934f84f1c92d3fb9f04173b33e
        w_download x64 8995548dfffcde7c49987029c764355612ba6850ee09a7b6f0fddc85bdc5c280
        keep unrelated-checksum
        """
        let updated = WinetricksTools.updatingKnownPayloadChecksums(in: script)

        XCTAssertContains(updated, "f0bab33a302b3cdb2e11113760d016f54fd3d2632c65ba7834fac4f0abd7f1a3")
        XCTAssertContains(updated, "843068991daaa1f73ad9f6239bce4d0f6a07a51f18c37ea2a867e9beca71295c")
        XCTAssertContains(updated, "keep unrelated-checksum")
        XCTAssertFalse(updated.contains("e7267c1bdf9237c0b4a28cf027c382b97aa909934f84f1c92d3fb9f04173b33e"))
        XCTAssertFalse(updated.contains("8995548dfffcde7c49987029c764355612ba6850ee09a7b6f0fddc85bdc5c280"))
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
        XCTAssertEqual(SetupPathTools.windowsDirectoryPath("G:/GAMMA/ModOrganizer.exe"), "G:/GAMMA")
        XCTAssertEqual(SetupPathTools.windowsDirectoryPath(#"G:\GAMMA\ModOrganizer.exe"#), "G:/GAMMA")
        XCTAssertEqual(SetupPathTools.windowsDirectoryPath("G:/ModOrganizer.exe"), "G:/")
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

    func testWineDisplayDefaultWritesNothingAndRetinaOffWritesOnlyRequiredValues() throws {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gamma-wine-display-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temp) }

        let existingRegistry = #"""
        [Software\\Wine\\Mac Driver]
        "RetinaMode"="Y"

        [Control Panel\\Desktop]
        "LogPixels"=dword:000000c0
        """#
        let engine = GAMMASetupEngine(executablePath: "/tmp/gamma-setup-engine")
        let unchanged = try engine.configureWineDisplayForTesting(
            request: SetupRequest(
                outputApp: temp.appendingPathComponent("default.app").path,
                forceRetinaOff: false
            ),
            registry: existingRegistry
        )
        XCTAssertEqual(unchanged, existingRegistry)

        let forced = try engine.configureWineDisplayForTesting(
            request: SetupRequest(
                outputApp: temp.appendingPathComponent("forced.app").path,
                forceRetinaOff: true
            ),
            registry: ""
        )
        XCTAssertContains(forced, #""RetinaMode"="N""#)
        XCTAssertContains(forced, #""LogPixels"=dword:00000060"#)
        XCTAssertFalse(forced.contains("Win8DpiScaling"))
        XCTAssertFalse(forced.contains("Explorer\\\\Desktops"))
    }

    func testRequiredDllOverridesMatchEnforcedWrapperRegistry() {
        XCTAssertEqual(SetupRegistryDefaults.requiredDllOverrides, [
            "*concrt140": "native,builtin",
            "*d3dcompiler_43": "native,builtin",
            "*d3dcompiler_47": "native,builtin",
            "*d3dx9_43": "native,builtin",
            "*d3dx10_43": "native,builtin",
            "*d3dx11_43": "native,builtin",
            "*msvcp140": "native,builtin",
            "*msvcp140_1": "native,builtin",
            "*msvcp140_2": "native,builtin",
            "*msvcp140_atomic_wait": "native,builtin",
            "*msvcp140_codecvt_ids": "native,builtin",
            "*vcamp140": "native,builtin",
            "*vccorlib140": "native,builtin",
            "*vcomp140": "native,builtin",
            "*vcruntime140": "native,builtin",
            "*vcruntime140_1": "native,builtin",
            "*xinput1_3": "native,builtin",
        ])
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
        XCTAssertEqual(report.wineDriveLetter, "Z")
        XCTAssertEqual(report.wineDriveRoot, "/")
        XCTAssertEqual(report.shortWineDriveRoot, temp.path)
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

    func testEnginePreflightReportsOptionalGRootWithoutRequiringRewrite() throws {
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
        XCTAssertFalse(report.zRewriteRequired)
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

    func testXRayD3DMetalProfileWritesLauncherWineOptions() throws {
        let temp = try makeTempDir("gamma-xray-d3dmetal-profile")
        let template = try makeWrapperTemplate(root: temp)
        let app = temp.appendingPathComponent("stalker-gamma.app")
        let request = SetupRequest(
            outputApp: app.path,
            renderer: "d3dmetal",
            installGPTK4Binaries: true,
            compatibilityProfile: .xrayD3DMetal
        )
        let engine = GAMMASetupEngine(
            executablePath: temp.appendingPathComponent("gamma-setup-engine").path,
            reporter: JSONEventReporter(streamEvents: false)
        )

        try engine.configureWrapperForTesting(
            request: request,
            templateSource: template,
            templateName: "Template-1.0.11"
        )
        let plistURL = app.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]

        XCTAssertEqual(plist?["D3DMETAL"] as? String, "1")
        XCTAssertEqual(plist?["WINEESYNC"] as? String, "0")
        XCTAssertEqual(plist?["WINEMSYNC"] as? String, "1")
        XCTAssertEqual(plist?["ADVERTISE_AVX"] as? Int, 1)
        XCTAssertEqual(plist?["METAL_HUD"] as? Int, 1)
        XCTAssertEqual(plist?["WINEDEBUG"] as? String, "-all")
        try? FileManager.default.removeItem(at: temp)
    }

    func testUSVFSDefaultSourceIsNotUserSpecific() {
        XCTAssertEqual(SetupDefaults.defaultUSVFSSource, "")
    }

    func testLaunchBatchEnvironmentIsOnlyAddedForModOrganizer() {
        let gameLines = SetupLaunchBatchTools.commandLines(
            executableWindowsPath: #"G:\Anomaly\bin\AnomalyDX11AVX.exe"#,
            workingDirectoryWindowsPath: #"G:\Anomaly\bin"#,
            usesModOrganizerEnvironment: false,
            launchArguments: "  --dxgi-old  "
        )
        XCTAssertFalse(gameLines.contains { $0.contains("QT_OPENGL") })
        XCTAssertEqual(gameLines.last, #"start "" /D "G:\Anomaly\bin" "G:\Anomaly\bin\AnomalyDX11AVX.exe" --dxgi-old"#)

        let mo2Lines = SetupLaunchBatchTools.commandLines(
            executableWindowsPath: #"G:\GAMMA\ModOrganizer.exe"#,
            workingDirectoryWindowsPath: #"G:\GAMMA"#,
            usesModOrganizerEnvironment: true,
            launchArguments: #"--profile "Default""#
        )
        XCTAssertTrue(mo2Lines.contains(#"set "QT_OPENGL=software""#))
        XCTAssertTrue(mo2Lines.contains(#"set "QT_QUICK_BACKEND=software""#))
        XCTAssertTrue(mo2Lines.contains(#"set "QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu""#))
        XCTAssertEqual(mo2Lines.last, #"start "" /D "G:\GAMMA" "G:\GAMMA\ModOrganizer.exe" --profile "Default""#)

        let noArguments = SetupLaunchBatchTools.commandLines(
            executableWindowsPath: #"G:\Anomaly\bin\Anomaly.exe"#,
            workingDirectoryWindowsPath: #"G:\Anomaly\bin"#,
            usesModOrganizerEnvironment: false,
            launchArguments: "   "
        )
        XCTAssertEqual(noArguments.last, #"start "" /D "G:\Anomaly\bin" "G:\Anomaly\bin\Anomaly.exe""#)
    }

    func testModOrganizerBatchUsesWindowsWorkingDirectory() {
        let lines = SetupLaunchBatchTools.modOrganizerCommandLines(
            executableWindowsPath: "G:/g/ModOrganizer.exe",
            launchArguments: "--portable"
        )
        XCTAssertContains(lines.joined(separator: "\n"), #"cd /d "G:\g""#)
        XCTAssertContains(lines.joined(separator: "\n"), #"start "" "G:\g\ModOrganizer.exe" --portable"#)
        XCTAssertFalse(lines.joined(separator: "\n").contains("Contents\\Resources"))
    }

    func testLaunchArgumentsRejectLineBreaks() throws {
        let temp = try makeTempDir("gamma-launch-flags")
        let app = temp.appendingPathComponent("stalker-gamma.app")
        let gamma = temp.appendingPathComponent("GAMMA")
        try FileManager.default.createDirectory(at: gamma, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gamma.appendingPathComponent("ModOrganizer.exe").path, contents: Data())
        let request = SetupRequest(
            outputApp: app.path,
            mo2Path: gamma.appendingPathComponent("ModOrganizer.exe").path,
            launchArguments: "--first\r\nstart unwanted.exe"
        )
        let engine = GAMMASetupEngine(executablePath: temp.appendingPathComponent("gamma-setup-engine").path)
        var rejected = false
        do {
            try engine.configureDriveMappingAndMO2BatchForTesting(request: request)
        } catch SetupEngineError.message(let message) {
            rejected = message.contains("single line")
        } catch {
            rejected = false
        }
        XCTAssertTrue(rejected)
        try? FileManager.default.removeItem(at: temp)
    }

    func testDefaultModOrganizerBatchDetectionIsNarrow() {
        let generated = SetupLaunchBatchTools.modOrganizerCommandLines(executableWindowsPath: "G:/g/ModOrganizer.exe")
            .joined(separator: "\r\n")
        XCTAssertTrue(SetupLaunchBatchTools.isDefaultModOrganizerBatch(generated))

        let edited = generated + "\r\nrem user customization"
        XCTAssertFalse(SetupLaunchBatchTools.isDefaultModOrganizerBatch(edited))
    }

    func testDefaultInstallUsesWineZMappingWithoutCreatingShortDrive() throws {
        let temp = try makeTempDir("gamma-default-drive")
        let app = temp.appendingPathComponent("stalker-gamma.app")
        let gamma = temp.appendingPathComponent("GAMMA")
        let anomaly = temp.appendingPathComponent("Anomaly")
        try FileManager.default.createDirectory(at: gamma, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: anomaly, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gamma.appendingPathComponent("ModOrganizer.exe").path, contents: Data())
        let originalINI = """
        [General]
        gamePath=G:\\Anomaly
        """
        let iniURL = gamma.appendingPathComponent("ModOrganizer.ini")
        try originalINI.write(to: iniURL, atomically: true, encoding: .utf8)

        let request = SetupRequest(
            outputApp: app.path,
            mo2Path: gamma.appendingPathComponent("ModOrganizer.exe").path,
            gammaPath: gamma.path,
            anomalyPath: anomaly.path,
            driveMappingMode: "preserve"
        )
        let engine = GAMMASetupEngine(executablePath: temp.appendingPathComponent("gamma-setup-engine").path, reporter: JSONEventReporter(streamEvents: false))
        try engine.configureDriveMappingAndMO2BatchForTesting(request: request)

        let dosdevices = app.appendingPathComponent("Contents/SharedSupport/prefix/dosdevices")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dosdevices.appendingPathComponent("g:").path))
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: dosdevices.appendingPathComponent("z:").path), "/")
        let gammaWindows = "Z:" + gamma.path.replacingOccurrences(of: "/", with: "\\")
        let mo2Windows = "Z:" + gamma.appendingPathComponent("ModOrganizer.exe").path.replacingOccurrences(of: "/", with: "\\")
        let batch = try String(contentsOf: app.appendingPathComponent("Contents/SharedSupport/prefix/drive_c/mo2.bat"))
        XCTAssertContains(batch, #"cd /d "\#(gammaWindows)""#)
        XCTAssertContains(batch, #"start "" "\#(mo2Windows)""#)
        XCTAssertEqual(try String(contentsOf: iniURL), originalINI)
        try? FileManager.default.removeItem(at: temp)
    }

    func testAdvancedInstallCreatesGMappingWithoutChangingModOrganizerINI() throws {
        let temp = try makeTempDir("gamma-advanced-drive")
        let app = temp.appendingPathComponent("stalker-gamma.app")
        let gamma = temp.appendingPathComponent("GAMMA")
        try FileManager.default.createDirectory(at: gamma, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gamma.appendingPathComponent("ModOrganizer.exe").path, contents: Data())
        let originalINI = """
        [General]
        gamePath=G:\\Anomaly
        """
        let iniURL = gamma.appendingPathComponent("ModOrganizer.ini")
        try originalINI.write(to: iniURL, atomically: true, encoding: .utf8)

        let request = SetupRequest(
            outputApp: app.path,
            mo2Path: gamma.appendingPathComponent("ModOrganizer.exe").path,
            gammaPath: gamma.path,
            driveMappingMode: "shorten"
        )
        let engine = GAMMASetupEngine(executablePath: temp.appendingPathComponent("gamma-setup-engine").path, reporter: JSONEventReporter(streamEvents: false))
        try engine.configureDriveMappingAndMO2BatchForTesting(request: request)

        let dosdevices = app.appendingPathComponent("Contents/SharedSupport/prefix/dosdevices")
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: dosdevices.appendingPathComponent("g:").path), temp.path)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: dosdevices.appendingPathComponent("z:").path), "/")
        let batch = try String(contentsOf: app.appendingPathComponent("Contents/SharedSupport/prefix/drive_c/mo2.bat"))
        XCTAssertContains(batch, #"cd /d "G:\GAMMA""#)
        XCTAssertContains(batch, #"start "" "G:\GAMMA\ModOrganizer.exe""#)
        XCTAssertEqual(try String(contentsOf: iniURL), originalINI)
        try? FileManager.default.removeItem(at: temp)
    }

    func testCustomLaunchBatchesUseMappedGAndFallbackZPaths() throws {
        let temp = try makeTempDir("gamma-custom-launch-mapped")
        let outside = try makeTempDir("gamma-custom-launch-outside")
        let app = temp.appendingPathComponent("stalker-gamma.app")
        let gamma = temp.appendingPathComponent("GAMMA")
        let mappedBin = temp.appendingPathComponent("flatgold/bin")
        let outsideBin = outside.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: gamma, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mappedBin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideBin, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gamma.appendingPathComponent("ModOrganizer.exe").path, contents: Data())
        let mappedExecutable = mappedBin.appendingPathComponent("AnomalyDX11AVX.exe")
        let outsideExecutable = outsideBin.appendingPathComponent("AnomalyDX11.exe")
        FileManager.default.createFile(atPath: mappedExecutable.path, contents: Data())
        FileManager.default.createFile(atPath: outsideExecutable.path, contents: Data())

        let request = SetupRequest(
            outputApp: app.path,
            mo2Path: gamma.appendingPathComponent("ModOrganizer.exe").path,
            programBatch: "/Mapped.bat",
            launchBatches: [
                LaunchBatch(
                    batchPath: "/Mapped.bat",
                    executablePath: mappedExecutable.path,
                    workingDirectory: mappedBin.path
                ),
                LaunchBatch(
                    batchPath: "/Outside.bat",
                    executablePath: outsideExecutable.path,
                    workingDirectory: outsideBin.path
                )
            ],
            launchArguments: "--dxgi-old",
            driveMappingMode: "shorten"
        )
        let engine = GAMMASetupEngine(executablePath: temp.appendingPathComponent("gamma-setup-engine").path)
        try engine.configureDriveMappingAndMO2BatchForTesting(request: request)

        let driveC = app.appendingPathComponent("Contents/SharedSupport/prefix/drive_c")
        let mappedBatch = try String(contentsOf: driveC.appendingPathComponent("Mapped.bat"))
        XCTAssertContains(mappedBatch, #"start "" /D "G:\flatgold\bin" "G:\flatgold\bin\AnomalyDX11AVX.exe" --dxgi-old"#)
        let modOrganizerBatch = try String(contentsOf: driveC.appendingPathComponent("mo2.bat"))
        XCTAssertFalse(modOrganizerBatch.contains("--dxgi-old"))

        let outsideWindowsDirectory = "Z:" + outsideBin.path.replacingOccurrences(of: "/", with: "\\")
        let outsideWindowsExecutable = "Z:" + outsideExecutable.path.replacingOccurrences(of: "/", with: "\\")
        let outsideBatch = try String(contentsOf: driveC.appendingPathComponent("Outside.bat"))
        XCTAssertContains(outsideBatch, #"start "" /D "\#(outsideWindowsDirectory)" "\#(outsideWindowsExecutable)""#)
        XCTAssertFalse(outsideBatch.contains("--dxgi-old"))

        try? FileManager.default.removeItem(at: temp)
        try? FileManager.default.removeItem(at: outside)
    }

    func testExistingTargetIsRejectedWithoutReplacement() throws {
        let temp = try makeTempDir("gamma-existing-target")
        let template = try makeWrapperTemplate(root: temp)
        let app = temp.appendingPathComponent("stalker-gamma.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let sentinel = app.appendingPathComponent("user-file")
        try "keep".write(to: sentinel, atomically: true, encoding: .utf8)

        let engine = GAMMASetupEngine(executablePath: temp.appendingPathComponent("gamma-setup-engine").path, reporter: JSONEventReporter(streamEvents: false))
        var errorDescription = ""
        do {
            try engine.configureWrapperForTesting(
                request: SetupRequest(outputApp: app.path, updateUSVFS: false),
                templateSource: template,
                templateName: "Template-1.0.11"
            )
        } catch {
            errorDescription = String(describing: error)
        }

        XCTAssertContains(errorDescription, "target already exists")
        XCTAssertEqual(try String(contentsOf: sentinel), "keep")
        try? FileManager.default.removeItem(at: temp)
    }

    func testWinetricksDetectionReadsRegistryDllOverrides() {
        let registry = #"""
        [Software\\Wine\\DllOverrides]
        "*concrt140"="native,builtin"
        "*d3dcompiler_43"="native,builtin"
        "*d3dcompiler_47"="native,builtin"
        "*d3dx9_43"="native,builtin"
        "*d3dx10_43"="native,builtin"
        "*d3dx11_43"="native,builtin"
        "*msvcp140"="native,builtin"
        "*msvcp140_1"="native,builtin"
        "*msvcp140_2"="native,builtin"
        "*msvcp140_atomic_wait"="native,builtin"
        "*msvcp140_codecvt_ids"="native,builtin"
        "*vcamp140"="native,builtin"
        "*vccorlib140"="native,builtin"
        "*vcomp140"="native,builtin"
        "*vcruntime140"="native,builtin"
        "*vcruntime140_1"="native,builtin"
        "*xinput1_3"="native,builtin"
        """#
        let engine = GAMMASetupEngine(executablePath: "/tmp/gamma-setup-engine", reporter: JSONEventReporter(streamEvents: false))

        XCTAssertTrue(engine.missingDllOverridesForTesting(registry: registry).isEmpty)
        let missing = engine.missingDllOverridesForTesting(registry: registry.replacingOccurrences(of: #""*vcruntime140_1"="native,builtin""#, with: ""))
        XCTAssertTrue(missing.contains("*vcruntime140_1"))
    }

    func testUSVFSInstallerComparesAndReplacesStaleBinaries() throws {
        let temp = try makeTempDir("gamma-usvfs")
        let source = temp.appendingPathComponent("usvfs")
        let mo2Dir = temp.appendingPathComponent("GAMMA")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mo2Dir, withIntermediateDirectories: true)
        let files = ["usvfs_x64.dll", "usvfs_proxy_x64.exe", "usvfs_x86.dll", "usvfs_proxy_x86.exe"]
        for file in files {
            try "new-\(file)".write(to: source.appendingPathComponent(file), atomically: true, encoding: .utf8)
            try "old-\(file)".write(to: mo2Dir.appendingPathComponent(file), atomically: true, encoding: .utf8)
        }
        let mo2 = mo2Dir.appendingPathComponent("ModOrganizer.exe")
        FileManager.default.createFile(atPath: mo2.path, contents: Data())

        let request = SetupRequest(
            outputApp: temp.appendingPathComponent("stalker-gamma.app").path,
            updateUSVFS: true,
            mo2Path: mo2.path,
            usvfsSource: source.path
        )
        let engine = GAMMASetupEngine(executablePath: temp.appendingPathComponent("gamma-setup-engine").path, reporter: JSONEventReporter(streamEvents: false))
        try engine.installUSVFSForTesting(request: request)
        try engine.installUSVFSForTesting(request: request)

        for file in files {
            XCTAssertEqual(try String(contentsOf: mo2Dir.appendingPathComponent(file)), "new-\(file)")
        }
        try? FileManager.default.removeItem(at: temp)
    }

    func testGPTK4PayloadDetectionAndReplacement() throws {
        let temp = try makeTempDir("gamma-gptk4")
        let resourceRoot = temp.appendingPathComponent("Resources")
        let source = resourceRoot.appendingPathComponent("gptk4/d3dmetal")
        try makeD3DMetalPayload(at: source, version: "4.0b1", marker: "gptk4")
        let app = temp.appendingPathComponent("stalker-gamma.app")
        let target = app.appendingPathComponent("Contents/Frameworks/renderer/d3dmetal")
        try makeD3DMetalPayload(at: target, version: "3.0", marker: "old")

        let request = SetupRequest(
            outputApp: app.path,
            installGPTK4Binaries: true,
            resourceRoot: resourceRoot.path
        )
        let engine = GAMMASetupEngine(executablePath: temp.appendingPathComponent("gamma-setup-engine").path, reporter: JSONEventReporter(streamEvents: false))
        XCTAssertFalse(engine.payloadMatchesForTesting(source: source, target: target))
        try engine.installGPTK4ForTesting(request: request)

        XCTAssertTrue(engine.payloadMatchesForTesting(source: source, target: target))
        XCTAssertEqual(
            try FileManager.default.destinationOfSymbolicLink(atPath: app.appendingPathComponent("Contents/Frameworks/renderer/apple_gptk").path),
            "d3dmetal"
        )
        try? FileManager.default.removeItem(at: temp)
    }

    func testConfigureAliasCreationAndCollisionHandling() throws {
        let temp = try makeTempDir("gamma-configure-alias")
        let template = try makeWrapperTemplate(root: temp)
        let engine = GAMMASetupEngine(executablePath: temp.appendingPathComponent("gamma-setup-engine").path, reporter: JSONEventReporter(streamEvents: false))
        let app = temp.appendingPathComponent("stalker-gamma.app")
        try engine.configureWrapperForTesting(
            request: SetupRequest(outputApp: app.path, engine: SetupDefaults.sikarugir10Engine, updateUSVFS: false),
            templateSource: template,
            templateName: "Template-1.0.11"
        )

        let alias = temp.appendingPathComponent("Configure stalker-gamma")
        XCTAssertTrue(FileManager.default.fileExists(atPath: alias.path))
        XCTAssertEqual(
            bookmarkTarget(alias)?.standardizedFileURL.path,
            app.appendingPathComponent("Contents/Configure.app").standardizedFileURL.path
        )

        let collidingApp = temp.appendingPathComponent("stalker-gamma-collision.app")
        let collidingAlias = temp.appendingPathComponent("Configure stalker-gamma-collision")
        try "not an alias".write(to: collidingAlias, atomically: true, encoding: .utf8)
        var threw = false
        do {
            try engine.configureWrapperForTesting(
                request: SetupRequest(outputApp: collidingApp.path, engine: SetupDefaults.sikarugir10Engine, updateUSVFS: false),
                templateSource: template,
                templateName: "Template-1.0.11"
            )
        } catch {
            threw = true
        }
        XCTAssertTrue(threw)
        try? FileManager.default.removeItem(at: temp)
    }

    private func makeGammaFixture(gamePath: String) throws -> (temp: URL, gamma: URL, anomaly: URL) {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gamma-setup-engine-fixture-\(UUID().uuidString)")
        let gamma = temp.appendingPathComponent("GAMMA")
        let anomaly = temp.appendingPathComponent("Anomaly")
        try FileManager.default.createDirectory(at: gamma.appendingPathComponent("profiles/Default"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: anomaly, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gamma.appendingPathComponent("ModOrganizer.exe").path, contents: Data())
        FileManager.default.createFile(atPath: gamma.appendingPathComponent("profiles/Default/modlist.txt").path, contents: Data())
        try """
        [General]
        gamePath=\(gamePath)
        """.write(to: gamma.appendingPathComponent("ModOrganizer.ini"), atomically: true, encoding: .utf8)
        return (temp, gamma, anomaly)
    }

    private func makeTempDir(_ prefix: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeWrapperTemplate(root: URL) throws -> URL {
        let template = root.appendingPathComponent("Template-1.0.11.app")
        let contents = template.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("Configure.app"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("Resources"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("Logs"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("drive_c"), withIntermediateDirectories: true)
        try writePlist(["Program Name and Path": "/mo2.bat"], to: contents.appendingPathComponent("Info.plist"))
        FileManager.default.createFile(atPath: contents.appendingPathComponent("PkgInfo").path, contents: Data())
        return template
    }

    private func makeD3DMetalPayload(at root: URL, version: String, marker: String) throws {
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("external/D3DMetal.framework/Resources"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("wine/x86_64-unix"),
            withIntermediateDirectories: true
        )
        try marker.write(to: root.appendingPathComponent("external/libd3dshared.dylib"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            atPath: root.appendingPathComponent("wine/x86_64-unix/dxgi.so").path,
            withDestinationPath: "../../external/libd3dshared.dylib"
        )
        try writePlist(
            [
                "CFBundleShortVersionString": version,
                "CFBundleVersion": version
            ],
            to: root.appendingPathComponent("external/D3DMetal.framework/Resources/version.plist")
        )
    }

    private func writePlist(_ values: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func bookmarkTarget(_ alias: URL) -> URL? {
        guard let data = try? URL.bookmarkData(withContentsOf: alias) else { return nil }
        var stale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
    }
}
