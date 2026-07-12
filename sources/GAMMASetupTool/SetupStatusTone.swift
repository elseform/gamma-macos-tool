import Foundation

enum WinetricksWrapperState {
    case planned
}

enum SetupStatusTone: String {
    case success
    case warning
    case error
    case secondary
    case accent

    static func checkRow(ok: Bool, warning: Bool) -> SetupStatusTone {
        ok ? .success : (warning ? .warning : .error)
    }

    static func statusRow(ok: Bool, warning: Bool) -> SetupStatusTone {
        checkRow(ok: ok, warning: warning)
    }

    static func winetricks(_ state: WinetricksWrapperState) -> SetupStatusTone {
        switch state {
        case .planned:
            return .secondary
        }
    }
}
