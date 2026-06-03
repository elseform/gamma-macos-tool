import SwiftUI

extension SetupStatusTone {
    var color: Color {
        switch self {
        case .success:
            return .green
        case .warning:
            return .yellow
        case .error:
            return .red
        case .secondary:
            return .secondary
        case .accent:
            return .blue
        }
    }
}
