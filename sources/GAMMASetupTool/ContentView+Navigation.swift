import SwiftUI

extension ContentView {
    // MARK: - Header

    private var headerText: (title: String, subtitle: String) {
        switch step {
        case .environment:
            return (
                "Check environment",
                "Verify required tools and GAMMA installation before continuing."
            )
        case .setup:
            return (
                "Wrapper settings",
                "Default settings are fine in most cases. Try other options only if you encounter issues."
            )
        case .create:
            return (model.createHeaderTitle, model.createHeaderSubtitle)
        case .complete:
            return ("Installation finished", "Get out of here, Stalker")
        }
    }

    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 7) {
                Text(headerText.title)
                    .font(.title2.weight(.semibold))
                Text(headerText.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(height: Layout.headerContentHeight, alignment: .topLeading)
        .padding(.horizontal, Layout.headerHorizontalPadding)
        .padding(.top, Layout.headerTopPadding)
        .padding(.bottom, Layout.headerBottomPadding)
        .frame(height: Layout.headerHeight, alignment: .topLeading)
        .background(Color(nsColor: .underPageBackgroundColor))
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    var currentStepView: some View {
        switch step {
        case .environment:
            EnvironmentPage(model: model)
        case .setup:
            SetupPage(model: model, showWinetricksList: $showWinetricksList)
        case .create:
            CreatePage(model: model, createButtonSubmitted: $createButtonSubmitted)
        case .complete:
            CompletePage(model: model)
        }
    }

    // MARK: - Footer

    private var footerVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.69"
    }

    var footer: some View {
        HStack(spacing: 12) {
            Text(footerVersion)
                .font(.caption)
                .foregroundStyle(.tertiary)

            footerLinks

            Spacer()

            footerBackButton
            footerPrimaryButton
        }
        .padding(.horizontal, Layout.footerHorizontalPadding)
        .padding(.vertical, Layout.footerVerticalPadding)
        .frame(height: Layout.footerHeight, alignment: .center)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var footerLinks: some View {
        let sourceURL = URL(string: "https://github.com/elseform/gamma-macos-tool")!
        let supportURL = URL(string: "https://discord.com/channels/912320241713958912/1315449108797980762")!

        return HStack(spacing: 10) {
            Text("Source:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link(destination: sourceURL) {
                BrandIcon(resourceName: "github", fallbackSystemName: "chevron.left.forwardslash.chevron.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("GitHub repository")

            Text("Support thread:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link(destination: supportURL) {
                BrandIcon(resourceName: "discord", fallbackSystemName: "bubble.left.and.bubble.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Discord thread")
        }
    }

    @ViewBuilder
    private var footerBackButton: some View {
        if step == .create && !model.isRunning && !createButtonSubmitted {
            Button("Back") {
                if let previous = previousStep {
                    step = previous
                }
            }
            .disabled(previousStep == nil)
        }
    }

    @ViewBuilder
    private var footerPrimaryButton: some View {
        switch step {
        case .environment:
            Button {
                continueFromEnvironment()
            } label: {
                Label("Continue", systemImage: "arrow.right.circle")
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!model.environmentOK || model.isRunning)
        case .setup:
            Button {
                continueToNextStep()
            } label: {
                Label("Confirm settings", systemImage: "arrow.right.circle")
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!canContinue)
        case .create:
            if !model.isRunning && !createButtonSubmitted {
                Button {
                    startCreate()
                } label: {
                    Label(model.primaryButtonTitle, systemImage: "play.circle")
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.isRunning || !model.environmentOK || !model.driveMappingReady)
            }
        case .complete:
            Button {
                model.showCreatedAppAndQuit()
            } label: {
                HStack(spacing: 6) {
                    HazardIcon()
                    Text("Show .app")
                }
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .help("Show wrapper in Finder")
        }
    }

    // MARK: - Navigation State

    private var visibleSteps: [WizardStep] {
        if environmentCompleted && step != .complete {
            return [.setup, .create]
        }
        return []
    }

    private var currentStepIndex: Int? {
        visibleSteps.firstIndex(of: step)
    }

    private var previousStep: WizardStep? {
        guard let index = currentStepIndex, index > 0 else { return nil }
        return visibleSteps[index - 1]
    }

    private var nextStep: WizardStep? {
        guard let index = currentStepIndex, index + 1 < visibleSteps.count else { return nil }
        return visibleSteps[index + 1]
    }

    func maxStep(_ lhs: WizardStep, _ rhs: WizardStep) -> WizardStep {
        lhs.rawValue >= rhs.rawValue ? lhs : rhs
    }

    private var canContinue: Bool {
        if model.isRunning {
            return false
        }
        if step == .environment {
            return model.environmentOK
        }
        if step == .setup {
            return nextStep != nil && model.driveMappingReady
        }
        return nextStep != nil
    }

    private func continueToNextStep() {
        guard let next = nextStep else { return }
        furthestUnlockedStep = next.rawValue > furthestUnlockedStep.rawValue ? next : furthestUnlockedStep
        step = next
    }

    private func continueFromEnvironment() {
        guard model.environmentOK else { return }
        environmentCompleted = true
        furthestUnlockedStep = .setup
        step = .setup
    }

    private func startCreate() {
        createButtonSubmitted = true
        Task {
            let created = await model.create()
            createButtonSubmitted = false
            if created {
                step = .complete
            }
        }
    }
}
