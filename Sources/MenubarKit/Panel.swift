import AppKit
import SwiftUI

/// Fixed sizes shared by every app.
public enum MenubarMetrics {
    /// The panel width, in points.
    public static let panelWidth: CGFloat = 340
    /// The tray glyph size, in points.
    public static let trayIconSize: CGFloat = 18
}

/// The popover container for `MenuBarExtra(...).menuBarExtraStyle(.window)`:
/// 340pt wide, 12pt padding, 10pt spacing between sections.
public struct MenubarPanel<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(12)
        .frame(width: MenubarMetrics.panelWidth)
    }
}

/// A tone symbol: its shape carries the meaning, colour only reinforces it.
/// Hidden from VoiceOver; the surrounding text carries the words.
public struct StatusIcon: View {
    @Environment(\.menubarTheme) private var theme
    private let tone: StatusTone
    private let size: CGFloat
    private let weight: Font.Weight

    public init(tone: StatusTone, size: CGFloat = 13, weight: Font.Weight = .semibold) {
        self.tone = tone
        self.size = size
        self.weight = weight
    }

    public var body: some View {
        Image(systemName: tone.symbol)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(theme.color(for: tone))
            .accessibilityHidden(true)
    }
}

/// The panel's top section: 30pt tone symbol, headline and detail.
/// Read by VoiceOver as one element.
public struct StatusHeader: View {
    private let tone: StatusTone
    private let headline: String
    private let detail: String

    public init(tone: StatusTone, headline: String, detail: String) {
        self.tone = tone
        self.headline = headline
        self.detail = detail
    }

    /// - Parameter detailOverride: Shown instead of `status.detail`, for example a running activity.
    public init(_ status: MenubarStatus, detailOverride: String? = nil) {
        self.init(tone: status.tone, headline: status.headline, detail: detailOverride ?? status.detail)
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            StatusIcon(tone: tone, size: 30, weight: .regular)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline).font(.headline)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 4)
    }
}

/// One title/value line inside a `.groupedTile()`, with a tone symbol.
public struct StatusRowView: View {
    private let row: MenubarStatusRow

    public init(_ row: MenubarStatusRow) {
        self.row = row
    }

    public var body: some View {
        HStack(spacing: 8) {
            StatusIcon(tone: row.tone)
            Text(row.title)
            Spacer()
            Text(row.value).foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .frame(minHeight: 28)
        .accessibilityElement(children: .combine)
    }
}

/// A grouped tile of status rows.
public struct StatusRowsTile: View {
    private let rows: [MenubarStatusRow]

    public init(_ rows: [MenubarStatusRow]) {
        self.rows = rows
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { StatusRowView($0) }
        }
        .groupedTile()
    }
}

/// A tile section header: a secondary title and an optional link button.
public struct TileHeader: View {
    private let title: String
    private let linkTitle: String?
    private let action: (() -> Void)?

    public init(_ title: String, linkTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.linkTitle = linkTitle
        self.action = action
    }

    public var body: some View {
        HStack {
            Text(title).font(.callout.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
            if let linkTitle, let action {
                Button(linkTitle, action: action).buttonStyle(.link).font(.callout)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

extension View {
    /// The rounded tile that groups rows in the panel.
    public func groupedTile() -> some View {
        padding(.vertical, 4)
            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Primary actions: an accent capsule with ink text.
public struct ProminentButtonStyle: ButtonStyle {
    private let fullWidth: Bool

    public init(fullWidth: Bool = false) {
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        ProminentButtonBody(configuration: configuration, fullWidth: fullWidth)
    }
}

private struct ProminentButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let fullWidth: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.menubarTheme) private var theme

    var body: some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 28)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Capsule().fill(theme.accent.opacity(configuration.isPressed ? 0.8 : 1)))
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Capsule())
    }
}

/// A full-width menu row in the panel, highlighted on hover and press.
public struct MenuRowButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        MenuRowBody(configuration: configuration)
    }
}

private struct MenuRowBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovering = false

    var body: some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.primary.opacity(configuration.isPressed ? 0.12 : hovering ? 0.07 : 0))
            )
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}

/// The panel's menu section: rows in `MenuRowButtonStyle`, with a divider
/// and a Quit row at the end.
public struct MenuSection<Content: View>: View {
    private let quitTitle: String?
    private let quitHelp: String?
    private let content: Content

    /// - Parameters:
    ///   - quitTitle: For example "Quit Scratchpad". `nil` omits the divider and Quit row.
    ///   - quitHelp: Tooltip for the Quit row, for example what keeps running after quitting.
    public init(quitTitle: String? = nil, quitHelp: String? = nil, @ViewBuilder content: () -> Content) {
        self.quitTitle = quitTitle
        self.quitHelp = quitHelp
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
            if let quitTitle {
                Divider().padding(.vertical, 4).padding(.horizontal, 10)
                Button(quitTitle) { NSApp.terminate(nil) }
                    .help(quitHelp ?? "")
            }
        }
        .buttonStyle(MenuRowButtonStyle())
    }
}

/// The full-width primary action under the status rows.
public struct PrimaryActionButton: View {
    private let title: String
    private let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(title, action: action)
            .buttonStyle(ProminentButtonStyle(fullWidth: true))
    }
}

/// A secondary inline message, for example the last error.
public struct PanelNotice: View {
    private let message: String
    private let symbol: String

    public init(_ message: String, symbol: String = "exclamationmark.triangle") {
        self.message = message
        self.symbol = symbol
    }

    public var body: some View {
        Label(message, systemImage: symbol)
            .font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// "Version 1.2.3 (45)" at the bottom of the panel.
public struct VersionFooter: View {
    private let label: String

    public init(version: String?, build: String?) {
        label = VersionLabel.format(version: version, build: build)
    }

    /// Reads the version from `bundle`'s Info.plist.
    public init(bundle: Bundle = .main) {
        label = VersionLabel.of(bundle)
    }

    public var body: some View {
        Text("Version \(label)")
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 10)
    }
}
