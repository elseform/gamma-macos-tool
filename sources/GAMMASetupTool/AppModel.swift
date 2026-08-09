import SwiftUI
import AppKit
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct ToolResult {
    let output: String
    let exitCode: Int32
}

struct SetupSummaryItem: Identifiable {
    var id: String { label }
    let label: String
    let planned: String
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
        defer { lock.unlock() }
        let current = data
        return String(data: current, encoding: .utf8) ?? ""
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var appName = "stalker-gamma"
    @Published var installDirectory = SetupConfiguration.defaultInstallDirectory
    @Published var engine = SetupConfiguration.defaultEngine
    @Published var renderer = "d3dmetal"
    @Published var updateUSVFS = true
    @Published var installGPTK4Binaries = true
    @Published var installDirectXBinaries = false
    @Published var programBatch = "/mo2.bat"
    @Published var launchBatches: [LaunchBatch] = []
    @Published var launchArguments = ""
    @Published var saveVerboseLog = false
    @Published var driveMappingMode = "preserve"
    @Published var displayMode = "defaultWine"
    @Published var displayResolutionMode = "detected"
    @Published var customDisplayResolutionWidth = ""
    @Published var customDisplayResolutionHeight = ""
    @Published var detectedDisplay: MacDisplaySettings?
    @Published var manualModOrganizerPath = ""
    @Published var modOrganizerSelectionError = ""
    @Published var preflight: Preflight?
    @Published var preflightError = ""
    @Published var logText = ""
    @Published var savedLogPath = ""
    @Published var statusText = "Ready"
    @Published var isRunning = false
    @Published var showOutput = false
    @Published var progress = 0.0
    @Published var frozenSetupSummaryItems: [SetupSummaryItem]?
    @Published var installStageIndex = -1
    @Published var installStageCompletedIndex = -1
    @Published var installFailed = false
    var receivedInstallStageEvents = false
    var pendingEngineEventText = ""

    let requiredWinetricks = [
        "corefonts",
        "d3dx9_43",
        "d3dx11_43",
        "d3dcompiler_47",
        "vcrun2026"
    ]

    init() {
        loadSettings()
    }
}
