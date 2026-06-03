import SwiftUI
import AppKit

struct WindowMinimumSize: NSViewRepresentable {
    let width: CGFloat
    let height: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.minSize = NSSize(width: width, height: height)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.minSize = NSSize(width: width, height: height)
        }
    }
}

enum Layout {
    static let windowWidth: CGFloat = 820
    static let windowHeight: CGFloat = 520
    static let contentMaxWidth: CGFloat = 1000
    static let contentHorizontalPadding: CGFloat = 30
    static let contentVerticalPadding: CGFloat = 16
    static let headerHorizontalPadding: CGFloat = 28
    static let headerVerticalPadding: CGFloat = 15
    static let headerContentMinHeight: CGFloat = 74
    static let footerHorizontalPadding: CGFloat = 28
    static let footerVerticalPadding: CGFloat = 12
    static let environmentPanelWidth: CGFloat = 820
    static let environmentPanelHorizontalPadding: CGFloat = 4
    static let environmentPanelVerticalPadding: CGFloat = 2
    static let setupContentWidth: CGFloat = 740
    static let setupColumnSpacing: CGFloat = 18
    static let setupLeftColumnWidth: CGFloat = 360
    static let setupPanelHorizontalPadding: CGFloat = 12
    static let setupPanelVerticalPadding: CGFloat = 8
    static let winetricksPanelVerticalPadding: CGFloat = 8
    static let completeMaxWidth: CGFloat = 740

    static var setupRightColumnWidth: CGFloat {
        setupContentWidth - setupLeftColumnWidth - setupColumnSpacing
    }
}
