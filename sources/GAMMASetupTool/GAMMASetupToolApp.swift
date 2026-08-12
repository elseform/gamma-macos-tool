import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct GAMMASetupToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("GAMMA Setup Tool") {
            ContentView()
        }
        .defaultSize(width: Layout.windowDefaultWidth, height: Layout.windowDefaultHeight)
    }
}
