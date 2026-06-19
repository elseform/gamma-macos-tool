final class SetupConfigurationTests {
    func testOutputAppPathAddsAppSuffix() {
        let config = SetupConfiguration(appName: "stalker-gamma", installDirectory: "/tmp/Sikarugir")

        XCTAssertEqual(config.outputAppPath, "/tmp/Sikarugir/stalker-gamma.app")
    }

    func testOutputAppPathDoesNotDuplicateAppSuffix() {
        let config = SetupConfiguration(appName: "  stalker-gamma.app  ", installDirectory: "/tmp/Sikarugir")

        XCTAssertEqual(config.outputAppPath, "/tmp/Sikarugir/stalker-gamma.app")
    }

    func testRendererLabels() {
        XCTAssertEqual(SetupConfiguration(renderer: "d3dmetal").rendererLabel, "D3DMetal")
        XCTAssertEqual(SetupConfiguration(renderer: "dxmt").rendererLabel, "DXMT")
        XCTAssertEqual(SetupConfiguration(renderer: "dxvk").rendererLabel, "DXVK")
    }

    func testEnvironmentOKRequiresAllRequiredInputs() {
        XCTAssertTrue(SetupConfiguration(preflight: .fixture()).environmentOK)

        var missingMO2Ini = Preflight.fixture()
        missingMO2Ini.modOrganizerIniFound = false

        XCTAssertFalse(SetupConfiguration(preflight: missingMO2Ini).environmentOK)

        var missingCli = Preflight.fixture()
        missingCli.stalkerGammaFound = false
        XCTAssertTrue(SetupConfiguration(preflight: missingCli).environmentOK)

        var missingSettings = Preflight.fixture()
        missingSettings.settingsFound = false
        XCTAssertTrue(SetupConfiguration(preflight: missingSettings).environmentOK)

        var missingAnomaly = Preflight.fixture()
        missingAnomaly.anomalyFound = false
        XCTAssertTrue(SetupConfiguration(preflight: missingAnomaly).environmentOK)

        XCTAssertFalse(SetupConfiguration().environmentOK)
    }

    func testCanInstallComponentsOnlyWhenBrewManagedDependenciesAreMissing() {
        XCTAssertFalse(SetupConfiguration(preflight: .fixture()).canInstallComponents)

        var missingWinetricks = Preflight.fixture()
        missingWinetricks.winetricksFound = false
        XCTAssertTrue(SetupConfiguration(preflight: missingWinetricks).canInstallComponents)

        var missingHomebrew = missingWinetricks
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
        XCTAssertTrue(config.setupRequest.wineESync)
        XCTAssertTrue(config.setupRequest.wineMSync)
    }

    func testDefaultsMatchPlaytestedSikarugirWrapper() {
        let config = SetupConfiguration()

        XCTAssertEqual(config.engine, SetupConfiguration.sikarugir10Engine)
        XCTAssertEqual(config.renderer, "d3dmetal")
        XCTAssertTrue(config.wineESync)
        XCTAssertTrue(config.wineMSync)
        XCTAssertFalse(config.enableHIDDevices)
        XCTAssertFalse(config.enableFnToggle)
        XCTAssertFalse(config.moltenVKFastMath)
        XCTAssertFalse(config.metalHUD)
        XCTAssertEqual(config.displayMode, "forced")
    }

    func testSetupRequestIncludesWineSyncOptions() {
        let config = SetupConfiguration(wineESync: false, wineMSync: false)

        XCTAssertFalse(config.setupRequest.wineESync)
        XCTAssertFalse(config.setupRequest.wineMSync)
    }

    func testSetupRequestIncludesHIDDevicesOption() {
        XCTAssertEqual(SetupConfiguration().setupRequest.enableHIDDevices, false)
        XCTAssertEqual(SetupConfiguration(enableHIDDevices: true).setupRequest.enableHIDDevices, true)
    }

    func testSetupRequestIncludesFnToggleOption() {
        XCTAssertEqual(SetupConfiguration().setupRequest.enableFnToggle, false)
        XCTAssertEqual(SetupConfiguration(enableFnToggle: true).setupRequest.enableFnToggle, true)
    }

    func testSetupRequestIncludesUSVFSUpdateOption() {
        XCTAssertFalse(SetupConfiguration(engine: SetupConfiguration.defaultEngine).setupRequest.updateUSVFS)
        XCTAssertTrue(SetupConfiguration(engine: SetupConfiguration.defaultEngine, updateUSVFS: true).setupRequest.updateUSVFS)
        XCTAssertFalse(SetupConfiguration(engine: SetupConfiguration.sikarugir10Engine).setupRequest.updateUSVFS)
        XCTAssertTrue(SetupConfiguration(engine: SetupConfiguration.sikarugir10Engine, updateUSVFS: true).setupRequest.updateUSVFS)
        XCTAssertEqual(SetupConfiguration(engine: SetupConfiguration.sikarugir10Engine).setupRequest.usvfsSource, "")
    }

    func testSetupRequestIncludesManualModOrganizerWhenProvided() {
        let config = SetupConfiguration(manualModOrganizerPath: "/Games/GAMMA/ModOrganizer.exe")

        XCTAssertEqual(config.setupRequest.mo2Path, "/Games/GAMMA/ModOrganizer.exe")
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
        let config = SetupConfiguration(programBatch: launch.batchPath, launchBatches: [launch])

        XCTAssertEqual(config.selectedLaunchExecutablePath, launch.executablePath)
        XCTAssertEqual(config.selectedLaunchExecutableLabel, "AnomalyDX11AVX.exe")
        XCTAssertEqual(config.setupRequest.launchBatches?.first, launch)
        XCTAssertEqual(config.setupRequest.launchBatches?.first?.usesModOrganizerEnvironment, false)
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
        XCTAssertEqual(defaultWine.displayResolutionLabel, "Default Wine")
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
        XCTAssertEqual(config.setupRequest.useWineVirtualDesktop, false)
        XCTAssertEqual(config.setupRequest.resetWineDisplay, false)
    }

    func testEngineLabels() {
        XCTAssertEqual(SetupConfiguration(engine: SetupConfiguration.crossOverEngine).engineLabel, "Wine CX 24.0.7")
        XCTAssertEqual(SetupConfiguration(engine: SetupConfiguration.sikarugir10Engine).engineLabel, "Wine Sikarugir 10.0")
    }

    func testD3DMetalSetupRequestOptions() {
        let config = SetupConfiguration(
            moltenVKFastMath: true,
            metalHUD: true,
            extraWinetricks: "  quartz dinput8  ",
            applyReticleFix: true,
            saveVerboseLog: true
        )

        XCTAssertEqual(config.setupRequest.extraWinetricks, ["quartz", "dinput8"])
        XCTAssertTrue(config.setupRequest.moltenVKFastMath)
        XCTAssertTrue(config.setupRequest.metalHUD)
        XCTAssertTrue(config.setupRequest.writeLog)
        XCTAssertTrue(config.setupRequest.verbose)
        XCTAssertEqual(config.setupRequest.commonFixes, ["d3dmetal-reticle"])
    }

    func testDXMTSetupRequestOptions() {
        let config = SetupConfiguration(
            renderer: "dxmt",
            dxmtMetalFXSpatial: true,
            dxmtMetalFXScaleFactor: " 1.5 ",
            dxmtLogLevel: "debug"
        )

        XCTAssertTrue(config.setupRequest.dxmtMetalFXSpatial)
        XCTAssertEqual(config.setupRequest.dxmtMetalFXScaleFactor, "1.5")
        XCTAssertEqual(config.setupRequest.dxmtLogLevel, "debug")
    }

    func testDXVKSetupRequestOptionsRequireHUDToggleForHUDContents() {
        let noHUDToggle = SetupConfiguration(renderer: "dxvk", dxvkHUD: "fps")
        XCTAssertEqual(noHUDToggle.setupRequest.dxvkHUD, "")

        let withHUDToggle = SetupConfiguration(renderer: "dxvk", metalHUD: true, dxvkHUD: "fps")
        XCTAssertEqual(withHUDToggle.setupRequest.dxvkHUD, "fps")
    }

    func testDriveMappingShortenMode() {
        var preflight = Preflight.fixture()
        preflight.zRewriteRequired = true
        preflight.zShortenAvailable = true
        preflight.modOrganizerGamePath = "Z:\\Users\\me\\Games\\Anomaly"
        preflight.wineDriveLetter = "Z"
        preflight.wineDriveRoot = "/"
        preflight.shortWineDriveLetter = "G"
        preflight.shortWineDriveRoot = "/Users/me/Games"

        let preserve = SetupConfiguration(driveMappingMode: "preserve", preflight: preflight)
        XCTAssertEqual(preserve.plannedWineDriveMapping, "Z: -> /")
        XCTAssertEqual(preserve.plannedModOrganizerGamePath, "Z:\\Users\\me\\Games\\Anomaly")
        XCTAssertFalse(preserve.willRewriteModOrganizerIni)
        XCTAssertFalse(preserve.driveMappingReady)
        XCTAssertEqual(preserve.setupRequest.driveMappingMode, "preserve")

        let shorten = SetupConfiguration(driveMappingMode: "shorten", preflight: preflight)
        XCTAssertEqual(shorten.plannedWineDriveMapping, "G: -> /Users/me/Games")
        XCTAssertEqual(shorten.plannedModOrganizerGamePath, "G:\\Anomaly")
        XCTAssertTrue(shorten.willRewriteModOrganizerIni)
        XCTAssertTrue(shorten.driveMappingReady)
        XCTAssertEqual(shorten.setupRequest.driveMappingMode, "shorten")
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

private extension Preflight {
    static func fixture() -> Preflight {
        Preflight(
            targetApp: "/Applications/stalker-gamma.app",
            engine: "WS12WineCX24.0.7_7",
            renderer: "d3dmetal",
            moltenVKFastMath: false,
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
