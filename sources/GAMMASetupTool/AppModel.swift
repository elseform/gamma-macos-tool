import SwiftUI
import AppKit

struct Preflight: Codable {
    var targetApp: String
    var engine: String
    var renderer: String
    var moltenVKFastMath: Bool
    var programBatch: String
    var stalkerGammaPath: String
    var stalkerGammaFound: Bool
    var settingsFile: String
    var settingsFound: Bool
    var gammaPath: String
    var gammaFound: Bool
    var mo2Path: String
    var mo2Found: Bool
    var anomalyPath: String
    var anomalyFound: Bool
    var mo2Profile: String
    var modlistPath: String
    var modlistFound: Bool
    var modOrganizerIni: String
    var modOrganizerIniFound: Bool
    var modOrganizerGamePath: String
    var wineDriveLetter: String
    var wineDriveRoot: String
    var zRewriteRequired: Bool
    var homebrewPath: String
    var homebrewFound: Bool
    var sikarugirTapInstalled: Bool
    var sikarugirInstalled: Bool
    var winetricksPath: String
    var winetricksFound: Bool
}

struct ToolResult {
    var output: String
    var exitCode: Int32
}

final class OutputBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func stringValue() -> String {
        lock.lock()
        let current = data
        lock.unlock()
        return String(data: current, encoding: .utf8) ?? ""
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var appName = "stalker-gamma"
    @Published var installDirectory = NSString(string: "~/Applications/Sikarugir").expandingTildeInPath
    @Published var renderer = "d3dmetal"
    @Published var moltenVKFastMath = false
    @Published var metalHUD = false
    @Published var dxmtMetalFXSpatial = false
    @Published var dxmtMaxFrameRate = ""
    @Published var dxmtLogLevel = "default"
    @Published var extraWinetricks = ""
    @Published var applyReticleFix = false
    @Published var writeLog = false
    @Published var verboseInstall = false
    @Published var preflight: Preflight?
    @Published var preflightError = ""
    @Published var logText = ""
    @Published var statusText = "Ready"
    @Published var isRunning = false
    @Published var isInstallingComponents = false
    @Published var showOutput = false
    @Published var progress = 0.0
    @Published var createModeOverride: String?

    let requiredWinetricks = [
        "corefonts",
        "d3dcompiler_43",
        "d3dcompiler_47",
        "d3dx9",
        "d3dx10",
        "d3dx11_43",
        "vcrun2022"
    ]

    var scriptURL: URL {
        if let bundled = Bundle.main.url(forResource: "gamma-setup-tool", withExtension: "sh") {
            return bundled
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceScript = cwd.appendingPathComponent("sources/scripts/gamma-setup-tool.sh")
        if FileManager.default.fileExists(atPath: sourceScript.path) {
            return sourceScript
        }
        return cwd.appendingPathComponent("gamma-setup-tool.sh")
    }

    var outputAppPath: String {
        let cleanName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = cleanName.hasSuffix(".app") ? String(cleanName.dropLast(4)) : cleanName
        let name = "\(baseName).app"
        return URL(fileURLWithPath: installDirectory).appendingPathComponent(name).path
    }

    var outputAppExists: Bool {
        FileManager.default.fileExists(atPath: outputAppPath)
    }

    var outputAppStatus: String {
        outputAppExists ? "Already exists" : "Will be created"
    }

    var createModeLabel: String {
        createModeOverride ?? (outputAppExists ? "Update existing wrapper" : "Create new wrapper")
    }

    var environmentOK: Bool {
        guard let preflight else { return false }
        return preflight.stalkerGammaFound
            && preflight.settingsFound
            && preflight.homebrewFound
            && preflight.sikarugirTapInstalled
            && preflight.sikarugirInstalled
            && preflight.winetricksFound
            && preflight.anomalyFound
            && preflight.gammaFound
            && preflight.mo2Found
            && preflight.modOrganizerIniFound
    }

    var canInstallComponents: Bool {
        guard let preflight else { return false }
        return preflight.stalkerGammaFound
            && preflight.settingsFound
            && preflight.homebrewFound
            && (!preflight.sikarugirTapInstalled || !preflight.sikarugirInstalled || !preflight.winetricksFound)
    }

    var primaryButtonTitle: String {
        "Create GAMMA Wrapper"
    }

    var environmentMessage: String {
        guard let preflight else { return "Checking environment..." }
        if !preflight.stalkerGammaFound {
            return "Install stalker-gamma-cli first so the stalker-gamma command is available."
        }
        if !preflight.settingsFound {
            return "Run stalker-gamma once so it creates its settings file."
        }
        if !preflight.homebrewFound {
            return "Install Homebrew first; it is required for Sikarugir and winetricks."
        }
        if !preflight.anomalyFound || !preflight.gammaFound || !preflight.mo2Found || !preflight.modOrganizerIniFound {
            return "GAMMA, Anomaly, ModOrganizer.exe, and ModOrganizer.ini must be available at the detected paths."
        }
        return "Install missing Homebrew-managed setup components, then recheck."
    }

    func chooseInstallDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: installDirectory)
        if panel.runModal() == .OK, let url = panel.url {
            installDirectory = url.path
            Task { await refreshPreflight() }
        }
    }

    func refreshPreflight() async {
        preflightError = ""
        let args = baseArguments() + ["--preflight-json"]
        do {
            let result = try await runTool(arguments: args, stream: false)
            guard result.exitCode == 0 else {
                preflight = nil
                preflightError = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                return
            }
            preflight = try JSONDecoder().decode(Preflight.self, from: Data(result.output.utf8))
        } catch {
            preflight = nil
            preflightError = error.localizedDescription
        }
    }

    func create() async -> Bool {
        isRunning = true
        isInstallingComponents = false
        createModeOverride = outputAppExists ? "Update existing wrapper" : "Create new wrapper"
        progress = 0
        logText = ""
        statusText = "Creating wrapper"
        do {
            let result = try await runTool(arguments: baseArguments() + selectedOptions(), stream: true)
            isRunning = false
            progress = result.exitCode == 0 ? 1 : progress
            statusText = result.exitCode == 0 ? "Wrapper created" : "Failed"
            await refreshPreflight()
            return result.exitCode == 0
        } catch {
            isRunning = false
            logText += "\n\(error.localizedDescription)"
            statusText = "Failed"
            return false
        }
    }

    func resetForNewWrapper() {
        logText = ""
        statusText = "Ready"
        progress = 0
        isInstallingComponents = false
        createModeOverride = nil
        showOutput = false
    }

    func openCreatedApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: outputAppPath))
    }

    func installComponents() async {
        isRunning = true
        isInstallingComponents = true
        progress = 0
        logText = ""
        statusText = "Installing components"
        do {
            let result = try await runTool(arguments: baseArguments() + ["--install-components-only"], stream: true)
            isRunning = false
            isInstallingComponents = false
            if result.exitCode == 0 {
                progress = 1
                statusText = "Rechecking environment"
                await refreshPreflight()
                logText = ""
                statusText = "Ready"
                progress = 0
                showOutput = false
            } else {
                statusText = "Install failed"
            }
        } catch {
            isRunning = false
            isInstallingComponents = false
            logText += "\n\(error.localizedDescription)"
            statusText = "Install failed"
        }
    }

    private func baseArguments() -> [String] {
        ["--output-app", outputAppPath, "--renderer", renderer]
    }

    private func selectedOptions() -> [String] {
        var args: [String] = []
        let extra = extraWinetricks.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty {
            args += ["--extra-winetricks", extra]
        }
        if moltenVKFastMath {
            args += ["--moltenvk-fast-math"]
        }
        if metalHUD {
            args += ["--metal-hud"]
        }
        if renderer == "dxmt", dxmtMetalFXSpatial {
            args += ["--dxmt-metalfx-spatial"]
        }
        let maxFrameRate = dxmtMaxFrameRate.trimmingCharacters(in: .whitespacesAndNewlines)
        if renderer == "dxmt", !maxFrameRate.isEmpty {
            args += ["--dxmt-max-frame-rate", maxFrameRate]
        }
        if renderer == "dxmt", dxmtLogLevel != "default" {
            args += ["--dxmt-log-level", dxmtLogLevel]
        }
        if writeLog {
            args += ["--log-file"]
        }
        if verboseInstall {
            args += ["--verbose"]
        }
        if applyReticleFix {
            args += ["--common-fix", "d3dmetal-reticle"]
        }
        if preflight?.zRewriteRequired == true {
            args += ["--assume-rewrite-z"]
        }
        return args
    }

    private func runTool(arguments: [String], stream: Bool) async throws -> ToolResult {
        let script = scriptURL
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [script.path] + arguments
            process.currentDirectoryURL = script.deletingLastPathComponent()

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let buffer = OutputBuffer()
            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                buffer.append(data)
                guard stream, let text = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    self?.appendLog(text)
                }
            }

            process.terminationHandler = { proc in
                handle.readabilityHandler = nil
                let remaining = handle.readDataToEndOfFile()
                if !remaining.isEmpty {
                    buffer.append(remaining)
                }
                let output = buffer.stringValue()
                continuation.resume(returning: ToolResult(output: output, exitCode: proc.terminationStatus))
            }

            do {
                try process.run()
            } catch {
                handle.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    private func appendLog(_ text: String) {
        logText += text
        for line in text.split(separator: "\n") {
            if line.hasPrefix("==>") {
                statusText = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                progress = min(progress + 0.07, 0.95)
            }
        }
    }
}
