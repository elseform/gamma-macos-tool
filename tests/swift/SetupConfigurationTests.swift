import Foundation

final class SetupConfigurationTests {
    func testOutputAppPathAddsAppSuffix() {
        let config = SetupConfiguration(appName: "stalker-gamma", installDirectory: "/tmp/Sikarugir")

        XCTAssertEqual(config.outputAppPath, "/tmp/Sikarugir/stalker-gamma.app")
    }

    func testOutputAppPathDoesNotDuplicateAppSuffix() {
        let config = SetupConfiguration(appName: "  stalker-gamma.app  ", installDirectory: "/tmp/Sikarugir")

        XCTAssertEqual(config.outputAppPath, "/tmp/Sikarugir/stalker-gamma.app")
    }

    func testDefaultOutputAppPathUsesApplicationsFolder() {
        let expected = URL(fileURLWithPath: SetupConfiguration.defaultInstallDirectory)
            .appendingPathComponent("stalker-gamma.app")
            .path

        XCTAssertEqual(SetupConfiguration().outputAppPath, expected)
    }

    func testWrapperNameValidationRejectsUnsafeNames() {
        XCTAssertTrue(SetupConfiguration.isValidWrapperName("GAMMA"))
        XCTAssertTrue(SetupConfiguration.isValidWrapperName("GAMMA.app"))
        XCTAssertFalse(SetupConfiguration.isValidWrapperName(""))
        XCTAssertFalse(SetupConfiguration.isValidWrapperName("../GAMMA"))
        XCTAssertFalse(SetupConfiguration.isValidWrapperName("GAMMA:Test"))
    }

    func testRendererLabels() {
        XCTAssertEqual(SetupConfiguration(renderer: "d3dmetal").rendererLabel, "D3DMetal")
        XCTAssertEqual(SetupConfiguration(renderer: "dxmt").rendererLabel, "DXMT")
        XCTAssertEqual(SetupConfiguration(renderer: "dxvk").rendererLabel, "DXVK")
    }

    func testEnvironmentOKRequiresSelectedModOrganizerOnly() throws {
        let temp = try makeTempDir("gamma-environment")
        let mo2 = temp.appendingPathComponent("ModOrganizer.exe")
        FileManager.default.createFile(atPath: mo2.path, contents: Data())

        var missingTools = Preflight.fixture()
        missingTools.homebrewFound = false
        missingTools.sikarugirTapInstalled = false
        missingTools.sikarugirInstalled = false
        missingTools.winetricksFound = false
        missingTools.gammaFound = false
        missingTools.mo2Found = false
        missingTools.modOrganizerIniFound = false

        let config = SetupConfiguration(
            manualModOrganizerPath: mo2.path,
            preflight: missingTools
        )

        XCTAssertTrue(config.environmentOK)
        XCTAssertTrue(config.createFlowEnvironmentOK)
        XCTAssertFalse(SetupConfiguration(preflight: .fixture()).environmentOK)
        XCTAssertFalse(SetupConfiguration(manualModOrganizerPath: mo2.path + ".missing").environmentOK)
        try? FileManager.default.removeItem(at: temp)
    }

    func testCanInstallComponentsIsDisabledForWizard() {
        XCTAssertFalse(SetupConfiguration(preflight: .fixture()).canInstallComponents)

        var missingWinetricks = Preflight.fixture()
        missingWinetricks.winetricksFound = false
        missingWinetricks.winetricksPath = ""
        XCTAssertFalse(SetupConfiguration(preflight: missingWinetricks).canInstallComponents)

        var missingSikarugir = Preflight.fixture()
        missingSikarugir.sikarugirTapInstalled = false
        missingSikarugir.sikarugirInstalled = false
        XCTAssertFalse(SetupConfiguration(preflight: missingSikarugir).canInstallComponents)

        var missingHomebrew = missingSikarugir
        missingHomebrew.homebrewFound = false
        XCTAssertFalse(SetupConfiguration(preflight: missingHomebrew).canInstallComponents)
    }

    func testSetupRequestIncludesTargetAndRenderer() {
        let config = SetupConfiguration(
            appName: "GAMMA",
            installDirectory: "/Applications",
            engine: SetupConfiguration.sikarugir10Engine,
            renderer: "dxmt"
        )

        XCTAssertEqual(config.setupRequest.outputApp, "/Applications/GAMMA.app")
        XCTAssertEqual(config.setupRequest.engine, "WS12WineSikarugir10.0_6")
        XCTAssertEqual(config.setupRequest.renderer, "dxmt")
    }

    func testDefaultsMatchPlaytestedSikarugirWrapper() {
        let config = SetupConfiguration()

        XCTAssertEqual(config.engine, SetupConfiguration.sikarugir10Engine)
        XCTAssertEqual(config.renderer, "d3dmetal")
        XCTAssertTrue(config.updateUSVFS)
        XCTAssertTrue(config.installGPTK4Binaries)
        XCTAssertFalse(config.saveVerboseLog)
        XCTAssertEqual(config.driveMappingMode, "preserve")
        XCTAssertEqual(config.displayMode, "defaultWine")
    }

    func testSetupRequestIncludesUSVFSUpdateOption() {
        XCTAssertTrue(SetupConfiguration().setupRequest.updateUSVFS)
        XCTAssertFalse(SetupConfiguration(updateUSVFS: false).setupRequest.updateUSVFS)
        XCTAssertEqual(SetupConfiguration(engine: SetupConfiguration.sikarugir10Engine).setupRequest.usvfsSource, "")
    }

    func testSetupRequestIncludesGPTK4Option() {
        XCTAssertTrue(SetupConfiguration().setupRequest.installGPTK4Binaries)
        XCTAssertFalse(SetupConfiguration(installGPTK4Binaries: false).setupRequest.installGPTK4Binaries)
    }

    func testSetupRequestIncludesManualModOrganizerWhenProvided() {
        let config = SetupConfiguration(manualModOrganizerPath: "/Games/GAMMA/ModOrganizer.exe")

        XCTAssertEqual(config.setupRequest.mo2Path, "/Games/GAMMA/ModOrganizer.exe")
    }

    func testCreateFlowRequiresSelectedModOrganizerButNotAutomaticGammaDiscovery() throws {
        let temp = try makeTempDir("gamma-create-flow")
        let mo2 = temp.appendingPathComponent("ModOrganizer.exe")
        FileManager.default.createFile(atPath: mo2.path, contents: Data())

        var preflight = Preflight.fixture()
        preflight.stalkerGammaFound = false
        preflight.settingsFound = false
        preflight.gammaFound = false
        preflight.mo2Found = false
        preflight.modOrganizerIniFound = false

        let config = SetupConfiguration(
            manualModOrganizerPath: mo2.path,
            preflight: preflight
        )

        XCTAssertTrue(config.environmentOK)
        XCTAssertTrue(config.createFlowEnvironmentOK)
        XCTAssertEqual(config.setupRequest.mo2Path, mo2.path)
        try? FileManager.default.removeItem(at: temp)
    }

    func testLaunchExecutableDefaultsToDetectedModOrganizer() {
        var preflight = Preflight.fixture()
        preflight.mo2Path = "/Games/GAMMA/ModOrganizer.exe"

        let config = SetupConfiguration(preflight: preflight)

        XCTAssertEqual(config.selectedLaunchExecutablePath, "/Games/GAMMA/ModOrganizer.exe")
        XCTAssertEqual(config.selectedLaunchExecutableLabel, "ModOrganizer")
        XCTAssertEqual(config.setupRequest.programBatch, "/mo2.bat")
    }

    func testCustomLaunchExecutableIsSerializedWithEnvironmentChoice() {
        let launch = LaunchBatch(
            batchPath: "/Anomaly.bat",
            executablePath: "/Games/Anomaly/bin/AnomalyDX11AVX.exe",
            workingDirectory: "/Games/Anomaly/bin",
            usesModOrganizerEnvironment: false
        )
        let config = SetupConfiguration(
            programBatch: launch.batchPath,
            launchBatches: [launch],
            launchArguments: #"  --dxgi-old --profile "Gold"  "#
        )

        XCTAssertEqual(config.selectedLaunchExecutablePath, launch.executablePath)
        XCTAssertEqual(config.selectedLaunchExecutableLabel, "AnomalyDX11AVX.exe")
        XCTAssertEqual(config.setupRequest.launchBatches?.first, launch)
        XCTAssertEqual(config.setupRequest.launchBatches?.first?.usesModOrganizerEnvironment, false)
        XCTAssertEqual(config.setupRequest.launchArguments, #"--dxgi-old --profile "Gold""#)
    }

    func testEmptyLaunchArgumentsAreNotSerialized() {
        XCTAssertNil(SetupConfiguration(launchArguments: "   ").setupRequest.launchArguments)
    }

    func testCustomLaunchExecutableMustStillExist() throws {
        let temp = try makeTempDir("gamma-custom-launch")
        let executable = temp.appendingPathComponent("AnomalyDX11AVX.exe")
        FileManager.default.createFile(atPath: executable.path, contents: Data())
        let launch = LaunchBatch(batchPath: "/Anomaly.bat", executablePath: executable.path)

        XCTAssertTrue(SetupConfiguration(programBatch: launch.batchPath, launchBatches: [launch]).selectedLaunchExecutableFound)
        try FileManager.default.removeItem(at: executable)
        XCTAssertFalse(SetupConfiguration(programBatch: launch.batchPath, launchBatches: [launch]).selectedLaunchExecutableFound)
        try? FileManager.default.removeItem(at: temp)
    }

    func testCustomModOrganizerLaunchRequestsEnvironment() {
        let launch = LaunchBatch(
            batchPath: "/Alternate MO2.bat",
            executablePath: "/Games/Alternate/ModOrganizer.exe",
            usesModOrganizerEnvironment: true
        )

        XCTAssertEqual(launch.usesModOrganizerEnvironment, true)
    }

    func testSetupRequestIncludesDisplayResolutionOptions() {
        let defaultWine = SetupConfiguration(displayMode: "defaultWine")
        XCTAssertEqual(defaultWine.displayResolutionLabel, "Default")
        XCTAssertNil(defaultWine.setupRequest.displayResolutionWidth)
        XCTAssertNil(defaultWine.setupRequest.displayResolutionHeight)
        XCTAssertEqual(defaultWine.setupRequest.resetWineDisplay, true)

        let config = SetupConfiguration(
            displayMode: "forced",
            displayResolutionMode: "1920x1080"
        )

        XCTAssertEqual(config.displayResolutionLabel, "1920 x 1080")
        XCTAssertEqual(config.setupRequest.displayResolutionWidth, 1920)
        XCTAssertEqual(config.setupRequest.displayResolutionHeight, 1080)
        XCTAssertEqual(config.setupRequest.resetWineDisplay, false)
    }

    func testEngineLabels() {
        XCTAssertEqual(SetupConfiguration(engine: SetupConfiguration.crossOverEngine).engineLabel, "Wine CX 24.0.7")
        XCTAssertEqual(SetupConfiguration(engine: SetupConfiguration.sikarugir10Engine).engineLabel, "Wine Sikarugir 10.0")
    }

    func testSetupRequestIncludesVerboseLogOption() {
        let config = SetupConfiguration(saveVerboseLog: true)

        XCTAssertTrue(config.setupRequest.writeLog)
        XCTAssertTrue(config.setupRequest.verbose)
    }

    func testDriveMappingShortenMode() {
        let mo2Path = "/Users/me/Games/GAMMA/ModOrganizer.exe"
        let preserve = SetupConfiguration(
            driveMappingMode: "preserve",
            manualModOrganizerPath: mo2Path
        )
        XCTAssertEqual(preserve.plannedWineDriveMapping, "Z: -> /")
        XCTAssertTrue(preserve.driveMappingReady)
        XCTAssertEqual(preserve.setupRequest.driveMappingMode, "preserve")

        let shorten = SetupConfiguration(
            driveMappingMode: "shorten",
            manualModOrganizerPath: mo2Path
        )
        XCTAssertEqual(shorten.plannedWineDriveMapping, "G: -> /Users/me/Games")
        XCTAssertEqual(shorten.optionalGDriveRoot, "/Users/me/Games")
        XCTAssertTrue(shorten.driveMappingReady)
        XCTAssertEqual(shorten.setupRequest.driveMappingMode, "shorten")

        XCTAssertFalse(SetupConfiguration(driveMappingMode: "shorten").driveMappingReady)
    }

    func testDriveMappingIsReadyWhenPreflightContextIsAbsent() {
        XCTAssertTrue(SetupConfiguration().driveMappingReady)
    }

    func testEnvironmentMessagesForMissingInputs() {
        XCTAssertFalse(SetupConfiguration().environmentOK)

        var missingBrew = Preflight.fixture()
        missingBrew.homebrewFound = false
        XCTAssertFalse(SetupConfiguration(preflight: missingBrew).canInstallComponents)

        var missingGamma = Preflight.fixture()
        missingGamma.gammaFound = false
        XCTAssertFalse(SetupConfiguration(preflight: missingGamma).environmentOK)

        var missingMO2 = Preflight.fixture()
        missingMO2.mo2Found = false
        XCTAssertFalse(SetupConfiguration(preflight: missingMO2).environmentOK)
    }
}

private func makeTempDir(_ prefix: String) throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private extension Preflight {
    static func fixture() -> Preflight {
        Preflight(
            targetApp: "/Applications/stalker-gamma.app",
            engine: "WS12WineCX24.0.7_7",
            renderer: "d3dmetal",
            programBatch: "/mo2.bat",
            stalkerGammaPath: "/opt/homebrew/bin/stalker-gamma",
            stalkerGammaFound: true,
            settingsFile: "/Users/me/Library/Application Support/stalker-gamma/settings.json",
            settingsFound: true,
            gammaPath: "/Users/me/Games/GAMMA",
            gammaFound: true,
            mo2Path: "/Users/me/Games/GAMMA/ModOrganizer.exe",
            mo2Found: true,
            anomalyPath: "/Users/me/Games/Anomaly",
            anomalyFound: true,
            mo2Profile: "Default",
            modlistPath: "/Users/me/Games/GAMMA/profiles/Default/modlist.txt",
            modlistFound: true,
            modOrganizerIni: "/Users/me/Games/GAMMA/ModOrganizer.ini",
            modOrganizerIniFound: true,
            modOrganizerGamePath: "G:/Anomaly",
            wineDriveLetter: "G",
            wineDriveRoot: "/Users/me/Games",
            zRewriteRequired: false,
            zShortenAvailable: false,
            shortWineDriveLetter: "G",
            shortWineDriveRoot: "/Users/me/Games",
            homebrewPath: "/opt/homebrew/bin/brew",
            homebrewFound: true,
            sikarugirTapInstalled: true,
            sikarugirInstalled: true,
            winetricksPath: "/opt/homebrew/bin/winetricks",
            winetricksFound: true
        )
    }
}
