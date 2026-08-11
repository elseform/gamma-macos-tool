import Foundation

public enum SetupEngineStage: String, Codable, CaseIterable {
    case dependencies
    case wrapper
    case engine
    case prefix
    case driveMapping
    case winetricks
    case finalize
}

public enum SetupEngineEventType: String, Codable {
    case log
    case stageStarted
    case stageFinished
    case stageFailed
    case artifact
    case completed
}

public enum SetupCompatibilityProfile: String, Codable {
    case standard
    case xrayD3DMetal = "xray-d3dmetal"

    public var requiredVerbs: [String] {
        switch self {
        case .standard:
            return ["corefonts", "d3dx9_43", "d3dx11_43", "d3dcompiler_47", "vcrun2026"]
        case .xrayD3DMetal:
            return ["d3dx9_43", "d3dx11_43", "d3dcompiler_47", "vcrun2026", "win10", "sound=coreaudio"]
        }
    }
}

public enum SetupRegistryDefaults {
    public static let requiredDllOverrides: [String: String] = [
        "*concrt140": "native,builtin",
        "*d3dcompiler_47": "native,builtin",
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
        "*d3dx9_43": "native,builtin",
        "*d3dx10_43": "native,builtin",
        "*d3dx11_43": "native,builtin",
        "*d3dcompiler_43": "native,builtin",
        "*xinput1_3": "native,builtin",
    ]

    public static let xrayD3DMetalDllOverrides: [String: String] = [
        "*concrt140": "native,builtin",
        "*d3dcompiler_47": "native,builtin",
        "*d3dx9_43": "native,builtin",
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
        "winemenubuilder.exe": "",
    ]

    public static func dllOverrides(for profile: SetupCompatibilityProfile) -> [String: String] {
        switch profile {
        case .standard:
            return requiredDllOverrides
        case .xrayD3DMetal:
            return xrayD3DMetalDllOverrides
        }
    }
}

public struct SetupEngineEvent: Codable {
    public var type: SetupEngineEventType
    public var stage: SetupEngineStage?
    public var message: String?
    public var severity: String?
    public var path: String?
    public var success: Bool?

    public init(
        type: SetupEngineEventType,
        stage: SetupEngineStage? = nil,
        message: String? = nil,
        severity: String? = nil,
        path: String? = nil,
        success: Bool? = nil
    ) {
        self.type = type
        self.stage = stage
        self.message = message
        self.severity = severity
        self.path = path
        self.success = success
    }
}

public struct Preflight: Codable {
    public var targetApp: String
    public var engine: String
    public var renderer: String
    public var programBatch: String
    public var stalkerGammaPath: String
    public var stalkerGammaFound: Bool
    public var settingsFile: String
    public var settingsFound: Bool
    public var gammaPath: String
    public var gammaFound: Bool
    public var mo2Path: String
    public var mo2Found: Bool
    public var anomalyPath: String
    public var anomalyFound: Bool
    public var mo2Profile: String
    public var modlistPath: String
    public var modlistFound: Bool
    public var modOrganizerIni: String
    public var modOrganizerIniFound: Bool
    public var modOrganizerGamePath: String
    public var wineDriveLetter: String
    public var wineDriveRoot: String
    public var zRewriteRequired: Bool
    public var zShortenAvailable: Bool
    public var shortWineDriveLetter: String
    public var shortWineDriveRoot: String
    public var homebrewPath: String
    public var homebrewFound: Bool
    public var sikarugirTapInstalled: Bool
    public var sikarugirInstalled: Bool
    public var winetricksPath: String
    public var winetricksFound: Bool

    public init(
        targetApp: String,
        engine: String,
        renderer: String,
        programBatch: String,
        stalkerGammaPath: String,
        stalkerGammaFound: Bool,
        settingsFile: String,
        settingsFound: Bool,
        gammaPath: String,
        gammaFound: Bool,
        mo2Path: String,
        mo2Found: Bool,
        anomalyPath: String,
        anomalyFound: Bool,
        mo2Profile: String,
        modlistPath: String,
        modlistFound: Bool,
        modOrganizerIni: String,
        modOrganizerIniFound: Bool,
        modOrganizerGamePath: String,
        wineDriveLetter: String,
        wineDriveRoot: String,
        zRewriteRequired: Bool,
        zShortenAvailable: Bool,
        shortWineDriveLetter: String,
        shortWineDriveRoot: String,
        homebrewPath: String,
        homebrewFound: Bool,
        sikarugirTapInstalled: Bool,
        sikarugirInstalled: Bool,
        winetricksPath: String,
        winetricksFound: Bool
    ) {
        self.targetApp = targetApp
        self.engine = engine
        self.renderer = renderer
        self.programBatch = programBatch
        self.stalkerGammaPath = stalkerGammaPath
        self.stalkerGammaFound = stalkerGammaFound
        self.settingsFile = settingsFile
        self.settingsFound = settingsFound
        self.gammaPath = gammaPath
        self.gammaFound = gammaFound
        self.mo2Path = mo2Path
        self.mo2Found = mo2Found
        self.anomalyPath = anomalyPath
        self.anomalyFound = anomalyFound
        self.mo2Profile = mo2Profile
        self.modlistPath = modlistPath
        self.modlistFound = modlistFound
        self.modOrganizerIni = modOrganizerIni
        self.modOrganizerIniFound = modOrganizerIniFound
        self.modOrganizerGamePath = modOrganizerGamePath
        self.wineDriveLetter = wineDriveLetter
        self.wineDriveRoot = wineDriveRoot
        self.zRewriteRequired = zRewriteRequired
        self.zShortenAvailable = zShortenAvailable
        self.shortWineDriveLetter = shortWineDriveLetter
        self.shortWineDriveRoot = shortWineDriveRoot
        self.homebrewPath = homebrewPath
        self.homebrewFound = homebrewFound
        self.sikarugirTapInstalled = sikarugirTapInstalled
        self.sikarugirInstalled = sikarugirInstalled
        self.winetricksPath = winetricksPath
        self.winetricksFound = winetricksFound
    }
}

public struct SetupRequest: Codable {
    public var appName: String
    public var outputApp: String
    public var engine: String
    public var renderer: String
    public var updateUSVFS: Bool
    public var installGPTK4Binaries: Bool
    public var installDirectXBinaries: Bool
    public var compatibilityProfile: SetupCompatibilityProfile?
    public var mo2Path: String
    public var gammaPath: String
    public var anomalyPath: String
    public var programBatch: String
    public var launchBatches: [LaunchBatch]?
    public var launchArguments: String?
    public var driveMappingMode: String
    public var forceRetinaOff: Bool?
    public var writeLog: Bool
    public var verbose: Bool
    public var dryRun: Bool
    public var forceDownload: Bool
    public var replace: Bool
    public var settingsFile: String
    public var usvfsSource: String
    public var appIconSource: String
    public var resourceRoot: String

    public init(
        appName: String = "stalker-gamma",
        outputApp: String,
        engine: String = SetupDefaults.defaultEngine,
        renderer: String = "d3dmetal",
        updateUSVFS: Bool = true,
        installGPTK4Binaries: Bool = true,
        installDirectXBinaries: Bool = false,
        compatibilityProfile: SetupCompatibilityProfile? = nil,
        mo2Path: String = "",
        gammaPath: String = "",
        anomalyPath: String = "",
        programBatch: String = "/mo2.bat",
        launchBatches: [LaunchBatch] = [],
        launchArguments: String? = nil,
        driveMappingMode: String = "preserve",
        forceRetinaOff: Bool? = false,
        writeLog: Bool = false,
        verbose: Bool = false,
        dryRun: Bool = false,
        forceDownload: Bool = false,
        replace: Bool = false,
        settingsFile: String = SetupDefaults.defaultSettingsFile,
        usvfsSource: String = SetupDefaults.defaultUSVFSSource,
        appIconSource: String = "",
        resourceRoot: String = ""
    ) {
        self.appName = appName
        self.outputApp = outputApp
        self.engine = engine
        self.renderer = renderer
        self.updateUSVFS = updateUSVFS
        self.installGPTK4Binaries = installGPTK4Binaries
        self.installDirectXBinaries = installDirectXBinaries
        self.compatibilityProfile = compatibilityProfile
        self.mo2Path = mo2Path
        self.gammaPath = gammaPath
        self.anomalyPath = anomalyPath
        self.programBatch = programBatch
        self.launchBatches = launchBatches
        self.launchArguments = launchArguments
        self.driveMappingMode = driveMappingMode
        self.forceRetinaOff = forceRetinaOff
        self.writeLog = writeLog
        self.verbose = verbose
        self.dryRun = dryRun
        self.forceDownload = forceDownload
        self.replace = replace
        self.settingsFile = settingsFile
        self.usvfsSource = usvfsSource
        self.appIconSource = appIconSource
        self.resourceRoot = resourceRoot
    }
}

public struct LaunchBatch: Codable, Identifiable, Equatable {
    public var id: String { batchPath }
    public var batchPath: String
    public var executablePath: String
    public var workingDirectory: String
    public var usesModOrganizerEnvironment: Bool?

    public init(
        batchPath: String,
        executablePath: String,
        workingDirectory: String = "",
        usesModOrganizerEnvironment: Bool = false
    ) {
        self.batchPath = batchPath
        self.executablePath = executablePath
        self.workingDirectory = workingDirectory
        self.usesModOrganizerEnvironment = usesModOrganizerEnvironment
    }
}

public enum SetupDefaults {
    public static let crossOverEngine = "WS12WineCX24.0.7_7"
    public static let sikarugir10Engine = "WS12WineSikarugir10.0_6"
    public static let defaultEngine = sikarugir10Engine
    public static let supportedEngines = [defaultEngine, crossOverEngine]
    public static let defaultUSVFSSource = ""
    public static let defaultSettingsFile = NSString(
        string: "~/Library/Application Support/stalker-gamma/settings.json"
    ).expandingTildeInPath
}
