import AppKit
import CoreGraphics
import Foundation

struct MacDisplaySettings: Equatable {
    var visibleWidth: Int
    var visibleHeight: Int
    var backingWidth: Int
    var backingHeight: Int
    var scaleFactor: Double
    var localizedName: String

    var isHiDPI: Bool {
        scaleFactor > 1.01 || backingWidth > visibleWidth || backingHeight > visibleHeight
    }

    var summary: String {
        let suffix = isHiDPI ? " HiDPI" : ""
        if backingWidth > 0, backingHeight > 0, backingWidth != visibleWidth || backingHeight != visibleHeight {
            return "\(visibleWidth) x \(visibleHeight)\(suffix) (\(backingWidth) x \(backingHeight) backing)"
        }
        return "\(visibleWidth) x \(visibleHeight)\(suffix)"
    }

    static func detectMainDisplay(screen: NSScreen? = NSScreen.main) -> MacDisplaySettings? {
        guard let screen else { return nil }
        let frame = screen.frame
        let visibleWidth = Int(frame.width.rounded())
        let visibleHeight = Int(frame.height.rounded())
        let scale = screen.backingScaleFactor
        var backingWidth = Int((frame.width * scale).rounded())
        var backingHeight = Int((frame.height * scale).rounded())

        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
           let mode = CGDisplayCopyDisplayMode(CGDirectDisplayID(screenNumber.uint32Value)) {
            backingWidth = mode.pixelWidth
            backingHeight = mode.pixelHeight
        }

        return MacDisplaySettings(
            visibleWidth: visibleWidth,
            visibleHeight: visibleHeight,
            backingWidth: backingWidth,
            backingHeight: backingHeight,
            scaleFactor: scale,
            localizedName: screen.localizedName
        )
    }
}
