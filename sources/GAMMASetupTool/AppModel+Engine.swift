import SwiftUI
import AppKit
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

extension AppModel {
    // MARK: - Request Construction

    func engineRequest() -> SetupRequest {
        var request = configuration.setupRequest
        request.resourceRoot = AppResources.bundle.resourceURL?.path ?? Bundle.main.resourceURL?.path ?? ""
        if let icon = AppResources.bundle.url(forResource: "Anomaly", withExtension: "icns")
            ?? Bundle.main.url(forResource: "Anomaly", withExtension: "icns") {
            request.appIconSource = icon.path
        }
        return request
    }

    // MARK: - Process Execution

    func runEngine(
        command: String,
        request: SetupRequest,
        extraArguments: [String] = [],
        stream: Bool
    ) async throws -> ToolResult {
        let engine = engineURL
        let requestURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gamma-setup-engine-\(UUID().uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(request).write(to: requestURL, options: .atomic)

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = engine
            process.arguments = [command, "--request-file", requestURL.path] + extraArguments
            process.currentDirectoryURL = engine.deletingLastPathComponent()

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

            process.terminationHandler = { [process] proc in
                process.terminationHandler = nil
                handle.readabilityHandler = nil
                try? FileManager.default.removeItem(at: requestURL)
                let remaining = handle.readDataToEndOfFile()
                if !remaining.isEmpty {
                    buffer.append(remaining)
                    if stream, let text = String(data: remaining, encoding: .utf8) {
                        Task { @MainActor in
                            self.appendLog(text)
                        }
                    }
                }
                let output = buffer.stringValue()
                continuation.resume(returning: ToolResult(output: output, exitCode: proc.terminationStatus))
            }

            do {
                try process.run()
            } catch {
                handle.readabilityHandler = nil
                try? FileManager.default.removeItem(at: requestURL)
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Event Handling

    private func appendLog(_ text: String) {
        pendingEngineEventText += text
        var lines = pendingEngineEventText.components(separatedBy: "\n")
        pendingEngineEventText = lines.popLast() ?? ""
        for line in lines where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if handleEngineEventLine(line) {
                continue
            }
            logText += line + "\n"
        }
    }

    private func handleEngineEventLine(_ line: String) -> Bool {
        guard let data = line.data(using: .utf8),
              let event = try? JSONDecoder().decode(SetupEngineEvent.self, from: data) else {
            return false
        }
        receivedInstallStageEvents = true

        switch event.type {
        case .log:
            let message = event.message ?? ""
            guard !message.isEmpty else { return true }
            logText += "==> \(message)\n"
            statusText = message
            progress = min(progress + 0.07, 0.95)
        case .artifact:
            if event.message == "Log file", let path = event.path {
                savedLogPath = path
                logText += "Log file: \(path)\n"
            }
        case .completed:
            if let message = event.message, !message.isEmpty {
                logText += "\(message)\n"
            }
        case .stageStarted, .stageFinished, .stageFailed:
            guard let stage = event.stage, let index = installStageIndex(for: stage) else {
                return true
            }
            switch event.type {
            case .stageStarted:
                installStageIndex = index
                statusText = installStageName(at: index)
            case .stageFinished:
                installStageCompletedIndex = max(installStageCompletedIndex, index)
                if installStageIndex == index {
                    installStageIndex = -1
                }
                progress = max(progress, Double(index + 1) / Double(installStageCount))
            case .stageFailed:
                installStageIndex = index
                installFailed = true
                if let message = event.message {
                    logText += "error: \(message)\n"
                }
            default:
                break
            }
        }
        return true
    }

    private func installStageIndex(for stage: SetupEngineStage) -> Int? {
        switch stage {
        case .wrapper: return 0
        case .engine: return 1
        case .prefix: return 2
        case .driveMapping: return 3
        case .winetricks: return 4
        case .finalize: return 5
        }
    }

    private func inferredInstallStageIndex(from status: String) -> Int {
        let status = status.lowercased()
        if status.contains("creating sikarugir wrapper")
            || status.contains("rebuilding")
            || status.contains("configuring existing")
            || status.contains("installing anomaly app icon")
            || status.contains("restoring sikarugir app frameworks")
            || status.contains("configuring sikarugir app plist") {
            return 0
        }
        if status.contains("installing sikarugir engine") || status.contains("usvfs") {
            return 1
        }
        if status.contains("initializing sikarugir wine prefix")
            || status.contains("configuring wine macos graphics driver") {
            return 2
        }
        if status.contains("configuring wine drive mapping")
            || status.contains("modorganizer.ini") {
            return 3
        }
        if status.contains("winetricks")
            || status.contains("corefonts")
            || status.contains("vcrun2022")
            || status.contains("directx")
            || status.contains("dll overrides") {
            return 4
        }
        if status.contains("wine hid")
            || status.contains("creating dxmt")
            || status.contains("creating dxvk")
            || status.contains("modorganizer launch batch")
            || status.contains("common fix")
            || status.contains("normalizing")
            || status.contains("registering")
            || status.contains("summary")
            || status.contains("touching") {
            return 5
        }
        return installStageIndex
    }

    var installStageCount: Int {
        6
    }

    func installStageName(at index: Int) -> String {
        switch index {
        case 0: return "wrapper creation"
        case 1: return "engine installation"
        case 2: return "prefix initialization"
        case 3: return "drive mapping"
        case 4: return "winetricks"
        case 5: return "finalization"
        default: return "setup"
        }
    }
}
