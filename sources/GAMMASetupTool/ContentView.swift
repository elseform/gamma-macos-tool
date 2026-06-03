import SwiftUI

struct ContentView: View {
    @StateObject var model = AppModel()
    @State var step: WizardStep = .environment
    @State var environmentCompleted = false
    @State var furthestUnlockedStep = WizardStep.setup
    @State var showWinetricksList = false
    @State var createButtonSubmitted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(alignment: .center, spacing: 0) {
                currentStepView
                    .id(step)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            .frame(maxWidth: Layout.contentMaxWidth, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, Layout.contentHorizontalPadding)
            .padding(.vertical, Layout.contentVerticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Divider()
            footer
        }
        .frame(minWidth: Layout.windowWidth, minHeight: Layout.windowHeight)
        .background(WindowMinimumSize(width: Layout.windowWidth, height: Layout.windowHeight))
        .animation(.easeInOut(duration: 0.18), value: step)
        .task {
            guard !isXcodePreview else { return }
            await model.refreshPreflight()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if !model.isRunning {
                    await model.refreshPreflight()
                }
            }
        }
        .onChange(of: model.isRunning) { isRunning in
            if isRunning && !model.isInstallingComponents {
                step = .create
                furthestUnlockedStep = maxStep(furthestUnlockedStep, .create)
            }
        }
    }

    private var isXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

#if DEBUG
#Preview("GAMMA Setup Tool") {
    ContentView()
}
#endif
