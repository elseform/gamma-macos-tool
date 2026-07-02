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

enum SetupComponent: String {
    case sikarugir
    case winetricks
}

struct SetupSummaryItem: Identifiable {
    var id: String { label }
    let label: String
    let planned: String
    let current: String?

    var changed: Bool {
        guard let current else { return false }
        return current != planned
    }

    var displayValue: String {
        if let current, current != planned {
            return "\(current) -> \(planned)"
        }
        return planned
    }
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
    @Published var wineESync = true
    @Published var wineMSync = true
    @Published var updateUSVFS = false
    @Published var enableHIDDevices = false
    @Published var enableFnToggle = false
    @Published var moltenVKFastMath = false
    @Published var metalHUD = false
    @Published var dxmtMetalFXSpatial = false
    @Published var dxmtMetalFXScaleFactor = ""
    @Published var dxmtLogLevel = "default"
    @Published var dxvkHUD = "default"
    @Published var programBatch = "/mo2.bat"
    @Published var launchBatches: [LaunchBatch] = []
    @Published var extraWinetricks = ""
    @Published var applyReticleFix = true
    @Published var saveVerboseLog = true
    @Published var driveMappingMode = "preserve"
    @Published var displayMode = "forced"
    @Published var displayResolutionMode = "detected"
    @Published var customDisplayResolutionWidth = ""
    @Published var customDisplayResolutionHeight = ""
    @Published var detectedDisplay: MacDisplaySettings?
    @Published var manualModOrganizerPath = ""
    @Published var modOrganizerSelectionError = ""
    @Published var selectedExistingWrapperPath = ""
    @Published var preflight: Preflight?
    @Published var preflightError = ""
    @Published var logText = ""
    @Published var savedLogPath = ""
    @Published var statusText = "Ready"
    @Published var isRunning = false
    @Published var isInstallingComponents = false
    @Published var installingComponent: SetupComponent?
    @Published var showOutput = false
    @Published var progress = 0.0
    @Published var createModeOverride: String?
    @Published var currentSettingsOverride: [String: String]?
    @Published var frozenSetupSummaryItems: [SetupSummaryItem]?
    @Published var installStageIndex = -1
    @Published var installStageCompletedIndex = -1
    @Published var installFailed = false
    @Published var existingWrapperSettingsDetected = false
    var appliedWrapperSettingsPath: String?
    var receivedInstallStageEvents = false
    var pendingEngineEventText = ""

    let requiredWinetricks = [
        "corefonts",
        "d3dx9_43",
        "d3dx11_43",
        "d3dcompiler_47",
        "vcrun2026"
    ]

    let requiredDllOverrides: [String: String] = [
        "concrt140": "native,builtin",
        "d3dcompiler_47": "native",
        "d3dx11_43": "native",
        "d3dx9_43": "native",
        "msvcp140": "native,builtin",
        "msvcp140_1": "native,builtin",
        "msvcp140_2": "native,builtin",
        "msvcp140_atomic_wait": "native,builtin",
        "msvcp140_codecvt_ids": "native,builtin",
        "vcamp140": "native,builtin",
        "vccorlib140": "native,builtin",
        "vcomp140": "native,builtin",
        "vcruntime140": "native,builtin",
        "vcruntime140_1": "native,builtin",
    ]

    init() {
        loadSettings()
    }
}
