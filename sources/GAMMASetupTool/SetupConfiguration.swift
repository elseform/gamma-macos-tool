import Foundation

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct SetupConfiguration {
    static let defaultEngine = SetupDefaults.defaultEngine
    static let sikarugir10Engine = SetupDefaults.sikarugir10Engine
    static let supportedEngines = SetupDefaults.supportedEngines

    var appName = "stalker-gamma"
    var installDirectory = NSString(string: "~/Applications/Sikarugir").expandingTildeInPath
    var engine = SetupConfiguration.defaultEngine
    var renderer = "d3dmetal"
    var wineESync = true
    var wineMSync = true
    var updateUSVFS = false
    var enableHIDDevices = false
    var moltenVKFastMath = false
    var metalHUD = false
    var dxmtMetalFXSpatial = false
    var dxmtMetalFXScaleFactor = ""
    var dxmtLogLevel = "default"
    var dxvkHUD = "default"
    var extraWinetricks = ""
    var applyReticleFix = true
    var saveVerboseLog = true
    var driveMappingMode = "preserve"
    var manualModOrganizerPath = ""
    var preflight: Preflight?
    var outputAppExists = false

    var outputAppPath: String {
        let cleanName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = cleanName.hasSuffix(".app") ? String(cleanName.dropLast(4)) : cleanName
        let name = "\(baseName).app"
        return URL(fileURLWithPath: installDirectory).appendingPathComponent(name).path
    }

    var rendererLabel: String {
        switch renderer {
        case "dxmt":
            return "DXMT"
        case "dxvk":
            return "DXVK"
        default:
            return "D3DMetal"
        }
    }

    var engineLabel: String {
        switch engine {
        case Self.sikarugir10Engine:
            return "Wine Sikarugir 10.0"
        default:
            return "Wine CX 24.0.7"
        }
    }

    var environmentOK: Bool {
        guard let preflight else { return false }
        return preflight.homebrewFound
            && preflight.sikarugirInstalled
            && preflight.winetricksFound
            && preflight.gammaFound
            && preflight.mo2Found
            && preflight.modOrganizerIniFound
    }

    var canInstallComponents: Bool {
        guard let preflight else { return false }
        return preflight.homebrewFound
            && (!preflight.sikarugirTapInstalled || !preflight.sikarugirInstalled || !preflight.winetricksFound)
    }

    var plannedWineDriveMapping: String {
        guard let preflight else { return "" }
        if driveMappingMode == "shorten", preflight.zShortenAvailable {
            return "\(preflight.shortWineDriveLetter): -> \(preflight.shortWineDriveRoot)"
        }
        return "\(preflight.wineDriveLetter): -> \(preflight.wineDriveRoot)"
    }

    var plannedModOrganizerGamePath: String {
        guard let preflight else { return "" }
        guard willRewriteModOrganizerIni else { return preflight.modOrganizerGamePath }

        let rootRelative = preflight.shortWineDriveRoot
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map(String.init)
        let gameRelative = windowsPathRelative(preflight.modOrganizerGamePath)

        guard !rootRelative.isEmpty,
              gameRelative.count >= rootRelative.count,
              zip(rootRelative, gameRelative).allSatisfy({ $0.0.caseInsensitiveCompare($0.1) == .orderedSame }) else {
            return preflight.modOrganizerGamePath
        }

        let suffix = gameRelative.dropFirst(rootRelative.count)
        let drive = preflight.shortWineDriveLetter.uppercased()
        if suffix.isEmpty {
            return "\(drive):\\"
        }
        return "\(drive):\\" + suffix.joined(separator: "\\")
    }

    var willRewriteModOrganizerIni: Bool {
        guard let preflight else { return false }
        return driveMappingMode == "shorten" && preflight.zShortenAvailable
    }

    var driveMappingReady: Bool {
        guard let preflight else { return false }
        return !preflight.zRewriteRequired || willRewriteModOrganizerIni
    }

    var setupRequest: SetupRequest {
        let modOrganizerPath = manualModOrganizerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let metalFXScaleFactor = dxmtMetalFXScaleFactor.trimmingCharacters(in: .whitespacesAndNewlines)
        let extra = extraWinetricks
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        let fixes = renderer != "dxvk" && applyReticleFix ? ["d3dmetal-reticle"] : []

        return SetupRequest(
            appName: appName.trimmingCharacters(in: .whitespacesAndNewlines),
            outputApp: outputAppPath,
            engine: engine,
            renderer: renderer,
            wineESync: wineESync,
            wineMSync: wineMSync,
            updateUSVFS: updateUSVFS || engine == Self.sikarugir10Engine,
            enableHIDDevices: enableHIDDevices,
            moltenVKFastMath: moltenVKFastMath,
            metalHUD: metalHUD,
            dxmtMetalFXSpatial: renderer == "dxmt" && dxmtMetalFXSpatial,
            dxmtMetalFXScaleFactor: renderer == "dxmt" && dxmtMetalFXSpatial ? metalFXScaleFactor : "",
            dxmtLogLevel: renderer == "dxmt" && dxmtLogLevel != "default" ? dxmtLogLevel : "",
            dxvkHUD: renderer == "dxvk" && metalHUD && dxvkHUD != "default" ? dxvkHUD : "",
            mo2Path: modOrganizerPath,
            driveMappingMode: willRewriteModOrganizerIni ? "shorten" : driveMappingMode,
            extraWinetricks: extra,
            commonFixes: fixes,
            writeLog: saveVerboseLog,
            verbose: saveVerboseLog
        )
    }

    private func windowsPathRelative(_ path: String) -> [String] {
        let separators = CharacterSet(charactersIn: "\\/")
        var value = path
        if value.count >= 2, value[value.index(after: value.startIndex)] == ":" {
            value = String(value.dropFirst(2))
        }
        return value
            .split(whereSeparator: { character in
                character.unicodeScalars.allSatisfy { separators.contains($0) }
            })
            .map(String.init)
    }
}
