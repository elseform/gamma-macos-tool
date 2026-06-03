import SwiftUI
import AppKit

struct WindowMinimumSize: NSViewRepresentable {
    let width: CGFloat
    let height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            applySizing(to: view.window, context: context)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            applySizing(to: view.window, context: context)
        }
    }

    private func applySizing(to window: NSWindow?, context: Context) {
        guard let window else { return }
        let size = NSSize(width: width, height: height)
        window.minSize = size
        guard !context.coordinator.appliedInitialSize else { return }
        context.coordinator.appliedInitialSize = true
        window.setContentSize(size)
    }

    final class Coordinator {
        var appliedInitialSize = false
    }
}

enum Layout {
    static let windowWidth: CGFloat = 820
    static let windowHeight: CGFloat = 440
    static let contentMaxWidth: CGFloat = 1000
    static let contentHorizontalPadding: CGFloat = 30
    static let contentVerticalPadding: CGFloat = 12
    static let headerHorizontalPadding: CGFloat = 28
    static let headerTopPadding: CGFloat = 12
    static let headerBottomPadding: CGFloat = 12
    static let headerContentMinHeight: CGFloat = 0
    static let footerHorizontalPadding: CGFloat = 28
    static let footerVerticalPadding: CGFloat = 10
    static let wizardContentWidth: CGFloat = 740
    static let environmentPanelWidth: CGFloat = wizardContentWidth
    static let environmentPanelHorizontalPadding: CGFloat = 4
    static let environmentPanelVerticalPadding: CGFloat = 2
    static let setupContentWidth: CGFloat = wizardContentWidth
    static let setupColumnSpacing: CGFloat = 18
    static let setupLeftColumnWidth: CGFloat = 360
    static let setupPanelHorizontalPadding: CGFloat = 12
    static let setupPanelVerticalPadding: CGFloat = 8
    static let cardContentSpacing: CGFloat = 8
    static let winetricksPanelVerticalPadding: CGFloat = 8
    static let completeMaxWidth: CGFloat = wizardContentWidth

    static var setupRightColumnWidth: CGFloat {
        setupContentWidth - setupLeftColumnWidth - setupColumnSpacing
    }
}
