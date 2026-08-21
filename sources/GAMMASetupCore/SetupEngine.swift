import Darwin
import Foundation

public enum SetupEngineError: Error, CustomStringConvertible {
    case message(String)

    public var description: String {
        switch self {
        case .message(let value): return value
        }
    }
}

public final class JSONEventReporter {
    private let encoder = JSONEncoder()
    private var logURL: URL?
    private let streamEvents: Bool

    public init(streamEvents: Bool = true) {
        self.streamEvents = streamEvents
        encoder.outputFormatting = [.sortedKeys]
    }

    public func attachLog(_ url: URL) throws {
        logURL = url
        try "gamma-setup-engine log\nStarted: \(Date())\n\n".write(to: url, atomically: true, encoding: .utf8)
        emit(.init(type: .artifact, message: "Log file", path: url.path))
    }

    public func log(_ message: String, severity: String = "info") {
        emit(.init(type: .log, message: message, severity: severity))
    }

    public func stageStarted(_ stage: SetupEngineStage) {
        emit(.init(type: .stageStarted, stage: stage))
    }

    public func stageFinished(_ stage: SetupEngineStage) {
        emit(.init(type: .stageFinished, stage: stage))
    }

    public func stageFailed(_ stage: SetupEngineStage, message: String) {
        emit(.init(type: .stageFailed, stage: stage, message: message, severity: "error"))
    }

    public func completed(success: Bool, message: String) {
        emit(.init(type: .completed, message: message, success: success))
    }

    private func emit(_ event: SetupEngineEvent) {
        guard let data = try? encoder.encode(event),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        if streamEvents {
            FileHandle.standardOutput.write(Data((text + "\n").utf8))
        }
        if let logURL {
            let line = event.message ?? event.type.rawValue
            if let data = "[\(event.type.rawValue)] \(line)\n".data(using: .utf8),
               let handle = try? FileHandle(forWritingTo: logURL) {
                _ = try? handle.seekToEnd()
                _ = try? handle.write(contentsOf: data)
                _ = try? handle.close()
            }
        }
    }
}

struct CommandResult {
    var output: String
    var exitCode: Int32
}

struct ProcessRunner {
    var dryRun: Bool
    var verbose: Bool
    var reporter: JSONEventReporter?

    @discardableResult
    func run(_ executable: String, _ arguments: [String], environment: [String: String]? = nil, label: String? = nil) throws -> CommandResult {
        if dryRun {
            if verbose {
                reporter?.log("dry-run: " + ([executable] + arguments).map(shellQuote).joined(separator: " "))
            }
            return CommandResult(output: "", exitCode: 0)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment {
            var merged = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                merged[key] = value
            }
            process.environment = merged
        }

        let command = ([executable] + arguments).map(shellQuote).joined(separator: " ")
        if verbose {
            reporter?.log("run: \(command)")
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw SetupEngineError.message("\(label ?? command) failed\(detail.isEmpty ? "" : ": \(detail)")")
        }
        if verbose {
            let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !detail.isEmpty {
                reporter?.log("\(label ?? executable) output:\n\(detail)")
            }
        }
        return CommandResult(output: output, exitCode: process.terminationStatus)
    }

    private func shellQuote(_ value: String) -> String {
        if value.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines) == nil && !value.isEmpty {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

struct SetupContext {
    var request: SetupRequest
    var outputApp: URL
    var contents: URL
    var resources: URL
    var sharedSupport: URL
    var prefix: URL
    var wineDir: URL
    var wineBin: URL
    var wineServerBin: URL
    var driveC: URL
    var dosdevices: URL
    var userReg: URL
    var systemReg: URL
    var appLogDir: URL
    var scriptRoot: URL
    var cacheDir: URL
    var sikarugirSupport: URL
    var templateName = ""
    var templateSource: URL?
    var engineArchive: URL?
    var mo2Path = ""
    var gammaPath = ""
    var anomalyPath = ""
    var mo2ProfileName = ""
    var mo2IniPath = ""
    var mo2IniGamePathWin = ""
    var mo2IniDriveLetter = ""
    var mo2IniDriveRoot = ""
    var zRewriteRequired = false
    var driveLetter = "g"
    var driveRoot = ""

    var appSupportDirectory: URL {
        URL(
            fileURLWithPath: NSString(
                string: "~/Library/Application Support/gamma-setup-tool"
            ).expandingTildeInPath
        )
    }

    var managedWinetricks: URL {
        appSupportDirectory.appendingPathComponent("cache/winetricks/winetricks")
    }

    var winetricksDownloadCache: URL {
        appSupportDirectory.appendingPathComponent("cache/winetricks/downloads")
    }

    init(request: SetupRequest, executablePath: String) {
        let outputApp = URL(fileURLWithPath: request.outputApp)
        self.request = request
        self.outputApp = outputApp
        self.contents = outputApp.appendingPathComponent("Contents")
        self.resources = outputApp.appendingPathComponent("Contents/Resources")
        self.sharedSupport = outputApp.appendingPathComponent("Contents/SharedSupport")
        self.prefix = outputApp.appendingPathComponent("Contents/SharedSupport/prefix")
        self.wineDir = outputApp.appendingPathComponent("Contents/SharedSupport/wine")
        self.wineBin = outputApp.appendingPathComponent("Contents/SharedSupport/wine/bin/wine")
        self.wineServerBin = outputApp.appendingPathComponent("Contents/SharedSupport/wine/bin/wineserver")
        self.driveC = outputApp.appendingPathComponent("Contents/SharedSupport/prefix/drive_c")
        self.dosdevices = outputApp.appendingPathComponent("Contents/SharedSupport/prefix/dosdevices")
        self.userReg = outputApp.appendingPathComponent("Contents/SharedSupport/prefix/user.reg")
        self.systemReg = outputApp.appendingPathComponent("Contents/SharedSupport/prefix/system.reg")
        self.appLogDir = outputApp.appendingPathComponent("Contents/SharedSupport/Logs")
        let executableURL = URL(fileURLWithPath: executablePath)
        if request.resourceRoot.isEmpty {
            self.scriptRoot = executableURL.deletingLastPathComponent()
        } else {
            self.scriptRoot = URL(fileURLWithPath: request.resourceRoot)
        }
        self.cacheDir = URL(fileURLWithPath: NSString(string: "~/Library/Caches/stalker-gamma-sikarugir-setup").expandingTildeInPath)
        self.sikarugirSupport = URL(fileURLWithPath: NSString(string: "~/Library/Application Support/Sikarugir").expandingTildeInPath)
    }
}

public final class GAMMASetupEngine {
    private let fileManager = FileManager.default
    private let executablePath: String
    private let reporter: JSONEventReporter

    public init(executablePath: String, reporter: JSONEventReporter = JSONEventReporter()) {
        self.executablePath = executablePath
        self.reporter = reporter
    }

    public func preflight(request: SetupRequest) throws -> Preflight {
        var context = SetupContext(request: request, executablePath: executablePath)
        try loadGammaSettings(context: &context, required: false, preflightOnly: true)
        resolveDriveRoot(context: &context)

        let brewPath = findTool("brew") ?? ""
        let winetricksPath = findTool("winetricks") ?? ""
        let stalkerGammaPath = findTool("stalker-gamma") ?? ""
        var tapInstalled = false
        var sikarugirInstalled = false
        if !brewPath.isEmpty {
            tapInstalled = (try? ProcessRunner(dryRun: false, verbose: false).run(brewPath, ["tap"]).output.split(whereSeparator: \.isNewline).contains("sikarugir-app/sikarugir")) ?? false
            sikarugirInstalled = ((try? ProcessRunner(dryRun: false, verbose: false).run(brewPath, ["list", "--cask", "sikarugir"])) != nil)
        }

        let shortRoot = zShortRoot(context: context)
        let modlist = activeModlistPath(context: context)
        return Preflight(
            targetApp: request.outputApp,
            engine: request.engine,
            renderer: request.renderer,
            programBatch: request.programBatch,
            stalkerGammaPath: stalkerGammaPath,
            stalkerGammaFound: !stalkerGammaPath.isEmpty,
            settingsFile: request.settingsFile,
            settingsFound: fileManager.fileExists(atPath: request.settingsFile),
            gammaPath: context.gammaPath,
            gammaFound: directoryExists(context.gammaPath),
            mo2Path: context.mo2Path,
            mo2Found: fileManager.fileExists(atPath: context.mo2Path),
            anomalyPath: context.anomalyPath,
            anomalyFound: directoryExists(context.anomalyPath),
            mo2Profile: context.mo2ProfileName,
            modlistPath: modlist,
            modlistFound: fileManager.fileExists(atPath: modlist),
            modOrganizerIni: context.mo2IniPath,
            modOrganizerIniFound: fileManager.fileExists(atPath: context.mo2IniPath),
            modOrganizerGamePath: context.mo2IniGamePathWin,
            wineDriveLetter: context.driveLetter.uppercased(),
            wineDriveRoot: context.driveRoot,
            zRewriteRequired: context.zRewriteRequired,
            zShortenAvailable: !shortRoot.isEmpty,
            shortWineDriveLetter: "G",
            shortWineDriveRoot: shortRoot,
            homebrewPath: brewPath,
            homebrewFound: !brewPath.isEmpty,
            sikarugirTapInstalled: tapInstalled,
            sikarugirInstalled: sikarugirInstalled,
            winetricksPath: winetricksPath,
            winetricksFound: !winetricksPath.isEmpty
        )
    }

    public func installDependencies(request: SetupRequest) throws {
        let context = SetupContext(request: request, executablePath: executablePath)
        try setupLogIfNeeded(context: context)
        try ensureBrewDependencies(context: context)
        reporter.completed(success: true, message: "Setup components are installed.")
    }

    public func installDependency(name: String, request: SetupRequest) throws {
        let context = SetupContext(request: request, executablePath: executablePath)
        try setupLogIfNeeded(context: context)
        switch name {
        case "sikarugir":
            try ensureSikarugir(context: context)
            reporter.completed(success: true, message: "Sikarugir is installed.")
        case "winetricks":
            reporter.completed(success: true, message: "winetricks is resolved during wrapper setup.")
        default:
            throw SetupEngineError.message("unknown install dependency: \(name)")
        }
    }

    public func create(request: SetupRequest) throws {
        var context = SetupContext(request: request, executablePath: executablePath)
        try setupLogIfNeeded(context: context)
        try loadGammaSettings(context: &context, required: true, preflightOnly: false)
        try validateLaunchArguments(context.request.launchArguments)
        try validateSelectedLaunchExecutable(context: context)

        try runStage(.dependencies) {
            try ensureBrewDependencies(context: context)
            try resolveSikarugirAssets(context: &context)
        }
        try runStage(.wrapper) {
            try prepareTargetApp(context: &context)
            try ensureAppTemplateLayout(context: context)
            try installAppIcon(context: context)
            try ensureAppFrameworks(context: context)
            try configureAppPlist(context: context)
            try createConfigureAlias(context: context)
        }
        try runStage(.engine) {
            try installEngine(context: context)
            try installUSVFSUpdateForEngine(context: context)
            try installGPTK4Binaries(context: context)
            try installDXMTBinaries(context: context)
        }
        try runStage(.prefix) {
            try initializePrefix(context: context)
            try installDirectXBinaries(context: context)
            try configureWineGraphicsDriver(context: context)
            try configureWineDisplay(context: context)
        }
        try runStage(.driveMapping) {
            try configureDriveMapping(context: &context)
        }
        try runStage(.winetricks) {
            try installWinetricksDependencies(context: context)
            try configureDllOverrides(context: context)
        }
        try runStage(.finalize) {
            try createMO2Batch(context: &context)
            try createLaunchBatches(context: &context)
            try normalizeAppPermissions(context: context)
            try refreshAppRegistration(context: context)
            try verifyOutputs(context: context)
        }
        reporter.completed(success: true, message: "Sikarugir wrapper setup is completed.")
    }

    func createForTesting(request: SetupRequest, templateSource: URL, templateName: String) throws {
        var context = SetupContext(request: request, executablePath: executablePath)
        context.templateSource = templateSource
        context.templateName = templateName
        try prepareTargetApp(context: &context)
        try ensureAppTemplateLayout(context: context)
    }

    func configureWrapperForTesting(request: SetupRequest, templateSource: URL, templateName: String) throws {
        var context = SetupContext(request: request, executablePath: executablePath)
        context.templateSource = templateSource
        context.templateName = templateName
        try prepareTargetApp(context: &context)
        try ensureAppTemplateLayout(context: context)
        try configureAppPlist(context: context)
        try createConfigureAlias(context: context)
    }

    func installUSVFSForTesting(request: SetupRequest) throws {
        var context = SetupContext(request: request, executablePath: executablePath)
        context.mo2Path = request.mo2Path
        try installUSVFSUpdateForEngine(context: context)
    }

    func installGPTK4ForTesting(request: SetupRequest) throws {
        let context = SetupContext(request: request, executablePath: executablePath)
        try installGPTK4Binaries(context: context)
    }

    func installDXMTForTesting(request: SetupRequest) throws {
        let context = SetupContext(request: request, executablePath: executablePath)
        try installDXMTBinaries(context: context)
    }

    func configureDriveMappingAndMO2BatchForTesting(request: SetupRequest) throws {
        var context = SetupContext(request: request, executablePath: executablePath)
        try validateLaunchArguments(context.request.launchArguments)
        context.mo2Path = absolutePath(request.mo2Path)
        context.gammaPath = request.gammaPath.isEmpty
            ? URL(fileURLWithPath: context.mo2Path).deletingLastPathComponent().path
            : absolutePath(request.gammaPath)
        context.anomalyPath = request.anomalyPath.isEmpty ? "" : absolutePath(request.anomalyPath)
        loadModOrganizerIni(context: &context)
        try fileManager.createDirectory(at: context.contents, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: context.driveC, withIntermediateDirectories: true)
        try configureDriveMapping(context: &context)
        try createMO2Batch(context: &context)
        try createLaunchBatches(context: &context)
    }

    func configureWineDisplayForTesting(request: SetupRequest, registry: String) throws -> String {
        let context = SetupContext(request: request, executablePath: executablePath)
        try fileManager.createDirectory(
            at: context.userReg.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try registry.write(to: context.userReg, atomically: true, encoding: .utf8)
        try configureWineDisplay(context: context)
        return try String(contentsOf: context.userReg)
    }

    func missingDllOverridesForTesting(
        registry: String,
        profile: SetupCompatibilityProfile = .standard
    ) -> [String] {
        missingDllOverrides(
            in: currentDllOverrides(in: registry),
            required: SetupRegistryDefaults.dllOverrides(for: profile)
        )
    }

    func winetricksCachePathsForTesting(request: SetupRequest) -> [String: String] {
        let context = SetupContext(request: request, executablePath: executablePath)
        return [
            "script": context.managedWinetricks.path,
            "downloads": wineEnvironment(context: context)["W_CACHE"] ?? ""
        ]
    }

    func payloadMatchesForTesting(source: URL, target: URL) -> Bool {
        directoryPayloadMatches(source: source, target: target)
    }

    private func runStage(_ stage: SetupEngineStage, _ work: () throws -> Void) throws {
        reporter.stageStarted(stage)
        do {
            try work()
            reporter.stageFinished(stage)
        } catch {
            reporter.stageFailed(stage, message: errorDescription(error))
            throw error
        }
    }

    private func setupLogIfNeeded(context: SetupContext) throws {
        guard context.request.writeLog else { return }
        let stamp = timestamp()
        let name = context.request.dryRun ? "gamma-setup-tool.dry-run.\(stamp).log" : "gamma-setup-tool.\(stamp).log"
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(name)
        try reporter.attachLog(url)
    }

    private func runner(context: SetupContext) -> ProcessRunner {
        ProcessRunner(dryRun: context.request.dryRun, verbose: context.request.verbose, reporter: reporter)
    }

    private func ensureBrewDependencies(context: SetupContext) throws {
        try ensureSikarugir(context: context)
    }

    private func ensureHomebrew() throws -> String {
        guard let brew = findTool("brew") else {
            throw SetupEngineError.message("Homebrew is required to install Sikarugir")
        }
        return brew
    }

    private func ensureSikarugir(context: SetupContext) throws {
        let brew = try ensureHomebrew()
        let taps = (try? runner(context: context).run(brew, ["tap"]).output) ?? ""
        if !taps.split(whereSeparator: \.isNewline).contains("sikarugir-app/sikarugir") {
            reporter.log("Installing Sikarugir Homebrew tap")
            try runner(context: context).run(brew, ["tap", "sikarugir-app/sikarugir"])
        }
        if (try? runner(context: context).run(brew, ["list", "--cask", "sikarugir"])) == nil {
            reporter.log("Installing Sikarugir Creator")
            try runner(context: context).run(brew, ["install", "--cask", "sikarugir"])
        }
    }

    private func resolveSikarugirAssets(context: inout SetupContext) throws {
        guard SetupDefaults.supportedEngines.contains(context.request.engine) else {
            throw SetupEngineError.message("unknown engine: \(context.request.engine)")
        }
        let templateName = try downloadText(
            label: "Sikarugir template version",
            url: "https://raw.githubusercontent.com/Sikarugir-App/Wrapper/main/NewestVersion.txt",
            fallback: "Template-1.0.11",
            context: context
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        context.templateName = templateName

        let localTemplate = context.sikarugirSupport.appendingPathComponent("Template/\(templateName).app")
        let localEngine = context.sikarugirSupport.appendingPathComponent("Engines/\(context.request.engine).tar.xz")
        if directoryExists(localTemplate.path), !context.request.forceDownload {
            context.templateSource = localTemplate
        } else {
            let archive = try downloadFile(
                label: "Sikarugir template \(templateName)",
                url: "https://github.com/Sikarugir-App/Wrapper/releases/download/v1.0/\(templateName).tar.xz",
                output: context.cacheDir.appendingPathComponent("sikarugir-template/\(templateName).tar.xz"),
                context: context
            )
            let templateSource = context.cacheDir.appendingPathComponent("sikarugir-template/\(templateName).app")
            if !context.request.dryRun, !directoryExists(templateSource.path) {
                let extracted = context.cacheDir.appendingPathComponent("sikarugir-template/extracted")
                try? fileManager.removeItem(at: extracted)
                try fileManager.createDirectory(at: extracted, withIntermediateDirectories: true)
                try runner(context: context).run("/usr/bin/tar", ["-xJf", archive.path, "-C", extracted.path], label: "extract Sikarugir template")
                guard let found = findFirstApp(named: "\(templateName).app", under: extracted) else {
                    throw SetupEngineError.message("template archive did not contain \(templateName).app")
                }
                try fileManager.moveItem(at: found, to: templateSource)
                try? fileManager.removeItem(at: extracted)
            }
            context.templateSource = templateSource
        }

        if fileManager.fileExists(atPath: localEngine.path), !context.request.forceDownload {
            context.engineArchive = localEngine
        } else {
            context.engineArchive = try downloadFile(
                label: "Sikarugir engine \(context.request.engine)",
                url: "https://github.com/Sikarugir-App/Engines/releases/download/v1.0/\(context.request.engine).tar.xz",
                output: context.cacheDir.appendingPathComponent("sikarugir-engine/\(context.request.engine).tar.xz"),
                context: context
            )
        }
    }

    private func prepareTargetApp(context: inout SetupContext) throws {
        let app = context.outputApp
        if fileManager.fileExists(atPath: app.path) {
            guard context.request.replace else {
                throw SetupEngineError.message("target already exists; choose a different wrapper name: \(app.path)")
            }
            try remove(app, context: context)
        }

        reporter.log("Creating Sikarugir wrapper at \(app.path)")
        try createDirectory(app.deletingLastPathComponent(), context: context)
        guard !context.request.dryRun else { return }
        guard let template = context.templateSource, directoryExists(template.path) else {
            throw SetupEngineError.message("Sikarugir template source was not found")
        }
        try fileManager.copyItem(at: template, to: app)
    }

    private func ensureAppTemplateLayout(context: SetupContext) throws {
        for path in ["Info.plist", "PkgInfo", "Configure.app", "MacOS", "Resources", "Logs", "drive_c"] {
            try restoreTemplatePath(path, context: context)
        }
    }

    private func restoreTemplatePath(_ relative: String, context: SetupContext) throws {
        let target = context.contents.appendingPathComponent(relative)
        guard !pathEntryExists(target) else { return }
        guard let template = context.templateSource else {
            throw SetupEngineError.message("Sikarugir template source was not resolved")
        }
        let source = template.appendingPathComponent("Contents/\(relative)")
        reporter.log("Restoring Sikarugir template \(relative)")
        guard !context.request.dryRun else { return }
        guard pathEntryExists(source) else {
            throw SetupEngineError.message("missing Sikarugir template path: \(source.path)")
        }
        try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: source, to: target)
    }

    private func installAppIcon(context: SetupContext) throws {
        reporter.log("Installing Anomaly app icon")
        let source = appIconSource(context: context)
        guard !context.request.dryRun else { return }
        guard fileManager.fileExists(atPath: source.path) else {
            throw SetupEngineError.message("missing app icon: \(source.path)")
        }
        try fileManager.createDirectory(at: context.resources, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: context.resources.appendingPathComponent(source.lastPathComponent))
        try fileManager.copyItem(at: source, to: context.resources.appendingPathComponent(source.lastPathComponent))
    }

    private func ensureAppFrameworks(context: SetupContext) throws {
        let requiredFramework = context.contents.appendingPathComponent("Frameworks/libinotify.0.dylib")
        let requiredShared = context.sharedSupport.appendingPathComponent("libinotify.0.dylib")
        if fileManager.fileExists(atPath: requiredFramework.path), fileManager.fileExists(atPath: requiredShared.path) {
            return
        }
        reporter.log("Restoring Sikarugir app frameworks")
        guard !context.request.dryRun else { return }
        guard let template = context.templateSource else {
            throw SetupEngineError.message("Sikarugir template source was not resolved")
        }
        let source = template.appendingPathComponent("Contents/Frameworks")
        guard directoryExists(source.path) else {
            throw SetupEngineError.message("missing Sikarugir template frameworks")
        }
        let target = context.contents.appendingPathComponent("Frameworks")
        if !directoryExists(target.path) {
            try fileManager.copyItem(at: source, to: target)
        }
        try fileManager.createDirectory(at: context.sharedSupport, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: requiredShared)
        try fileManager.copyItem(at: requiredFramework, to: requiredShared)
        let link = context.sharedSupport.appendingPathComponent("libinotify.dylib")
        try? fileManager.removeItem(at: link)
        try fileManager.createSymbolicLink(atPath: link.path, withDestinationPath: "libinotify.0.dylib")
    }

    private func configureAppPlist(context: SetupContext) throws {
        reporter.log("Configuring Sikarugir app plist")
        guard !context.request.dryRun else { return }
        let plistURL = context.contents.appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: plistURL)
        var format = PropertyListSerialization.PropertyListFormat.xml
        var plist = try PropertyListSerialization.propertyList(from: data, options: [.mutableContainersAndLeaves], format: &format) as? [String: Any] ?? [:]
        let bundleName = URL(fileURLWithPath: context.request.outputApp).deletingPathExtension().lastPathComponent
        let renderer = context.request.renderer
        plist["CFBundleName"] = bundleName
        plist["CFBundleDisplayName"] = bundleName
        plist["CFBundleIdentifier"] = "com.sikarugir." + bundleName.filter { $0.isLetter || $0.isNumber }
        plist["CFBundleIconFile"] = appIconSource(context: context).deletingPathExtension().lastPathComponent
        plist["Program Name and Path"] = context.request.programBatch
        plist["Program Flags"] = ""
        plist["D3DMETAL"] = renderer == "d3dmetal" ? "1" : "0"
        plist["WINEESYNC"] = "0"
        plist["WINEMSYNC"] = "1"
        plist["DXVK"] = renderer == "dxvk" ? "1" : "0"
        plist["DXMT"] = renderer == "dxmt" ? "1" : "0"
        plist["D9VK"] = "0"
        plist["CNC_DDRAW"] = "0"
        plist["Winetricks silent"] = "1"
        plist["Winetricks disable logging"] = "1"
        plist["WINEDEBUG"] = "-all"
        if context.request.compatibilityProfile == .xrayD3DMetal {
            plist["ADVERTISE_AVX"] = 1
            plist["METAL_HUD"] = 1
            plist["FASTMATH"] = 0
            plist["Try To Use GPU Info"] = 0
        }
        let out = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try out.write(to: plistURL, options: .atomic)
    }

    private func createConfigureAlias(context: SetupContext) throws {
        let configureApp = context.contents.appendingPathComponent("Configure.app")
        guard directoryExists(configureApp.path) else {
            throw SetupEngineError.message("missing Sikarugir Configure.app")
        }
        let wrapperName = context.outputApp.deletingPathExtension().lastPathComponent
        let alias = context.outputApp
            .deletingLastPathComponent()
            .appendingPathComponent("Configure \(wrapperName)")
        reporter.log("Creating Configure alias")
        guard !context.request.dryRun else { return }
        if pathEntryExists(alias), !configureAlias(alias, pointsTo: configureApp) {
            throw SetupEngineError.message("Configure alias target already exists and points somewhere else: \(alias.path)")
        }
        try? fileManager.removeItem(at: alias)
        let data = try configureApp.bookmarkData(
            options: [.suitableForBookmarkFile],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        try URL.writeBookmarkData(data, to: alias)
    }

    private func configureAlias(_ alias: URL, pointsTo target: URL) -> Bool {
        if isSymlink(alias),
           let destination = try? fileManager.destinationOfSymbolicLink(atPath: alias.path) {
            let resolved = destination.hasPrefix("/")
                ? URL(fileURLWithPath: destination)
                : alias.deletingLastPathComponent().appendingPathComponent(destination)
            return samePath(resolved, target)
        }

        guard let data = try? URL.bookmarkData(withContentsOf: alias) else { return false }
        var stale = false
        guard let resolved = try? URL(
            resolvingBookmarkData: data,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            return false
        }
        return samePath(resolved, target)
    }

    private func installEngine(context: SetupContext) throws {
        reporter.log("Installing Sikarugir engine \(context.request.engine)")
        guard !context.request.dryRun else { return }
        guard let archive = context.engineArchive, fileManager.fileExists(atPath: archive.path) else {
            throw SetupEngineError.message("missing Sikarugir engine archive")
        }
        try? fileManager.removeItem(at: context.wineDir)
        try? fileManager.removeItem(at: context.sharedSupport.appendingPathComponent("wswine.bundle"))
        try fileManager.createDirectory(at: context.sharedSupport, withIntermediateDirectories: true)
        try runner(context: context).run("/usr/bin/tar", ["-xJf", archive.path, "-C", context.sharedSupport.path], label: "extract Sikarugir engine")
        let bundle = context.sharedSupport.appendingPathComponent("wswine.bundle")
        if directoryExists(bundle.path) {
            try fileManager.moveItem(at: bundle, to: context.wineDir)
        }
        guard fileManager.isExecutableFile(atPath: context.wineBin.path) else {
            throw SetupEngineError.message("engine did not install wine")
        }
    }

    private func installUSVFSUpdateForEngine(context: SetupContext) throws {
        guard context.request.updateUSVFS else { return }
        let source = try usvfsSource(context: context)
        let mo2Dir = URL(fileURLWithPath: context.mo2Path).deletingLastPathComponent()
        let files = ["usvfs_x64.dll", "usvfs_proxy_x64.exe", "usvfs_x86.dll", "usvfs_proxy_x86.exe"]
        for file in files where !fileManager.fileExists(atPath: source.appendingPathComponent(file).path) {
            throw SetupEngineError.message("missing bundled usvfs binary: \(source.appendingPathComponent(file).path)")
        }
        if !context.request.forceDownload,
           files.allSatisfy({ fileManager.contentsEqual(atPath: source.appendingPathComponent($0).path, andPath: mo2Dir.appendingPathComponent($0).path) }) {
            return
        }
        reporter.log("Installing bundled usvfs binaries for \(context.request.engine)")
        guard !context.request.dryRun else { return }
        guard directoryExists(mo2Dir.path) else {
            throw SetupEngineError.message("missing ModOrganizer directory")
        }
        for file in files {
            try? fileManager.removeItem(at: mo2Dir.appendingPathComponent(file))
            try fileManager.copyItem(at: source.appendingPathComponent(file), to: mo2Dir.appendingPathComponent(file))
        }
    }

    private func installGPTK4Binaries(context: SetupContext) throws {
        guard context.request.installGPTK4Binaries else { return }
        let source = try gptk4Source(context: context)
        let rendererDir = context.contents.appendingPathComponent("Frameworks/renderer")
        let target = rendererDir.appendingPathComponent("d3dmetal")

        guard d3dMetalVersion(in: source) == "4.0b1" else {
            throw SetupEngineError.message("bundled GPTK4 D3DMetal payload is not version 4.0b1")
        }
        if !context.request.forceDownload, directoryPayloadMatches(source: source, target: target) {
            return
        }

        reporter.log("Installing GPTK4 D3DMetal binaries")
        guard !context.request.dryRun else { return }
        try fileManager.createDirectory(at: rendererDir, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: target)
        try copyPayloadDirectory(source: source, target: target)
        try? fileManager.removeItem(at: rendererDir.appendingPathComponent("apple_gptk"))
        try fileManager.createSymbolicLink(atPath: rendererDir.appendingPathComponent("apple_gptk").path, withDestinationPath: "d3dmetal")
    }

    private func installDXMTBinaries(context: SetupContext) throws {
        guard context.request.installDXMTBinaries == true else { return }
        let rendererDir = context.contents.appendingPathComponent("Frameworks/renderer")
        let target = rendererDir.appendingPathComponent("dxmt")

        let localCandidates = [
            context.scriptRoot.appendingPathComponent("dxmt"),
            context.scriptRoot.appendingPathComponent("sources/GAMMASetupTool/Resources/dxmt"),
            context.scriptRoot.appendingPathComponent("../../sources/GAMMASetupTool/Resources/dxmt")
        ]

        if let localSource = localCandidates.first(where: { directoryExists($0.path) }) {
            reporter.log("Installing DXMT binaries from local payload")
            guard !context.request.dryRun else { return }
            try fileManager.createDirectory(at: rendererDir, withIntermediateDirectories: true)
            try? fileManager.removeItem(at: target)
            try copyPayloadDirectory(source: localSource, target: target)
            return
        }

        reporter.log("Resolving latest DXMT artifact from GitHub (3Shain/dxmt)")
        let artifactInfo = try resolveLatestDXMTArtifact(context: context)
        let archive = try downloadFile(
            label: "latest DXMT artifact (\(artifactInfo.name))",
            url: artifactInfo.downloadURL,
            output: context.cacheDir.appendingPathComponent("dxmt/\(artifactInfo.name).zip"),
            context: context
        )

        reporter.log("Installing latest DXMT binaries")
        guard !context.request.dryRun else { return }

        let staging = context.cacheDir.appendingPathComponent("dxmt/staging")
        try? fileManager.removeItem(at: staging)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)

        let unzip = findTool("unzip") ?? "/usr/bin/unzip"
        try runner(context: context).run(unzip, ["-q", "-o", archive.path, "-d", staging.path], label: "unzip DXMT artifact")

        if let entries = try? fileManager.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil) {
            for entry in entries {
                if entry.pathExtension == "gz" || entry.lastPathComponent.hasSuffix(".tar.gz") || entry.pathExtension == "tgz" {
                    let tar = findTool("tar") ?? "/usr/bin/tar"
                    try runner(context: context).run(tar, ["-xzf", entry.path, "-C", staging.path], label: "extract DXMT tarball")
                }
            }
        }

        guard let payloadRoot = findDXMTPayloadRoot(in: staging) else {
            throw SetupEngineError.message("could not find DXMT payload in downloaded artifact")
        }

        try fileManager.createDirectory(at: rendererDir, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: target)
        try fileManager.createDirectory(at: target, withIntermediateDirectories: true)

        let wineTarget = target.appendingPathComponent("wine")
        try fileManager.createDirectory(at: wineTarget, withIntermediateDirectories: true)

        let wineSource = payloadRoot.appendingPathComponent("wine")
        let effectiveSource = directoryExists(wineSource.path) ? wineSource : payloadRoot

        let subdirs = ["x86_64-unix", "x86_64-windows", "i386-windows", "aarch64-unix", "aarch64-windows"]
        for subdir in subdirs {
            let src = effectiveSource.appendingPathComponent(subdir)
            if directoryExists(src.path) {
                let dst = wineTarget.appendingPathComponent(subdir)
                try copyPayloadDirectory(source: src, target: dst)
            }
        }

        let version = artifactInfo.version.isEmpty ? artifactInfo.name : artifactInfo.version
        let versionFile = target.appendingPathComponent("version")
        try version.trimmingCharacters(in: .whitespacesAndNewlines).write(to: versionFile, atomically: true, encoding: .utf8)

        let licenseSource = payloadRoot.appendingPathComponent("LICENSE")
        if fileManager.fileExists(atPath: licenseSource.path) {
            try? fileManager.copyItem(at: licenseSource, to: target.appendingPathComponent("LICENSE"))
        }

        try? fileManager.removeItem(at: staging)
    }

    private struct DXMTArtifactInfo {
        let name: String
        let version: String
        let downloadURL: String
    }

    private func resolveLatestDXMTArtifact(context: SetupContext) throws -> DXMTArtifactInfo {
        let nightlyIndex = try downloadText(
            label: "DXMT nightly.link index",
            url: "https://nightly.link/3Shain/dxmt/workflows/ci.yml/main",
            fallback: "",
            context: context
        )

        if let match = nightlyIndex.range(of: #"https://nightly\.link/3Shain/dxmt/workflows/ci/main/dxmt-[a-zA-Z0-9_\.-]+\.zip"#, options: .regularExpression) {
            let urlString = String(nightlyIndex[match])
            let fileName = URL(string: urlString)?.deletingPathExtension().lastPathComponent ?? "dxmt"
            let version = fileName.hasPrefix("dxmt-") ? String(fileName.dropFirst("dxmt-".count)) : fileName
            return DXMTArtifactInfo(name: fileName, version: version, downloadURL: urlString)
        }

        let apiJson = try downloadText(
            label: "DXMT GitHub API artifacts",
            url: "https://api.github.com/repos/3Shain/dxmt/actions/artifacts?per_page=30",
            fallback: "",
            context: context
        )

        if let data = apiJson.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let artifacts = json["artifacts"] as? [[String: Any]] {
            for artifact in artifacts {
                if let name = artifact["name"] as? String, name.hasPrefix("dxmt-") {
                    let version = String(name.dropFirst("dxmt-".count))
                    let downloadURL = "https://nightly.link/3Shain/dxmt/workflows/ci/main/\(name).zip"
                    return DXMTArtifactInfo(name: name, version: version, downloadURL: downloadURL)
                }
            }
        }

        throw SetupEngineError.message("could not resolve latest DXMT artifact from GitHub Actions (https://github.com/3Shain/dxmt)")
    }

    private func findDXMTPayloadRoot(in root: URL) -> URL? {
        if directoryExists(root.appendingPathComponent("x86_64-windows").path)
            || directoryExists(root.appendingPathComponent("wine/x86_64-windows").path) {
            return root
        }
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for case let url as URL in enumerator {
            if directoryExists(url.appendingPathComponent("x86_64-windows").path)
                || directoryExists(url.appendingPathComponent("wine/x86_64-windows").path) {
                return url
            }
        }
        return nil
    }

    private func installDirectXBinaries(context: SetupContext) throws {
        guard context.request.installDirectXBinaries else { return }
        let source = try directxSource(context: context)
        
        let targetDir: URL
        if context.request.programBatch != "/mo2.bat" {
            let exeURL = URL(fileURLWithPath: context.request.programBatch)
            targetDir = exeURL.deletingLastPathComponent()
        } else {
            targetDir = context.driveC.appendingPathComponent("windows/system32")
        }
        
        let files = ["d3dx9_43.dll", "d3dx10_43.dll", "d3dx11_43.dll", "d3dcompiler_47.dll", "d3dcompiler_43.dll", "xinput1_3.dll"]
        
        reporter.log("Installing DirectX native binaries from \(source.path) to \(targetDir.path)")
        guard !context.request.dryRun else { return }
        
        try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        for file in files {
            let sourceFile = source.appendingPathComponent(file)
            let targetFile = targetDir.appendingPathComponent(file)
            
            if fileManager.fileExists(atPath: sourceFile.path) {
                try? fileManager.removeItem(at: targetFile)
                try fileManager.copyItem(at: sourceFile, to: targetFile)
            } else {
                reporter.log("Warning: bundled DirectX binary missing: \(file)", severity: "warning")
            }
        }
    }

    private func directxSource(context: SetupContext) throws -> URL {
        let candidates = [
            context.scriptRoot.appendingPathComponent("directx"),
            context.scriptRoot.appendingPathComponent("sources/GAMMASetupTool/Resources/directx"),
            context.scriptRoot.appendingPathComponent("../../sources/GAMMASetupTool/Resources/directx")
        ]
        if let found = candidates.first(where: { directoryExists($0.path) }) {
            return found
        }
        throw SetupEngineError.message("bundled directx binaries were requested but no source was found at Resources/directx")
    }

    private func initializePrefix(context: SetupContext) throws {
        if fileManager.fileExists(atPath: context.userReg.path), directoryExists(context.driveC.path) {
            try normalizeWineUserProfile(context: context)
            return
        }
        reporter.log("Initializing Sikarugir Wine prefix")
        guard !context.request.dryRun else { return }
        try fileManager.createDirectory(at: context.prefix, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: context.appLogDir, withIntermediateDirectories: true)
        try runner(context: context).run(context.wineBin.path, ["wineboot", "-u"], environment: wineEnvironment(context: context), label: "Wine prefix initialization")
        if fileManager.isExecutableFile(atPath: context.wineServerBin.path) {
            _ = try? runner(context: context).run(context.wineServerBin.path, ["-w"], environment: wineEnvironment(context: context))
        }
        guard fileManager.fileExists(atPath: context.userReg.path) else {
            throw SetupEngineError.message("Wine prefix initialization did not create user.reg")
        }
        try normalizeWineUserProfile(context: context)
    }

    private func normalizeWineUserProfile(context: SetupContext) throws {
        guard !context.request.dryRun else { return }
        let usersDir = context.driveC.appendingPathComponent("users")
        guard directoryExists(usersDir.path) else { return }
        let target = usersDir.appendingPathComponent("Sikarugir")
        if !directoryExists(target.path) {
            let aliases = ["crossover", NSUserName()].filter { !$0.isEmpty && $0 != "Sikarugir" }
            if let source = aliases.map({ usersDir.appendingPathComponent($0) }).first(where: { directoryExists($0.path) && !isSymlink($0) }) {
                try fileManager.moveItem(at: source, to: target)
            } else {
                try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
            }
        }
        for alias in ["crossover", NSUserName()].filter({ !$0.isEmpty && $0 != "Sikarugir" }) {
            let aliasPath = usersDir.appendingPathComponent(alias)
            if isSymlink(aliasPath) {
                try? fileManager.removeItem(at: aliasPath)
            } else if fileManager.fileExists(atPath: aliasPath.path) {
                continue
            }
            try? fileManager.createSymbolicLink(atPath: aliasPath.path, withDestinationPath: "Sikarugir")
        }
    }

    private func configureDriveMapping(context: inout SetupContext) throws {
        reporter.log("Configuring Wine drive mapping")
        if context.request.driveMappingMode != "shorten" {
            reporter.log("Using default Wine drive mapping")
            try ensureDefaultWineDriveLinks(context: context)
            return
        }
        resolveDriveRoot(context: &context)
        guard directoryExists(context.driveRoot) else {
            throw SetupEngineError.message("mounted disk root not found: \(context.driveRoot)")
        }
        try ensureDefaultWineDriveLinks(context: context)
        guard !context.request.dryRun else { return }
        try replaceSymlink(at: context.dosdevices.appendingPathComponent("\(context.driveLetter):"), destination: context.driveRoot)
    }

    private func ensureDefaultWineDriveLinks(context: SetupContext) throws {
        guard !context.request.dryRun else { return }
        try fileManager.createDirectory(at: context.dosdevices, withIntermediateDirectories: true)
        try replaceSymlink(at: context.dosdevices.appendingPathComponent("z:"), destination: "/")
        try replaceSymlink(at: context.dosdevices.appendingPathComponent("c:"), destination: "../drive_c")
        try replaceSymlink(at: context.contents.appendingPathComponent("drive_c"), destination: "SharedSupport/prefix/drive_c")
    }

    private func installWinetricksDependencies(context: SetupContext) throws {
        let profile = context.request.compatibilityProfile ?? .standard
        var requiredVerbs = context.request.winetricks ?? profile.requiredVerbs
        if context.request.installDirectXBinaries {
            requiredVerbs.removeAll { ["d3dx9_43", "d3dx11_43", "d3dcompiler_47"].contains($0) }
        }
        if let additional = context.request.additionalWinetricks {
            let extra = additional.split(separator: " ").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            requiredVerbs.append(contentsOf: extra)
        }
        let winetricks = try resolveCompatibleWinetricks(requiredVerbs: requiredVerbs, context: context)
        let installedOutput: String
        do {
            installedOutput = try runner(context: context).run(
                winetricks,
                ["list-installed"],
                environment: wineEnvironment(context: context),
                label: "query installed winetricks"
            ).output
        } catch {
            reporter.log("Could not query installed winetricks; required components will be verified by installation", severity: "warning")
            installedOutput = ""
        }
        let missing = WinetricksTools.missingVerbs(requiredVerbs, installedOutput: installedOutput)
        guard !missing.isEmpty else {
            reporter.log("Required winetricks components are already installed")
            return
        }
        try installWinetricksGroup(label: "missing required dependencies", verbs: missing, winetricks: winetricks, context: context)
    }

    private func missingDllOverrides(in overrides: [String: String], required: [String: String]) -> [String] {
        required.keys.sorted().compactMap { key in
            let normalized = key.trimmingCharacters(in: CharacterSet(charactersIn: "*")).lowercased()
            guard let actual = overrides[normalized] else { return key }
            let expected = required[key]?.lowercased() ?? ""
            if actual == expected { return nil }
            if expected == "native", actual == "native,builtin" { return nil }
            return key
        }
    }

    private func currentDllOverrides(in registry: String) -> [String: String] {
        var inSection = false
        var values: [String: String] = [:]
        for line in registry.split(whereSeparator: \.isNewline).map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let section = registrySectionName(trimmed) {
                inSection = section == #"Software\\Wine\\DllOverrides"#
                continue
            }
            guard inSection else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0]
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                .trimmingCharacters(in: CharacterSet(charactersIn: "*"))
                .lowercased()
            let value = parts[1]
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                .lowercased()
            values[key] = value
        }
        return values
    }

    private func resolveCompatibleWinetricks(requiredVerbs: [String], context: SetupContext) throws -> String {
        let managedWinetricks = context.managedWinetricks
        try updateManagedWinetricksPayloadChecksums(at: managedWinetricks)
        let candidates = [managedWinetricks.path, findTool("winetricks")].compactMap { $0 }
        let validationRunner = ProcessRunner(dryRun: context.request.dryRun, verbose: false, reporter: reporter)
        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
            if context.request.dryRun {
                return candidate
            }
            do {
                let output = try validationRunner.run(candidate, ["list-all"], label: "validate winetricks").output
                if WinetricksTools.supports(requiredVerbs, listOutput: output) {
                    return candidate
                }
            } catch {
                reporter.log("Could not validate winetricks at \(candidate): \(error)")
            }
        }

        reporter.log("Installed winetricks does not support all required verbs; downloading a current shared script")
        if !context.request.dryRun {
            try? fileManager.removeItem(at: managedWinetricks)
        }
        _ = try downloadFile(
            label: "current winetricks script",
            url: "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks",
            output: managedWinetricks,
            context: context
        )
        if context.request.dryRun {
            return managedWinetricks.path
        }
        try updateManagedWinetricksPayloadChecksums(at: managedWinetricks)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: managedWinetricks.path)
        let output = try validationRunner.run(managedWinetricks.path, ["list-all"], label: "validate downloaded winetricks").output
        guard WinetricksTools.supports(requiredVerbs, listOutput: output) else {
            throw SetupEngineError.message("downloaded winetricks does not support required verbs: \(requiredVerbs.joined(separator: ", "))")
        }
        return managedWinetricks.path
    }

    private func updateManagedWinetricksPayloadChecksums(at scriptURL: URL) throws {
        guard fileManager.fileExists(atPath: scriptURL.path) else { return }
        let script = try String(contentsOf: scriptURL)
        let updated = WinetricksTools.updatingKnownPayloadChecksums(in: script)
        guard updated != script else { return }
        try updated.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        reporter.log("Updated managed winetricks checksums for current Visual C++ redistributables")
    }

    private func installWinetricksGroup(label: String, verbs: [String], winetricks: String, context: SetupContext) throws {
        reporter.log("Installing \(label) with winetricks")
        reporter.log("Using shared winetricks download cache at \(context.winetricksDownloadCache.path)")
        guard !context.request.dryRun else { return }
        try fileManager.createDirectory(at: context.appLogDir, withIntermediateDirectories: true)
        try runner(context: context).run(winetricks, ["-q"] + verbs, environment: wineEnvironment(context: context), label: "\(label) winetricks")
    }

    private func configureWineGraphicsDriver(context: SetupContext) throws {
        reporter.log("Configuring Wine macOS graphics driver")
        try ensureSectionKeyValues(file: context.userReg, section: #"Software\\Wine\\Drivers"#, entries: ["Graphics": "mac"], context: context)
    }

    private func configureWineDisplay(context: SetupContext) throws {
        guard context.request.forceRetinaOff == true else { return }

        reporter.log("Forcing Wine Retina mode off at 96 DPI")
        try ensureSectionKeyValues(
            file: context.userReg,
            section: #"Software\\Wine\\Mac Driver"#,
            entries: ["RetinaMode": "N"],
            context: context
        )
        try ensureSectionRawLines(
            file: context.userReg,
            section: #"Control Panel\\Desktop"#,
            lines: [#""LogPixels"=dword:00000060"#],
            context: context
        )
    }

    private func configureDllOverrides(context: SetupContext) throws {
        reporter.log("Configuring DLL overrides")
        let profile = context.request.compatibilityProfile ?? .standard
        try removeRegistrySection(file: context.userReg, section: #"Software\\Wine\\DllOverrides"#, context: context)
        try ensureSectionKeyValues(
            file: context.userReg,
            section: #"Software\\Wine\\DllOverrides"#,
            entries: SetupRegistryDefaults.dllOverrides(for: profile),
            context: context
        )
    }

    private func createMO2Batch(context: inout SetupContext) throws {
        reporter.log("Creating ModOrganizer launch batch")
        resolveDriveRoot(context: &context)
        let mo2WinPath = try launchWindowsPath(nativePath: context.mo2Path, context: context)
        let batch = context.driveC.appendingPathComponent("mo2.bat")
        guard !context.request.dryRun else { return }
        try fileManager.createDirectory(at: batch.deletingLastPathComponent(), withIntermediateDirectories: true)
        let lines = SetupLaunchBatchTools.modOrganizerCommandLines(
            executableWindowsPath: mo2WinPath,
            launchArguments: normalizedBatchPath(context.request.programBatch) == "/mo2.bat"
                ? context.request.launchArguments ?? ""
                : ""
        )
        try (lines.joined(separator: "\r\n") + "\r\n").write(to: batch, atomically: true, encoding: .utf8)
    }

    private func createLaunchBatches(context: inout SetupContext) throws {
        let launchBatches = context.request.launchBatches ?? []
        guard !launchBatches.isEmpty else { return }
        reporter.log("Creating launch batches")
        resolveDriveRoot(context: &context)
        for launch in launchBatches {
            let batchPath = launch.batchPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !batchPath.isEmpty else { continue }
            let batch = context.driveC.appendingPathComponent(batchPath)
            let exeWinPath = try launchWindowsPath(nativePath: launch.executablePath, context: context)
            let workingNative = launch.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? URL(fileURLWithPath: launch.executablePath).deletingLastPathComponent().path
                : launch.workingDirectory
            let workingWinPath = try launchWindowsPath(nativePath: workingNative, context: context)
            guard !context.request.dryRun else { continue }
            try fileManager.createDirectory(at: batch.deletingLastPathComponent(), withIntermediateDirectories: true)
            let lines = SetupLaunchBatchTools.commandLines(
                executableWindowsPath: windowsBackslashPath(exeWinPath),
                workingDirectoryWindowsPath: windowsBackslashPath(workingWinPath),
                usesModOrganizerEnvironment: launch.usesModOrganizerEnvironment == true,
                launchArguments: normalizedBatchPath(launch.batchPath) == normalizedBatchPath(context.request.programBatch)
                    ? context.request.launchArguments ?? ""
                    : ""
            )
            try (lines.joined(separator: "\r\n") + "\r\n").write(to: batch, atomically: true, encoding: .utf8)
        }
    }

    private func launchWindowsPath(nativePath: String, context: SetupContext) throws -> String {
        if pathIsUnder(nativePath, parent: context.driveC.path) {
            let rel = String(nativePath.dropFirst(context.driveC.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return "C:/\(rel)"
        }
        if let driveCIndex = nativePath.range(of: "/drive_c/", options: [.caseInsensitive]) {
            let rel = String(nativePath[driveCIndex.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return "C:/\(rel)"
        }
        if context.request.driveMappingMode != "shorten" {
            return try defaultWineHostWindowsPath(nativePath)
        }
        if pathIsUnder(nativePath, parent: context.driveRoot) {
            return try nativeToWindowsPath(nativePath, driveRoot: context.driveRoot, driveLetter: context.driveLetter)
        }
        return try defaultWineHostWindowsPath(nativePath)
    }

    private func defaultWineHostWindowsPath(_ nativePath: String) throws -> String {
        let absolute = absolutePath(nativePath)
        guard absolute.hasPrefix("/") else {
            throw SetupEngineError.message("cannot convert native path to Wine Z: path: \(nativePath)")
        }
        return "Z:/" + absolute.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func selectedLaunchExecutable(context: SetupContext) -> String {
        if context.request.programBatch == "/mo2.bat" { return context.mo2Path }
        return selectedLaunchBatch(context: context)?.executablePath ?? context.request.programBatch
    }

    private func selectedLaunchUsesModOrganizerEnvironment(context: SetupContext) -> Bool {
        context.request.programBatch == "/mo2.bat"
            || selectedLaunchBatch(context: context)?.usesModOrganizerEnvironment == true
    }

    private func selectedLaunchBatch(context: SetupContext) -> LaunchBatch? {
        let selectedPath = normalizedBatchPath(context.request.programBatch)
        return (context.request.launchBatches ?? []).first {
            normalizedBatchPath($0.batchPath) == selectedPath
        }
    }

    private func normalizedBatchPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
    }

    private func validateLaunchArguments(_ launchArguments: String?) throws {
        guard let launchArguments,
              SetupLaunchBatchTools.containsLineBreak(launchArguments) else {
            return
        }
        throw SetupEngineError.message("launch flags must be a single line")
    }

    private func validateSelectedLaunchExecutable(context: SetupContext) throws {
        guard context.request.programBatch != "/mo2.bat" else { return }
        let executable = selectedLaunchExecutable(context: context)
        guard fileManager.fileExists(atPath: executable) else {
            throw SetupEngineError.message("launch executable not found: \(executable)")
        }
    }

    private func normalizeAppPermissions(context: SetupContext) throws {
        reporter.log("Normalizing Sikarugir app permissions")
        guard !context.request.dryRun else { return }
        if let enumerator = fileManager.enumerator(at: context.outputApp, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) {
            for case let url as URL in enumerator {
                chmod(url.path, 0o777)
            }
        }
        chmod(context.outputApp.path, 0o777)
    }

    private func refreshAppRegistration(context: SetupContext) throws {
        guard !context.request.dryRun else { return }
        let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        guard fileManager.isExecutableFile(atPath: lsregister) else { return }
        _ = try? runner(context: context).run(lsregister, ["-u", context.outputApp.path])
        _ = try? runner(context: context).run(lsregister, ["-f", context.outputApp.path])
    }

    private func verifyOutputs(context: SetupContext) throws {
        guard !context.request.dryRun else { return }
        guard fileManager.isExecutableFile(atPath: context.wineBin.path) else { throw SetupEngineError.message("missing Sikarugir wine") }
        guard fileManager.fileExists(atPath: context.userReg.path) else { throw SetupEngineError.message("missing Wine user registry") }
        guard directoryExists(context.driveC.path) else { throw SetupEngineError.message("missing drive_c") }
        let batch = context.driveC.appendingPathComponent(context.request.programBatch.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        guard fileManager.fileExists(atPath: batch.path) else { throw SetupEngineError.message("missing selected launch batch") }
        guard context.request.driveMappingMode == "shorten" else { return }
        let driveLink = context.dosdevices.appendingPathComponent("\(context.driveLetter):")
        guard (try? fileManager.destinationOfSymbolicLink(atPath: driveLink.path)) == context.driveRoot else {
            throw SetupEngineError.message("Wine drive mapping was not created correctly")
        }
    }

    private func loadGammaSettings(context: inout SetupContext, required: Bool, preflightOnly: Bool) throws {
        if !context.request.mo2Path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.mo2Path = absolutePath(context.request.mo2Path)
            context.gammaPath = context.request.gammaPath.isEmpty ? URL(fileURLWithPath: context.mo2Path).deletingLastPathComponent().path : absolutePath(context.request.gammaPath)
            context.anomalyPath = context.request.anomalyPath.isEmpty ? "" : absolutePath(context.request.anomalyPath)
            if required, !fileManager.fileExists(atPath: context.mo2Path) {
                throw SetupEngineError.message("ModOrganizer.exe not found: \(context.mo2Path)")
            }
            if required, !directoryExists(context.gammaPath) {
                throw SetupEngineError.message("GAMMA directory not found: \(context.gammaPath)")
            }
            loadModOrganizerIni(context: &context)
            return
        }

        if fileManager.fileExists(atPath: context.request.settingsFile) {
            try loadProfileSettings(context: &context)
        }

        if context.mo2Path.isEmpty {
            if required {
                throw SetupEngineError.message("could not find a usable active profile in \(context.request.settingsFile); provide a ModOrganizer path")
            }
            return
        }
        if required, !fileManager.fileExists(atPath: context.mo2Path) {
            throw SetupEngineError.message("ModOrganizer.exe not found: \(context.mo2Path)")
        }
        if required, !directoryExists(context.gammaPath) {
            throw SetupEngineError.message("GAMMA directory not found: \(context.gammaPath)")
        }
        loadModOrganizerIni(context: &context)
    }

    private func loadProfileSettings(context: inout SetupContext) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: context.request.settingsFile))
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profiles = object["Profiles"] as? [[String: Any]] else {
            return
        }
        var selected: [String: Any]?
        for profile in profiles {
            if selected == nil {
                selected = profile
            }
            if let active = profile["Active"] as? Bool, active {
                selected = profile
                break
            }
            if let active = profile["Active"] as? NSNumber, active.boolValue {
                selected = profile
                break
            }
        }
        guard let profile = selected, let gamma = profile["Gamma"] as? String, !gamma.isEmpty else {
            return
        }
        context.gammaPath = absolutePath(gamma)
        context.mo2Path = URL(fileURLWithPath: context.gammaPath).appendingPathComponent("ModOrganizer.exe").path
        context.anomalyPath = (profile["Anomaly"] as? String).map(absolutePath) ?? ""
        context.mo2ProfileName = profile["Mo2Profile"] as? String ?? ""
    }

    private func loadModOrganizerIni(context: inout SetupContext) {
        context.mo2IniPath = URL(fileURLWithPath: context.mo2Path).deletingLastPathComponent().appendingPathComponent("ModOrganizer.ini").path
        guard let text = try? String(contentsOfFile: context.mo2IniPath) else { return }
        guard let raw = iniValue(text: text, section: "General", key: "gamePath") else { return }
        context.mo2IniGamePathWin = decodeModOrganizerIniValue(raw)
        context.mo2IniDriveLetter = windowsPathDrive(context.mo2IniGamePathWin)
        let rel = windowsPathRelative(context.mo2IniGamePathWin)
        guard !context.mo2IniDriveLetter.isEmpty, !rel.isEmpty else { return }

        if context.mo2IniDriveLetter == "z", context.request.driveMappingMode != "shorten" {
            let absoluteCandidate = "/" + rel
            if directoryExists(absoluteCandidate) {
                context.anomalyPath = absolutePath(absoluteCandidate)
                context.mo2IniDriveRoot = "/"
                return
            }
        }

        let candidate = URL(fileURLWithPath: context.gammaPath).deletingLastPathComponent().appendingPathComponent(rel).path
        if directoryExists(candidate) {
            context.anomalyPath = absolutePath(candidate)
            context.mo2IniDriveRoot = rootRemovingSuffix(context.anomalyPath, suffix: rel)
            return
        }

        if !context.anomalyPath.isEmpty, directoryExists(context.anomalyPath) {
            context.mo2IniDriveRoot = commonParent(context.gammaPath, context.anomalyPath)
        }
    }

    private func resolveDriveRoot(context: inout SetupContext) {
        if context.request.driveMappingMode == "shorten", !context.gammaPath.isEmpty {
            context.driveRoot = URL(fileURLWithPath: context.gammaPath)
                .deletingLastPathComponent()
                .standardizedFileURL.path
            context.driveLetter = "g"
        } else {
            context.driveRoot = "/"
            context.driveLetter = "z"
        }
        context.zRewriteRequired = false
    }

    private func wineEnvironment(context: SetupContext) -> [String: String] {
        let libraryPath = "\(context.contents.path)/Frameworks:\(context.sharedSupport.path):\(context.wineDir.path)/lib:/opt/homebrew/lib:/usr/local/lib:/usr/lib"
        return [
            "WINEPREFIX": context.prefix.path,
            "WINEARCH": "win64",
            "PATH": "\(context.wineDir.path)/bin:/opt/homebrew/bin:/usr/local/bin:" + (ProcessInfo.processInfo.environment["PATH"] ?? ""),
            "DYLD_FALLBACK_LIBRARY_PATH": libraryPath,
            "WINETRICKS_FALLBACK_LIBRARY_PATH": libraryPath,
            "W_CACHE": context.winetricksDownloadCache.path
        ]
    }

    private func ensureSectionKeyValues(file: URL, section: String, entries: [String: String], context: SetupContext) throws {
        guard !context.request.dryRun else { return }
        guard fileManager.fileExists(atPath: file.path) else {
            throw SetupEngineError.message("missing registry file: \(file.path)")
        }
        var lines = try String(contentsOf: file).components(separatedBy: .newlines)
        editSection(lines: &lines, section: section) { body in
            var seen: Set<String> = []
            var output: [String] = []
            for line in body {
                if let key = quotedRegistryKey(line), let value = entries[key] {
                    output.append("\"\(key)\"=\"\(value)\"")
                    seen.insert(key)
                } else {
                    output.append(line)
                }
            }
            for key in entries.keys.sorted() where !seen.contains(key) {
                output.append("\"\(key)\"=\"\(entries[key]!)\"")
            }
            return output
        }
        try lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
    }

    private func ensureSectionRawLines(file: URL, section: String, lines desiredLines: [String], context: SetupContext) throws {
        guard !context.request.dryRun else { return }
        guard fileManager.fileExists(atPath: file.path) else {
            throw SetupEngineError.message("missing registry file: \(file.path)")
        }
        var lines = try String(contentsOf: file).components(separatedBy: .newlines)
        let desired = Dictionary(uniqueKeysWithValues: desiredLines.map { (rawLineKey($0), $0) })
        editSection(lines: &lines, section: section) { body in
            var seen: Set<String> = []
            var output: [String] = []
            for line in body {
                let key = rawLineKey(line)
                if let replacement = desired[key] {
                    output.append(replacement)
                    seen.insert(key)
                } else {
                    output.append(line)
                }
            }
            for key in desired.keys.sorted() where !seen.contains(key) {
                output.append(desired[key]!)
            }
            return output
        }
        try lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
    }

    private func removeRegistrySection(file: URL, section: String, context: SetupContext) throws {
        guard !context.request.dryRun, fileManager.fileExists(atPath: file.path) else { return }
        let lines = try String(contentsOf: file).components(separatedBy: .newlines)
        var output: [String] = []
        var skipping = false
        for line in lines {
            if registrySectionName(line) == section {
                skipping = true
                continue
            }
            if skipping, registrySectionName(line) != nil {
                skipping = false
            }
            if !skipping {
                output.append(line)
            }
        }
        try output.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
    }

    private func removeSectionKeys(file: URL, section: String, keys: Set<String>, context: SetupContext) throws {
        guard !context.request.dryRun, fileManager.fileExists(atPath: file.path) else { return }
        var lines = try String(contentsOf: file).components(separatedBy: .newlines)
        editSection(lines: &lines, section: section) { body in
            body.filter { line in
                guard let key = quotedRegistryKey(line) else { return true }
                return !keys.contains(key)
            }
        }
        try lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
    }

    private func editSection(lines: inout [String], section: String, bodyEdit: ([String]) -> [String]) {
        var start: Int?
        var end = lines.count
        for index in lines.indices {
            if registrySectionName(lines[index]) == section {
                start = index
                continue
            }
            if let start, index > start, registrySectionName(lines[index]) != nil {
                end = index
                break
            }
        }
        if let start {
            let body = Array(lines[(start + 1)..<end])
            lines.replaceSubrange((start + 1)..<end, with: bodyEdit(body))
        } else {
            if !lines.last.map({ $0.isEmpty })! {
                lines.append("")
            }
            lines.append("[\(section)]")
            lines.append(contentsOf: bodyEdit([]))
        }
    }

    private func downloadText(label: String, url: String, fallback: String, context: SetupContext) throws -> String {
        if context.request.dryRun {
            if context.request.verbose {
                reporter.log("dry-run: curl -fsSL \(url)")
            }
            return fallback
        }
        guard let curl = findTool("curl") ?? Optional("/usr/bin/curl") else { return fallback }
        do {
            return try runner(context: context).run(curl, ["-fsSL", url], label: "download \(label)").output
        } catch {
            if fallback.isEmpty { throw error }
            reporter.log("could not download \(label) from \(url); using cached/default value: \(fallback)", severity: "warning")
            return fallback
        }
    }

    private func downloadFile(label: String, url: String, output: URL, context: SetupContext) throws -> URL {
        if fileManager.fileExists(atPath: output.path), !context.request.forceDownload {
            return output
        }
        reporter.log("Downloading \(label)")
        if context.request.dryRun {
            if context.request.verbose {
                reporter.log("dry-run: curl -L --fail --retry 3 --output \(output.path) \(url)")
            }
            return output
        }
        try fileManager.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        let curl = findTool("curl") ?? "/usr/bin/curl"
        try runner(context: context).run(curl, ["-L", "--fail", "--retry", "3", "--output", output.path, url], label: "download \(label)")
        return output
    }

    private func createDirectory(_ url: URL, context: SetupContext) throws {
        guard !context.request.dryRun else {
            if context.request.verbose { reporter.log("dry-run: mkdir -p \(url.path)") }
            return
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func remove(_ url: URL, context: SetupContext) throws {
        guard !context.request.dryRun else {
            if context.request.verbose { reporter.log("dry-run: remove \(url.path)") }
            return
        }
        try? fileManager.removeItem(at: url)
    }

    private func replaceSymlink(at url: URL, destination: String) throws {
        try? fileManager.removeItem(at: url)
        try fileManager.createSymbolicLink(atPath: url.path, withDestinationPath: destination)
    }

    private func findTool(_ name: String) -> String? {
        let environment = ProcessInfo.processInfo.environment
        let paths: [String]
        if let override = environment["GAMMA_SETUP_TOOL_PATHS"] {
            paths = override.split(separator: ":").map(String.init)
        } else {
            paths = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
                + ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        }
        for path in paths {
            let candidate = URL(fileURLWithPath: path).appendingPathComponent(name).path
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private func directoryExists(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    private func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private func pathEntryExists(_ url: URL) -> Bool {
        if fileManager.fileExists(atPath: url.path) {
            return true
        }
        return (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    private func absolutePath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    private func samePath(_ left: URL, _ right: URL) -> Bool {
        left.standardizedFileURL.path == right.standardizedFileURL.path
    }

    private func pathIsUnder(_ child: String, parent: String) -> Bool {
        if parent == "/" { return child.hasPrefix("/") }
        return child == parent || child.hasPrefix(parent + "/")
    }

    private func commonParent(_ first: String, _ second: String) -> String {
        let a = first.split(separator: "/").map(String.init)
        let b = second.split(separator: "/").map(String.init)
        var parts: [String] = []
        for (left, right) in zip(a, b) {
            guard left == right else { break }
            parts.append(left)
        }
        return parts.isEmpty ? "/" : "/" + parts.joined(separator: "/")
    }

    private func decodeModOrganizerIniValue(_ value: String) -> String {
        var value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
        if value.hasPrefix("@ByteArray("), value.hasSuffix(")") {
            value = String(value.dropFirst("@ByteArray(".count).dropLast())
        }
        if value.hasPrefix("\"") { value.removeFirst() }
        if value.hasSuffix("\"") { value.removeLast() }
        return value
    }

    private func windowsPathDrive(_ path: String) -> String {
        let normalized = path.replacingOccurrences(of: #"\\\\"#, with: #"\"#)
        guard normalized.count >= 3,
              normalized[normalized.index(after: normalized.startIndex)] == ":",
              normalized[normalized.index(normalized.startIndex, offsetBy: 2)] == "\\" || normalized[normalized.index(normalized.startIndex, offsetBy: 2)] == "/" else {
            return ""
        }
        return String(normalized.prefix(1)).lowercased()
    }

    private func windowsPathRelative(_ path: String) -> String {
        var normalized = path.replacingOccurrences(of: #"\\\\"#, with: #"\"#)
        guard normalized.count >= 3, normalized[normalized.index(after: normalized.startIndex)] == ":" else {
            return ""
        }
        normalized = String(normalized.dropFirst(2))
        normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "\\/"))
        return normalized.replacingOccurrences(of: "\\", with: "/")
    }

    private func windowsBackslashPath(_ path: String) -> String {
        path.replacingOccurrences(of: "/", with: "\\")
    }

    private func nativeToWindowsPath(_ native: String, driveRoot: String, driveLetter: String) throws -> String {
        guard !driveRoot.isEmpty, pathIsUnder(native, parent: driveRoot) else {
            throw SetupEngineError.message("cannot convert native path to Wine path under mounted root \(driveRoot): \(native)")
        }
        let rel = driveRoot == "/" ? native.trimmingCharacters(in: CharacterSet(charactersIn: "/")) : String(native.dropFirst(driveRoot.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(driveLetter.uppercased()):/\(rel)"
    }

    private func rootRemovingSuffix(_ path: String, suffix: String) -> String {
        let suffixPath = "/" + suffix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix(suffixPath) {
            let root = String(path.dropLast(suffixPath.count))
            return root.isEmpty ? "/" : root
        }
        return URL(fileURLWithPath: path).deletingLastPathComponent().path
    }

    private func zShortRoot(context: SetupContext) -> String {
        guard !context.gammaPath.isEmpty, directoryExists(context.gammaPath) else { return "" }
        return URL(fileURLWithPath: context.gammaPath).deletingLastPathComponent().standardizedFileURL.path
    }

    private func activeModlistPath(context: SetupContext) -> String {
        guard !context.gammaPath.isEmpty else { return "" }
        if !context.mo2ProfileName.isEmpty {
            let candidate = URL(fileURLWithPath: context.gammaPath).appendingPathComponent("profiles/\(context.mo2ProfileName)/modlist.txt").path
            if fileManager.fileExists(atPath: candidate) { return candidate }
        }
        let gammaProfile = URL(fileURLWithPath: context.gammaPath).appendingPathComponent("profiles/G.A.M.M.A/modlist.txt").path
        if fileManager.fileExists(atPath: gammaProfile) { return gammaProfile }
        let profiles = URL(fileURLWithPath: context.gammaPath).appendingPathComponent("profiles")
        guard let enumerator = fileManager.enumerator(at: profiles, includingPropertiesForKeys: nil) else { return "" }
        for case let url as URL in enumerator where url.lastPathComponent == "modlist.txt" {
            return url.path
        }
        return ""
    }

    private func appIconSource(context: SetupContext) -> URL {
        if !context.request.appIconSource.isEmpty {
            return URL(fileURLWithPath: context.request.appIconSource)
        }
        let candidates = [
            context.scriptRoot.appendingPathComponent("Anomaly.icns"),
            context.scriptRoot.appendingPathComponent("sources/GAMMASetupTool/Resources/Anomaly.icns"),
            context.scriptRoot.appendingPathComponent("../../sources/GAMMASetupTool/Resources/Anomaly.icns")
        ]
        return candidates.first(where: { fileManager.fileExists(atPath: $0.path) }) ?? candidates[0]
    }

    private func usvfsSource(context: SetupContext) throws -> URL {
        if !context.request.usvfsSource.isEmpty {
            return URL(fileURLWithPath: context.request.usvfsSource)
        }

        let dirs = [
            context.scriptRoot.appendingPathComponent("usvfs/\(context.request.engine)"),
            context.scriptRoot.appendingPathComponent("usvfs"),
            context.scriptRoot.appendingPathComponent("sources/GAMMASetupTool/Resources/usvfs/\(context.request.engine)"),
            context.scriptRoot.appendingPathComponent("sources/GAMMASetupTool/Resources/usvfs"),
            context.scriptRoot.appendingPathComponent("../../sources/GAMMASetupTool/Resources/usvfs/\(context.request.engine)"),
            context.scriptRoot.appendingPathComponent("../../sources/GAMMASetupTool/Resources/usvfs")
        ]
        if let match = dirs.first(where: { directoryExists($0.path) }) {
            return match
        }

        throw SetupEngineError.message("bundled usvfs binaries were requested but no source was found at Resources/usvfs")
    }

    private func gptk4Source(context: SetupContext) throws -> URL {
        let dirs = [
            context.scriptRoot.appendingPathComponent("gptk4/d3dmetal"),
            context.scriptRoot.appendingPathComponent("sources/GAMMASetupTool/Resources/gptk4/d3dmetal"),
            context.scriptRoot.appendingPathComponent("../../sources/GAMMASetupTool/Resources/gptk4/d3dmetal")
        ]
        if let match = dirs.first(where: { directoryExists($0.path) }) {
            return match
        }
        throw SetupEngineError.message("GPTK4 binaries were requested but no bundled payload was found at Resources/gptk4/d3dmetal")
    }

    private func d3dMetalVersion(in directory: URL) -> String {
        let versionURL = directory
            .appendingPathComponent("external/D3DMetal.framework/Resources/version.plist")
        guard let plist = NSDictionary(contentsOf: versionURL) as? [String: Any] else {
            return ""
        }
        return plist["CFBundleShortVersionString"] as? String ?? ""
    }

    private func relativePayloadPath(child: URL, parent: URL) -> String {
        if child.path.hasPrefix(parent.path) {
            return String(child.path.dropFirst(parent.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        let parentCanonical = parent.resolvingSymlinksInPath().path
        let childDirCanonical = child.deletingLastPathComponent().resolvingSymlinksInPath().path
        if childDirCanonical.hasPrefix(parentCanonical) {
            let relativeDir = String(childDirCanonical.dropFirst(parentCanonical.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return relativeDir.isEmpty ? child.lastPathComponent : "\(relativeDir)/\(child.lastPathComponent)"
        }
        return child.lastPathComponent
    }

    private func directoryPayloadMatches(source: URL, target: URL) -> Bool {
        guard directoryExists(source.path), directoryExists(target.path),
              let enumerator = fileManager.enumerator(
                at: source,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
              ) else {
            return false
        }

        for case let sourceURL as URL in enumerator {
            let relative = relativePayloadPath(child: sourceURL, parent: source)
            guard !relative.isEmpty else { continue }
            let targetURL = target.appendingPathComponent(relative)
            guard payloadEntryMatches(source: sourceURL, target: targetURL) else {
                return false
            }
        }
        return true
    }

    private func payloadEntryMatches(source: URL, target: URL) -> Bool {
        if isSymlink(source) {
            return (try? fileManager.destinationOfSymbolicLink(atPath: source.path))
                == (try? fileManager.destinationOfSymbolicLink(atPath: target.path))
        }
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDir) else {
            return false
        }
        if isDir.boolValue {
            return directoryExists(target.path)
        }
        return fileManager.fileExists(atPath: target.path)
            && fileManager.contentsEqual(atPath: source.path, andPath: target.path)
    }

    private func copyPayloadDirectory(source: URL, target: URL) throws {
        try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        guard let enumerator = fileManager.enumerator(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ) else {
            throw SetupEngineError.message("could not enumerate payload: \(source.path)")
        }

        for case let sourceURL as URL in enumerator {
            let relative = relativePayloadPath(child: sourceURL, parent: source)
            guard !relative.isEmpty else { continue }
            let targetURL = target.appendingPathComponent(relative)
            if isSymlink(sourceURL) {
                guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: sourceURL.path) else {
                    throw SetupEngineError.message("could not read payload symlink: \(sourceURL.path)")
                }
                try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fileManager.removeItem(at: targetURL)
                try fileManager.createSymbolicLink(atPath: targetURL.path, withDestinationPath: destination)
                continue
            }

            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDir) else {
                throw SetupEngineError.message("missing payload entry: \(sourceURL.path)")
            }
            if isDir.boolValue {
                try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
            } else {
                try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fileManager.removeItem(at: targetURL)
                try fileManager.copyItem(at: sourceURL, to: targetURL)
            }
        }
    }

    private func findFirstApp(named name: String, under root: URL) -> URL? {
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return nil }
        for case let url as URL in enumerator where url.lastPathComponent == name {
            return url
        }
        return nil
    }

    private func iniValue(text: String, section: String, key: String) -> String? {
        var inSection = false
        for line in text.split(whereSeparator: \.isNewline).map(String.init) {
            if line == "[\(section)]" {
                inSection = true
                continue
            }
            if line.hasPrefix("[") {
                inSection = false
            }
            guard inSection else { continue }
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2, parts[0] == key {
                return String(parts[1])
            }
        }
        return nil
    }

    private func quotedRegistryKey(_ line: String) -> String? {
        guard line.hasPrefix("\""), let end = line.dropFirst().firstIndex(of: "\"") else { return nil }
        return String(line[line.index(after: line.startIndex)..<end])
    }

    private func registrySectionName(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["),
              let end = trimmed.firstIndex(of: "]") else {
            return nil
        }
        return String(trimmed[trimmed.index(after: trimmed.startIndex)..<end])
    }

    private func rawLineKey(_ line: String) -> String {
        String(line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func errorDescription(_ error: Error) -> String {
        if let setup = error as? SetupEngineError {
            return setup.description
        }
        return error.localizedDescription
    }
}
