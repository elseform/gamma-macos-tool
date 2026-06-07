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
    var appMarker: URL
    var markerDir: URL
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
    var userLtxPath = ""
    var gameResolutionWidth: Int?
    var gameResolutionHeight: Int?
    var zRewriteRequired = false
    var driveLetter = "g"
    var driveRoot = ""

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
        self.appMarker = outputApp.appendingPathComponent("Contents/SharedSupport/.stalker-gamma-sikarugir-setup")
        self.markerDir = outputApp.appendingPathComponent("Contents/SharedSupport/.stalker-gamma-sikarugir-markers")
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
        resolveDriveRoot(context: &context, allowRewrite: false)

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
        loadUserLtxResolution(context: &context)
        return Preflight(
            targetApp: request.outputApp,
            engine: request.engine,
            renderer: request.renderer,
            moltenVKFastMath: request.moltenVKFastMath,
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
            userLtxPath: context.userLtxPath,
            userLtxFound: fileManager.fileExists(atPath: context.userLtxPath),
            gameResolutionWidth: context.gameResolutionWidth,
            gameResolutionHeight: context.gameResolutionHeight,
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
            try ensureWinetricks(context: context)
            reporter.completed(success: true, message: "winetricks is installed.")
        default:
            throw SetupEngineError.message("unknown install dependency: \(name)")
        }
    }

    public func create(request: SetupRequest) throws {
        var context = SetupContext(request: request, executablePath: executablePath)
        try setupLogIfNeeded(context: context)
        try loadGammaSettings(context: &context, required: true, preflightOnly: false)
        try ensureBrewDependencies(context: context)
        try resolveSikarugirAssets(context: &context)
        let rendererChangedOnUpdate = rendererChangedForExistingManagedApp(context: context)

        try runStage(.wrapper) {
            try prepareTargetApp(context: context)
            try markManagedApp(context: context, status: "in-progress")
            try ensureAppTemplateLayout(context: context)
            try installAppIcon(context: context)
            try ensureAppFrameworks(context: context)
            try configureAppPlist(context: context)
        }
        try runStage(.engine) {
            try installEngine(context: context)
            try installUSVFSUpdateForEngine(context: context)
        }
        try runStage(.prefix) {
            try initializePrefix(context: context)
            try configureWineGraphicsDriver(context: context)
            try configureDisplayGeometry(context: context)
        }
        try runStage(.driveMapping) {
            try configureDriveMapping(context: &context)
        }
        try runStage(.winetricks) {
            try installWinetricksDependencies(context: context)
            try configureDllOverrides(context: context)
        }
        try runStage(.finalize) {
            try configureWinebusDefaults(context: context)
            try createDXMTConfig(context: context)
            try createDXVKConfig(context: context)
            try createMO2Batch(context: &context)
            try applyCommonFixes(context: context)
            try cleanupAnomalyCachesIfNeeded(context: context, rendererChangedOnUpdate: rendererChangedOnUpdate)
            try markManagedApp(context: context, status: "complete")
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
        try prepareTargetApp(context: context)
        try ensureAppTemplateLayout(context: context)
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
        try ensureWinetricks(context: context)
    }

    private func ensureHomebrew() throws -> String {
        guard let brew = findTool("brew") else {
            throw SetupEngineError.message("Homebrew is required to install Sikarugir and winetricks")
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

    private func ensureWinetricks(context: SetupContext) throws {
        _ = try ensureHomebrew()
        if findTool("winetricks") == nil {
            reporter.log("Installing winetricks")
            try runner(context: context).run(try ensureHomebrew(), ["install", "winetricks"])
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

    private func prepareTargetApp(context: SetupContext) throws {
        let app = context.outputApp
        if fileManager.fileExists(atPath: app.path) {
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: app.path, isDirectory: &isDir)
            if !isDir.boolValue {
                guard context.request.replace else {
                    throw SetupEngineError.message("target exists but is not an app directory: \(app.path)")
                }
                try remove(app, context: context)
            } else if context.request.replace {
                try remove(app, context: context)
            } else if fileManager.fileExists(atPath: context.appMarker.path) {
                let marker = (try? String(contentsOf: context.appMarker)) ?? ""
                let currentEngine = marker.split(whereSeparator: \.isNewline).first { $0.hasPrefix("engine=") }?.dropFirst("engine=".count) ?? ""
                if currentEngine != context.request.engine {
                    reporter.log("Rebuilding managed Sikarugir wrapper at \(app.path) because the engine changed")
                    try remove(app, context: context)
                } else {
                    reporter.log("Configuring existing managed Sikarugir wrapper at \(app.path)")
                    return
                }
            } else {
                reporter.log("Rebuilding existing Sikarugir wrapper at \(app.path) because setup metadata is missing")
                try remove(app, context: context)
            }
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
        plist["MOLTENVKCX"] = "1"
        plist["WINEMSYNC"] = context.request.wineMSync ? "1" : "0"
        plist["WINEESYNC"] = context.request.wineESync ? "1" : "0"
        plist["DXVK"] = renderer == "dxvk" ? "1" : "0"
        plist["DXMT"] = renderer == "dxmt" ? "1" : "0"
        plist["D9VK"] = "0"
        plist["CNC_DDRAW"] = "0"
        plist["FASTMATH"] = context.request.moltenVKFastMath ? "1" : "0"
        plist["METAL_HUD"] = context.request.metalHUD ? 1 : 0
        plist["Winetricks silent"] = "1"
        plist["Winetricks disable logging"] = "1"
        plist["WINEDEBUG"] = "-all"
        var environment = plist["LSEnvironment"] as? [String: String] ?? [:]
        for key in [
            "MVK_CONFIG_FAST_MATH_ENABLED", "MTL_HUD_ENABLED", "DXVK_HUD",
            "DXMT_METALFX_SPATIAL_SWAPCHAIN", "DXMT_CONFIG_FILE", "DXMT_CONFIG",
            "DXMT_LOG_LEVEL", "DXVK_CONFIG_FILE", "DXVK_FRAME_RATE", "DXVK_LOG_LEVEL",
            "QTWEBENGINE_CHROMIUM_FLAGS", "QT_OPENGL", "DYLD_FALLBACK_LIBRARY_PATH", "DYLD_LIBRARY_PATH"
        ] {
            environment.removeValue(forKey: key)
        }
        plist["LSEnvironment"] = environment
        let out = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try out.write(to: plistURL, options: .atomic)
    }

    private func installEngine(context: SetupContext) throws {
        let marker = context.markerDir.appendingPathComponent("engine-\(context.request.engine).done")
        if fileManager.fileExists(atPath: marker.path), fileManager.isExecutableFile(atPath: context.wineBin.path), !context.request.forceDownload {
            return
        }
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
        try fileManager.createDirectory(at: context.markerDir, withIntermediateDirectories: true)
        fileManager.createFile(atPath: marker.path, contents: Data())
    }

    private func installUSVFSUpdateForEngine(context: SetupContext) throws {
        guard context.request.updateUSVFS else { return }
        let marker = context.markerDir.appendingPathComponent("usvfs-\(context.request.engine).done")
        if fileManager.fileExists(atPath: marker.path), !context.request.forceDownload {
            return
        }
        reporter.log("Installing updated usvfs binaries for \(context.request.engine)")
        let source = try usvfsSource(context: context)
        let mo2Dir = URL(fileURLWithPath: context.mo2Path).deletingLastPathComponent()
        let files = ["usvfs_x64.dll", "usvfs_proxy_x64.exe", "usvfs_x86.dll", "usvfs_proxy_x86.exe"]
        for file in files where !fileManager.fileExists(atPath: source.appendingPathComponent(file).path) {
            throw SetupEngineError.message("missing updated usvfs binary: \(source.appendingPathComponent(file).path)")
        }
        guard !context.request.dryRun else { return }
        guard directoryExists(mo2Dir.path) else {
            throw SetupEngineError.message("missing ModOrganizer directory")
        }
        for file in files {
            try? fileManager.removeItem(at: mo2Dir.appendingPathComponent(file))
            try fileManager.copyItem(at: source.appendingPathComponent(file), to: mo2Dir.appendingPathComponent(file))
        }
        try fileManager.createDirectory(at: context.markerDir, withIntermediateDirectories: true)
        fileManager.createFile(atPath: marker.path, contents: Data())
    }

    private func initializePrefix(context: SetupContext) throws {
        let marker = context.markerDir.appendingPathComponent("prefix.done")
        if fileManager.fileExists(atPath: marker.path), fileManager.fileExists(atPath: context.userReg.path), directoryExists(context.driveC.path) {
            try normalizeWineUserProfile(context: context)
            return
        }
        reporter.log("Initializing Sikarugir Wine prefix")
        guard !context.request.dryRun else { return }
        try fileManager.createDirectory(at: context.prefix, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: context.markerDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: context.appLogDir, withIntermediateDirectories: true)
        try runner(context: context).run(context.wineBin.path, ["wineboot", "-u"], environment: wineEnvironment(context: context), label: "Wine prefix initialization")
        if fileManager.isExecutableFile(atPath: context.wineServerBin.path) {
            _ = try? runner(context: context).run(context.wineServerBin.path, ["-w"], environment: wineEnvironment(context: context))
        }
        guard fileManager.fileExists(atPath: context.userReg.path) else {
            throw SetupEngineError.message("Wine prefix initialization did not create user.reg")
        }
        try normalizeWineUserProfile(context: context)
        fileManager.createFile(atPath: marker.path, contents: Data())
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
        resolveDriveRoot(context: &context, allowRewrite: true)
        guard directoryExists(context.driveRoot) else {
            throw SetupEngineError.message("mounted disk root not found: \(context.driveRoot)")
        }
        guard !context.request.dryRun else { return }
        try fileManager.createDirectory(at: context.dosdevices, withIntermediateDirectories: true)
        try replaceSymlink(at: context.dosdevices.appendingPathComponent("\(context.driveLetter):"), destination: context.driveRoot)
        try replaceSymlink(at: context.dosdevices.appendingPathComponent("z:"), destination: "/")
        try replaceSymlink(at: context.dosdevices.appendingPathComponent("c:"), destination: "../drive_c")
        try replaceSymlink(at: context.contents.appendingPathComponent("drive_c"), destination: "SharedSupport/prefix/drive_c")
    }

    private func installWinetricksDependencies(context: SetupContext) throws {
        let groups: [(String, String, [String])] = [
            ("corefonts", "winetricks-corefonts.done", ["corefonts"]),
            ("vcrun2022", "winetricks-vcrun2022.done", ["vcrun2022"]),
            ("directx", "winetricks-directx.done", ["d3dcompiler_42", "d3dcompiler_43", "d3dcompiler_46", "d3dcompiler_47", "d3dx9", "d3dx10", "d3dx11_42", "d3dx11_43"])
        ]
        for (label, markerName, verbs) in groups {
            try installWinetricksGroup(label: label, marker: context.markerDir.appendingPathComponent(markerName), verbs: verbs, context: context)
        }
        if !context.request.extraWinetricks.isEmpty {
            try installWinetricksGroup(label: "extra", marker: context.markerDir.appendingPathComponent("winetricks-extra.done"), verbs: context.request.extraWinetricks, context: context)
        }
    }

    private func installWinetricksGroup(label: String, marker: URL, verbs: [String], context: SetupContext) throws {
        if fileManager.fileExists(atPath: marker.path) {
            return
        }
        reporter.log(label == "corefonts" ? "Installing corefonts with winetricks: Arial, Courier New, Times New Roman, Verdana" : "Installing \(label) with winetricks")
        guard !context.request.dryRun else { return }
        try fileManager.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: context.appLogDir, withIntermediateDirectories: true)
        try runner(context: context).run(findTool("winetricks") ?? "winetricks", ["-q"] + verbs, environment: wineEnvironment(context: context), label: "\(label) winetricks")
        fileManager.createFile(atPath: marker.path, contents: Data())
    }

    private func configureWineGraphicsDriver(context: SetupContext) throws {
        reporter.log("Configuring Wine macOS graphics driver")
        try ensureSectionKeyValues(file: context.userReg, section: #"Software\\Wine\\Drivers"#, entries: ["Graphics": "mac"], context: context)
    }

    private func configureDisplayGeometry(context: SetupContext) throws {
        if context.request.resetWineDisplay == true {
            reporter.log("Restoring default Wine display behavior")
            try resetDisplayGeometry(context: context)
            return
        }

        guard let width = context.request.displayResolutionWidth,
              let height = context.request.displayResolutionHeight,
              width > 0,
              height > 0 else {
            return
        }

        reporter.log("Configuring Wine display compatibility: \(width)x\(height)")
        try ensureSectionKeyValues(
            file: context.userReg,
            section: #"Software\\Wine\\Mac Driver"#,
            entries: ["RetinaMode": "n"],
            context: context
        )
        try ensureSectionRawLines(
            file: context.userReg,
            section: #"Control Panel\\Desktop"#,
            lines: [
                #""LogPixels"=dword:00000060"#,
                #""Win8DpiScaling"=dword:00000000"#
            ],
            context: context
        )

        if context.request.useWineVirtualDesktop == true {
            reporter.log("Enabling Wine virtual desktop: \(width)x\(height)")
            try ensureSectionKeyValues(
                file: context.userReg,
                section: #"Software\\Wine\\Explorer"#,
                entries: ["Desktop": "Default"],
                context: context
            )
            try ensureSectionKeyValues(
                file: context.userReg,
                section: #"Software\\Wine\\Explorer\\Desktops"#,
                entries: ["Default": "\(width)x\(height)"],
                context: context
            )
        } else {
            reporter.log("Disabling Wine virtual desktop")
            try removeSectionKeys(file: context.userReg, section: #"Software\\Wine\\Explorer"#, keys: ["Desktop"], context: context)
            try removeSectionKeys(file: context.userReg, section: #"Software\\Wine\\Explorer\\Desktops"#, keys: ["Default"], context: context)
        }
    }

    private func resetDisplayGeometry(context: SetupContext) throws {
        try removeSectionKeys(
            file: context.userReg,
            section: #"Software\\Wine\\Mac Driver"#,
            keys: ["RetinaMode"],
            context: context
        )
        try removeSectionKeys(
            file: context.userReg,
            section: #"Control Panel\\Desktop"#,
            keys: ["LogPixels", "Win8DpiScaling"],
            context: context
        )
        try removeSectionKeys(
            file: context.userReg,
            section: #"Software\\Wine\\Explorer"#,
            keys: ["Desktop"],
            context: context
        )
        try removeSectionKeys(
            file: context.userReg,
            section: #"Software\\Wine\\Explorer\\Desktops"#,
            keys: ["Default"],
            context: context
        )
    }

    private func configureDllOverrides(context: SetupContext) throws {
        reporter.log("Configuring DLL overrides")
        try removeRegistrySection(file: context.userReg, section: #"Software\\Wine\\DllOverrides"#, context: context)
        var entries: [String: String] = [:]
        for name in dllOverrideNames {
            entries["*\(name)"] = "native,builtin"
        }
        try ensureSectionKeyValues(file: context.userReg, section: #"Software\\Wine\\DllOverrides"#, entries: entries, context: context)
    }

    private func configureWinebusDefaults(context: SetupContext) throws {
        let section = #"System\\CurrentControlSet\\Services\\winebus"#
        let wineDefaultLines = [
            #""DisableHidraw"=dword:00000001"#,
            #""DisableInput"=dword:00000001"#,
            #""Enable SDL"=dword:00000001"#,
            #""Map Controllers"=dword:00000001"#
        ]
        let hidDeviceLines = [
            #""DisableHidraw"=dword:00000000"#,
            #""DisableInput"=dword:00000000"#,
            #""Enable SDL"=dword:00000000"#,
            #""Map Controllers"=dword:00000000"#
        ]
        let lines = (context.request.enableHIDDevices ?? false) ? hidDeviceLines : wineDefaultLines

        reporter.log((context.request.enableHIDDevices ?? false) ? "Enabling mouse input compatibility" : "Restoring Wine mouse input defaults")
        try ensureSectionRawLines(
            file: context.systemReg,
            section: section,
            lines: lines,
            context: context
        )
    }

    private func createDXMTConfig(context: SetupContext) throws {
        reporter.log("Creating DXMT configuration")
        let config = context.driveC.appendingPathComponent("dxmt.conf")
        guard context.request.renderer == "dxmt", context.request.dxmtMetalFXSpatial, !context.request.dxmtMetalFXScaleFactor.isEmpty else {
            if !context.request.dryRun {
                try? fileManager.removeItem(at: config)
            }
            return
        }
        guard !context.request.dryRun else { return }
        let text = """
        # Generated by GAMMA Setup Tool.
        # DXMT_METALFX_SPATIAL_SWAPCHAIN remains an environment switch.
        d3d11.metalSpatialUpscaleFactor = \(context.request.dxmtMetalFXScaleFactor)

        """
        try text.write(to: config, atomically: true, encoding: .utf8)
    }

    private func createDXVKConfig(context: SetupContext) throws {
        reporter.log("Creating DXVK configuration")
        let config = context.driveC.appendingPathComponent("dxvk.conf")
        guard context.request.renderer == "dxvk", !context.request.dxvkHUD.isEmpty else {
            if !context.request.dryRun {
                try? fileManager.removeItem(at: config)
            }
            return
        }
        guard !context.request.dryRun else { return }
        let text = """
        # Generated by GAMMA Setup Tool.
        # Sikarugir METAL_HUD remains the wrapper-level HUD on/off switch.
        dxvk.hud = \(context.request.dxvkHUD)

        """
        try text.write(to: config, atomically: true, encoding: .utf8)
    }

    private func createMO2Batch(context: inout SetupContext) throws {
        reporter.log("Creating ModOrganizer launch batch")
        resolveDriveRoot(context: &context, allowRewrite: false)
        let mo2WinPath = try nativeToWindowsPath(context.mo2Path, driveRoot: context.driveRoot, driveLetter: context.driveLetter)
        let mo2WinDir = URL(fileURLWithPath: mo2WinPath).deletingLastPathComponent().path
        let batch = context.driveC.appendingPathComponent(context.request.programBatch.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        guard !context.request.dryRun else { return }
        try fileManager.createDirectory(at: batch.deletingLastPathComponent(), withIntermediateDirectories: true)
        var lines = [
            "@echo off",
            #"set "QT_OPENGL=software""#,
            #"set "QT_QUICK_BACKEND=software""#,
            #"set "QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu""#
        ]
        if context.request.renderer == "dxmt", context.request.dxmtMetalFXSpatial {
            lines.append(#"set "DXMT_METALFX_SPATIAL_SWAPCHAIN=1""#)
        }
        if context.request.renderer == "dxmt", !context.request.dxmtLogLevel.isEmpty {
            lines.append(#"set "DXMT_LOG_LEVEL=\#(context.request.dxmtLogLevel)""#)
        }
        lines += [
            "",
            #"cd /d "\#(windowsBackslashPath(mo2WinDir))""#,
            #"start "" "\#(windowsBackslashPath(mo2WinPath))""#
        ]
        try (lines.joined(separator: "\r\n") + "\r\n").write(to: batch, atomically: true, encoding: .utf8)
    }

    private func applyCommonFixes(context: SetupContext) throws {
        for fix in context.request.commonFixes {
            switch fix {
            case "d3dmetal-reticle":
                try installReticleFix(context: context)
            default:
                throw SetupEngineError.message("unknown common fix: \(fix)")
            }
        }
    }

    private func cleanupAnomalyCachesIfNeeded(context: SetupContext, rendererChangedOnUpdate: Bool) throws {
        let reticleFixEnabled = context.request.commonFixes.contains("d3dmetal-reticle")
        guard reticleFixEnabled || rendererChangedOnUpdate else { return }
        guard !context.anomalyPath.isEmpty, directoryExists(context.anomalyPath) else { return }

        let anomaly = URL(fileURLWithPath: context.anomalyPath)
        let targets = [
            anomaly.appendingPathComponent("appdata/shaders_cache"),
            anomaly.appendingPathComponent("AnomalyDX11AVX.dxvk-cache"),
            anomaly.appendingPathComponent("AnomalyDX11.dxvk-cache")
        ]
        let reason = rendererChangedOnUpdate ? "translation layer changed" : "reticle fix enabled"
        for target in targets {
            if context.request.dryRun {
                if context.request.verbose { reporter.log("dry-run: remove \(target.path)") }
            } else if fileManager.fileExists(atPath: target.path) {
                try? fileManager.removeItem(at: target)
                reporter.log("Removed Anomaly cache for \(reason): \(target.path)")
            }
        }
    }

    private func installReticleFix(context: SetupContext) throws {
        let modName = "D3DMetal DXMT Reflex Reticle Fix"
        reporter.log("Installing common fix: \(modName)")
        let modsDir = URL(fileURLWithPath: context.gammaPath).appendingPathComponent("mods")
        let modDir = modsDir.appendingPathComponent(modName)
        guard !context.request.dryRun else { return }
        guard directoryExists(modsDir.path) else {
            throw SetupEngineError.message("MO2 mods directory not found")
        }
        let archive = try reticleFixArchive(context: context)
        try extractArchiveToMod(archive: archive, modDir: modDir, context: context)
        reporter.log("Installed \(modName) into \(modsDir.path)")
        reporter.log("Enable \"\(modName)\" in ModOrganizer before launching the game.")
    }

    private func reticleFixArchive(context: SetupContext) throws -> URL {
        let name = "D3DMetal DXMT Reflex Reticle Fix"
        if !context.request.forceDownload, let bundled = bundledReticleFixArchive(context: context) {
            return bundled
        }
        let out = context.cacheDir.appendingPathComponent("common-fixes/\(name).7z")
        if fileManager.fileExists(atPath: out.path), !context.request.forceDownload {
            return out
        }
        let api = "https://api.github.com/repos/elseform/gamma-macos-tool/releases/latest"
        let json = try downloadText(label: "reticle fix release", url: api, fallback: "", context: context)
        let data = Data(json.utf8)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assets = object["assets"] as? [[String: Any]],
              let url = assets.compactMap({ asset -> String? in
                  guard let name = asset["name"] as? String,
                        let download = asset["browser_download_url"] as? String,
                        name.range(of: #"^D3DMetal[ .]DXMT[ .]Reflex[ .]Reticle[ .]Fix.*\.7z$"#, options: [.regularExpression, .caseInsensitive]) != nil else {
                      return nil
                  }
                  return download
              }).first else {
            throw SetupEngineError.message("latest release does not contain a D3DMetal DXMT Reflex Reticle Fix .7z asset")
        }
        return try downloadFile(label: name, url: url, output: out, context: context)
    }

    private func extractArchiveToMod(archive: URL, modDir: URL, context: SetupContext) throws {
        guard let sevenZip = findTool("7zz") ?? findTool("7z") else {
            throw SetupEngineError.message("7-Zip is required to extract \(archive.path)")
        }
        let tmp = context.cacheDir.appendingPathComponent("common-fixes/extracted-reticle-fix")
        try? fileManager.removeItem(at: tmp)
        try fileManager.createDirectory(at: tmp, withIntermediateDirectories: true)
        try runner(context: context).run(sevenZip, ["x", "-y", archive.path, "-o\(tmp.path)"], label: "extract reticle fix")
        try? fileManager.removeItem(at: modDir)
        try fileManager.createDirectory(at: modDir, withIntermediateDirectories: true)
        let gamedata = tmp.appendingPathComponent("gamedata")
        if directoryExists(gamedata.path) {
            try fileManager.copyItem(at: gamedata, to: modDir.appendingPathComponent("gamedata"))
        } else {
            for child in try fileManager.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
                try fileManager.copyItem(at: child, to: modDir.appendingPathComponent(child.lastPathComponent))
            }
        }
        try? fileManager.removeItem(at: tmp)
    }

    private func markManagedApp(context: SetupContext, status: String) throws {
        guard !context.request.dryRun else { return }
        try fileManager.createDirectory(at: context.sharedSupport, withIntermediateDirectories: true)
        let text = """
        managed_by=gamma-setup-engine
        engine=\(context.request.engine)
        renderer=\(context.request.renderer)
        wine_esync=\(managedEnabled(context.request.wineESync))
        wine_msync=\(managedEnabled(context.request.wineMSync))
        mouse_input=\((context.request.enableHIDDevices ?? false) ? "compatibility" : "default")
        update_usvfs=\(managedEnabled(context.request.updateUSVFS))
        moltenvk_fast_math=\(managedEnabled(context.request.moltenVKFastMath))
        metal_hud=\(managedEnabled(context.request.metalHUD))
        dxmt_metalfx_spatial=\(managedEnabled(context.request.dxmtMetalFXSpatial))
        dxmt_scale=\(context.request.dxmtMetalFXScaleFactor)
        dxmt_log=\(context.request.dxmtLogLevel.isEmpty ? "default" : context.request.dxmtLogLevel)
        dxvk_hud=\(context.request.dxvkHUD.isEmpty ? "default" : context.request.dxvkHUD)
        reticle_fix=\(managedEnabled(context.request.commonFixes.contains("d3dmetal-reticle")))
        extra_winetricks=\(context.request.extraWinetricks.joined(separator: " "))
        display_mode=\(managedDisplayMode(context: context))
        display_resolution=\(managedDisplayResolution(context: context))
        wine_virtual_desktop=\((context.request.useWineVirtualDesktop == true) ? "enabled" : "disabled")
        template=\(context.templateName)
        status=\(status)
        created_or_updated=\(isoTimestamp())

        """
        try text.write(to: context.appMarker, atomically: true, encoding: .utf8)
    }

    private func managedEnabled(_ enabled: Bool) -> String {
        enabled ? "enabled" : "disabled"
    }

    private func managedDisplayMode(context: SetupContext) -> String {
        if context.request.resetWineDisplay == true {
            return "defaultWine"
        }
        if context.request.displayResolutionWidth != nil, context.request.displayResolutionHeight != nil {
            return "forced"
        }
        return "defaultWine"
    }

    private func managedDisplayResolution(context: SetupContext) -> String {
        guard let width = context.request.displayResolutionWidth,
              let height = context.request.displayResolutionHeight,
              width > 0,
              height > 0 else {
            return ""
        }
        return "\(width)x\(height)"
    }

    private func rendererChangedForExistingManagedApp(context: SetupContext) -> Bool {
        guard fileManager.fileExists(atPath: context.appMarker.path) else { return false }
        let marker = (try? String(contentsOf: context.appMarker)) ?? ""
        if let markerRenderer = markerValue("renderer", in: marker), !markerRenderer.isEmpty {
            return markerRenderer != context.request.renderer
        }
        guard let currentRenderer = currentAppRenderer(context: context) else { return false }
        return currentRenderer != context.request.renderer
    }

    private func currentAppRenderer(context: SetupContext) -> String? {
        let plistURL = context.contents.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        if boolLike(plist["DXVK"]) { return "dxvk" }
        if boolLike(plist["DXMT"]) { return "dxmt" }
        if boolLike(plist["D3DMETAL"]) { return "d3dmetal" }
        return nil
    }

    private func markerValue(_ key: String, in marker: String) -> String? {
        let prefix = "\(key)="
        return marker
            .split(whereSeparator: \.isNewline)
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    private func boolLike(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let int = value as? Int { return int != 0 }
        if let string = value as? String {
            return ["1", "true", "yes", "enabled"].contains(string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
        return false
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
        guard fileManager.fileExists(atPath: batch.path) else { throw SetupEngineError.message("missing ModOrganizer batch") }
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

    private func resolveDriveRoot(context: inout SetupContext, allowRewrite: Bool) {
        if !context.mo2IniDriveRoot.isEmpty {
            context.driveRoot = context.mo2IniDriveRoot
        } else if !context.anomalyPath.isEmpty, directoryExists(context.anomalyPath) {
            context.driveRoot = commonParent(context.gammaPath, context.anomalyPath)
        } else if !context.gammaPath.isEmpty {
            context.driveRoot = URL(fileURLWithPath: context.gammaPath).deletingLastPathComponent().path
        }
        if context.driveRoot == "/", context.mo2IniDriveLetter != "z" {
            if pathIsUnder(context.gammaPath, parent: NSHomeDirectory()) && (context.anomalyPath.isEmpty || pathIsUnder(context.anomalyPath, parent: NSHomeDirectory())) {
                context.driveRoot = NSHomeDirectory()
            } else if !context.gammaPath.isEmpty {
                context.driveRoot = URL(fileURLWithPath: context.gammaPath).deletingLastPathComponent().path
            }
        }

        if context.mo2IniDriveLetter == "z", context.driveRoot == "/", context.request.driveMappingMode != "shorten" {
            context.driveLetter = "z"
            context.zRewriteRequired = true
        } else if context.mo2IniDriveLetter == "z" {
            let target = context.driveRoot
            if allowRewrite, context.request.driveMappingMode == "shorten" {
                try? rewriteModOrganizerIniDrive(context: &context, from: "z", to: "g", mountedRoot: target)
            }
            context.driveLetter = "g"
            context.mo2IniDriveRoot = target
        } else if !context.mo2IniDriveLetter.isEmpty {
            context.driveLetter = context.mo2IniDriveLetter
        }
        context.driveLetter = context.driveLetter.lowercased()
    }

    private func rewriteModOrganizerIniDrive(context: inout SetupContext, from: String, to: String, mountedRoot: String) throws {
        guard fileManager.fileExists(atPath: context.mo2IniPath) else {
            throw SetupEngineError.message("ModOrganizer.ini not found: \(context.mo2IniPath)")
        }
        guard !context.request.dryRun else { return }
        let rootRel = mountedRoot.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var text = try String(contentsOfFile: context.mo2IniPath)
        if !rootRel.isEmpty {
            let parts = rootRel.split(separator: "/").map { NSRegularExpression.escapedPattern(for: String($0)) }
            let sep = #"(?:(?:\\\\)|\\|/)+"#
            let rootPattern = parts.joined(separator: sep)
            let pattern = "\(NSRegularExpression.escapedPattern(for: from + ":"))\(sep)\(rootPattern)\(sep)?"
            text = text.replacingOccurrences(of: pattern, with: to.uppercased() + #":\\"#, options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(of: "\(from):", with: "\(to.uppercased()):", options: [.caseInsensitive])
        try text.write(toFile: context.mo2IniPath, atomically: true, encoding: .utf8)
        loadModOrganizerIni(context: &context)
    }

    private func wineEnvironment(context: SetupContext) -> [String: String] {
        let libraryPath = "\(context.contents.path)/Frameworks:\(context.sharedSupport.path):\(context.wineDir.path)/lib:/opt/homebrew/lib:/usr/local/lib:/usr/lib"
        return [
            "WINEPREFIX": context.prefix.path,
            "WINEARCH": "win64",
            "PATH": "\(context.wineDir.path)/bin:/opt/homebrew/bin:/usr/local/bin:" + (ProcessInfo.processInfo.environment["PATH"] ?? ""),
            "DYLD_FALLBACK_LIBRARY_PATH": libraryPath,
            "WINETRICKS_FALLBACK_LIBRARY_PATH": libraryPath
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
        guard context.mo2IniDriveLetter == "z",
              !context.gammaPath.isEmpty,
              directoryExists(context.gammaPath),
              !context.anomalyPath.isEmpty,
              directoryExists(context.anomalyPath) else {
            return ""
        }
        let root = commonParent(context.gammaPath, context.anomalyPath)
        return root == "/" ? "" : root
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

    private func loadUserLtxResolution(context: inout SetupContext) {
        guard !context.anomalyPath.isEmpty else { return }
        let userLtx = URL(fileURLWithPath: context.anomalyPath).appendingPathComponent("appdata/user.ltx")
        context.userLtxPath = userLtx.path
        guard let text = try? String(contentsOf: userLtx),
              let resolution = userLtxResolution(text: text) else {
            return
        }
        context.gameResolutionWidth = resolution.width
        context.gameResolutionHeight = resolution.height
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

    private func bundledReticleFixArchive(context: SetupContext) -> URL? {
        let dirs = [
            context.scriptRoot.appendingPathComponent("mods"),
            context.scriptRoot.appendingPathComponent("sources/GAMMASetupTool/Resources/mods"),
            context.scriptRoot.appendingPathComponent("../../sources/GAMMASetupTool/Resources/mods")
        ]
        for dir in dirs {
            guard let children = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            if let match = children.first(where: { $0.lastPathComponent.hasPrefix("D3DMetal DXMT Reflex Reticle Fix") && $0.pathExtension == "7z" }) {
                return match
            }
        }
        return nil
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

        throw SetupEngineError.message("updated usvfs binaries were requested but no source was provided or bundled at Resources/usvfs")
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

    private func userLtxResolution(text: String) -> (width: Int, height: Int)? {
        for line in text.split(whereSeparator: \.isNewline).map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2, parts[0] == "vid_mode" else { continue }
            let dimensions = parts[1].split(separator: "x", maxSplits: 1)
            guard dimensions.count == 2,
                  let width = Int(dimensions[0]),
                  let height = Int(dimensions[1]) else {
                continue
            }
            return (width, height)
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

    private func isoTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: Date())
    }

    private func errorDescription(_ error: Error) -> String {
        if let setup = error as? SetupEngineError {
            return setup.description
        }
        return error.localizedDescription
    }
}

private let dllOverrideNames = [
    "concrt140",
    "d3dcompiler_43",
    "d3dcompiler_47",
    "d3dx10",
    "d3dx10_33", "d3dx10_34", "d3dx10_35", "d3dx10_36", "d3dx10_37", "d3dx10_38", "d3dx10_39", "d3dx10_40", "d3dx10_41", "d3dx10_42", "d3dx10_43",
    "d3dx11_42", "d3dx11_43",
    "d3dx9_24", "d3dx9_25", "d3dx9_26", "d3dx9_27", "d3dx9_28", "d3dx9_29", "d3dx9_30", "d3dx9_31", "d3dx9_32", "d3dx9_33",
    "d3dx9_34", "d3dx9_35", "d3dx9_36", "d3dx9_37", "d3dx9_38", "d3dx9_39", "d3dx9_40", "d3dx9_41", "d3dx9_42", "d3dx9_43",
    "msvcp140", "msvcp140_1", "msvcp140_2", "msvcp140_atomic_wait", "msvcp140_codecvt_ids",
    "vcamp140", "vccorlib140", "vcomp140",
    "vcruntime140", "vcruntime140_1"
]
