import SwiftUI

extension ContentView {
    var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(headerTitle)
                        .font(.title2.weight(.semibold))
                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if step == .environment {
                        HStack(spacing: 4) {
                            Text("Visit")
                                .foregroundStyle(.secondary)
                            Link(destination: URL(string: "https://github.com/FaithBeam/stalker-gamma-cli")!) {
                                HStack(spacing: 4) {
                                    BrandIcon(resourceName: "github", fallbackSystemName: "chevron.left.forwardslash.chevron.right")
                                        .frame(width: 13, height: 13)
                                    Text("stalker-gamma-cli")
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.primary)
                            .help("Visit stalker-gamma-cli on GitHub")
                            Text("for installation details.")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
                Spacer()
            }
        }
        .frame(minHeight: Layout.headerContentMinHeight, alignment: .topLeading)
        .padding(.horizontal, Layout.headerHorizontalPadding)
        .padding(.vertical, Layout.headerVerticalPadding)
        .background(Color(nsColor: .underPageBackgroundColor))
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    var headerTitle: String {
        switch step {
        case .environment:
            return "Check environment"
        case .setup:
            return "Wrapper settings"
        case .create:
            return model.createHeaderTitle
        case .complete:
            return "Installation finished"
        }
    }

    var headerSubtitle: String {
        switch step {
        case .environment:
            return "Verify required tools and GAMMA installation before continuing."
        case .setup:
            return "Default settings are fine in most cases. Try other options only if you encounter issues."
        case .create:
            return model.createHeaderSubtitle
        case .complete:
            return "Get out of here, Stalker"
        }
    }

    @ViewBuilder
    var currentStepView: some View {
        switch step {
        case .environment:
            environmentStep
        case .setup:
            setupStep
        case .create:
            createStep
        case .complete:
            completeStep
        }
    }

    var footer: some View {
        HStack(spacing: 12) {
            Text("0.67")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if step != .environment && step != .setup && step != .complete {
                Button("Back") {
                    if let previous = previousStep {
                        step = previous
                    }
                }
                .disabled(previousStep == nil || model.isRunning)
            }

            Spacer()

            footerLinks
        }
        .padding(.horizontal, Layout.footerHorizontalPadding)
        .padding(.vertical, Layout.footerVerticalPadding)
    }

    var footerLinks: some View {
        HStack(spacing: 10) {
            Text("Source:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link(destination: URL(string: "https://github.com/elseform/gamma-macos-tool")!) {
                BrandIcon(resourceName: "github", fallbackSystemName: "chevron.left.forwardslash.chevron.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("GitHub repository")

            Text("Support thread:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link(destination: URL(string: "https://discord.com/channels/912320241713958912/1315449108797980762")!) {
                BrandIcon(resourceName: "discord", fallbackSystemName: "bubble.left.and.bubble.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Discord thread")
        }
    }

    var visibleSteps: [WizardStep] {
        if environmentCompleted && step != .complete {
            return [.setup, .create]
        }
        return []
    }

    var currentStepIndex: Int? {
        visibleSteps.firstIndex(of: step)
    }

    var previousStep: WizardStep? {
        guard let index = currentStepIndex, index > 0 else { return nil }
        return visibleSteps[index - 1]
    }

    var nextStep: WizardStep? {
        guard let index = currentStepIndex, index + 1 < visibleSteps.count else { return nil }
        return visibleSteps[index + 1]
    }

    func maxStep(_ lhs: WizardStep, _ rhs: WizardStep) -> WizardStep {
        lhs.rawValue >= rhs.rawValue ? lhs : rhs
    }

    var canContinue: Bool {
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

    func continueToNextStep() {
        guard let next = nextStep else { return }
        furthestUnlockedStep = next.rawValue > furthestUnlockedStep.rawValue ? next : furthestUnlockedStep
        step = next
    }
}
