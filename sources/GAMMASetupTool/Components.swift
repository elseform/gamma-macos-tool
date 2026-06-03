import SwiftUI
import AppKit

struct StatusRow: View {
    let label: String
    let value: String
    let ok: Bool
    var warning = false
    var help: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let help {
                    HelpTip(text: help)
                }
            }
            Text(value.isEmpty ? "Not detected" : value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(SetupStatusTone.statusRow(ok: ok, warning: warning).color)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct HelpTip: View {
    let text: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(text)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            Text(text)
                .font(.body)
                .frame(width: 280, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
        }
    }
}

struct WarningTip: View {
    let text: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
        }
        .buttonStyle(.plain)
        .help(text)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            Text(text)
                .font(.body)
                .frame(width: 300, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
        }
    }
}

struct SectionTitle: View {
    let title: String
    let help: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.title2.weight(.semibold))
            HelpTip(text: help)
            Spacer(minLength: 0)
        }
    }
}

struct BrandIcon: View {
    let resourceName: String
    let fallbackSystemName: String

    var body: some View {
        if let url = AppResources.bundle.url(forResource: resourceName, withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        } else if let url = Bundle.main.url(forResource: resourceName, withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: fallbackSystemName)
                .frame(width: 16, height: 16)
        }
    }
}

struct HazardIcon: View {
    var body: some View {
        Text("☢")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 16, height: 16)
    }
}

enum WizardStep: Int, CaseIterable, Identifiable {
    case environment
    case setup
    case create
    case complete

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .environment: return "Environment"
        case .setup: return "Setup"
        case .create: return "Create"
        case .complete: return "Complete"
        }
    }

    var icon: String {
        switch self {
        case .environment: return "checkmark.shield"
        case .setup: return "slider.horizontal.3"
        case .create: return "play.circle"
        case .complete: return "checkmark.circle"
        }
    }

    var previous: WizardStep? {
        WizardStep(rawValue: rawValue - 1)
    }

    var next: WizardStep? {
        WizardStep(rawValue: rawValue + 1)
    }
}

struct CheckRow<Action: View>: View {
    let label: String
    let status: String
    let ok: Bool
    var warning = false
    var detail: String?
    var prominent = false
    @ViewBuilder var action: () -> Action

    init(
        label: String,
        status: String,
        ok: Bool,
        warning: Bool = false,
        detail: String? = nil,
        prominent: Bool = false,
        @ViewBuilder action: @escaping () -> Action
    ) {
        self.label = label
        self.status = status
        self.ok = ok
        self.warning = warning
        self.detail = detail
        self.prominent = prominent
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: ok ? "checkmark.circle.fill" : (warning ? "exclamationmark.triangle.fill" : "xmark.circle.fill"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(SetupStatusTone.checkRow(ok: ok, warning: warning).color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.title3.weight(.semibold))
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 12)

            Text(status)
                .font(.callout.weight(.semibold))
                .foregroundStyle(SetupStatusTone.checkRow(ok: ok, warning: warning).color)
                .frame(width: 96, alignment: .trailing)

            action()
                .frame(width: 150, height: 28, alignment: .trailing)
        }
        .padding(.vertical, 11)
        .frame(minHeight: 50)
    }
}

extension CheckRow where Action == EmptyView {
    init(
        label: String,
        status: String,
        ok: Bool,
        warning: Bool = false,
        detail: String? = nil,
        prominent: Bool = false
    ) {
        self.init(label: label, status: status, ok: ok, warning: warning, detail: detail, prominent: prominent) {
            EmptyView()
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }
}

struct SetupSummaryRow: View {
    let item: SetupSummaryItem

    var body: some View {
        GridRow {
            HStack(spacing: 5) {
                Text(item.label)
                    .font(.body)
                    .foregroundStyle(.secondary)
                if item.changed {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .help("This value will be updated.")
                }
            }
            Text(item.displayValue)
                .font(.body)
                .foregroundStyle(item.changed ? .yellow : .primary)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }
}
