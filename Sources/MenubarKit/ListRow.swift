import SwiftUI

/// A clickable two-line row for lists in the panel (for example routes,
/// devices or pull requests): optional leading icon, a title, a secondary
/// subtitle and an optional trailing value, highlighted on hover and press.
///
/// Put rows in a `VStack(spacing: 0)` inside `.groupedTile()`. VoiceOver reads
/// a row as one button: "title, subtitle, value".
public struct ListRowButton: View {
    private let title: String
    private let subtitle: String?
    private let value: String?
    private let leading: Leading?
    private let action: () -> Void

    private enum Leading {
        case tone(StatusTone)
        case symbol(String)
    }

    /// - Parameters:
    ///   - subtitle: Second line, truncated in the middle so both ends of a URL or path stay visible.
    ///   - tone: Leading tone symbol.
    ///   - value: Trailing secondary text, for example a port or a count.
    public init(
        _ title: String, subtitle: String? = nil, tone: StatusTone? = nil, value: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.leading = tone.map(Leading.tone)
        self.action = action
    }

    /// A row with an SF Symbol in place of a tone symbol.
    public init(
        _ title: String, subtitle: String? = nil, systemImage: String, value: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.leading = .symbol(systemImage)
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                switch leading {
                case .tone(let tone): StatusIcon(tone: tone)
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                        .accessibilityHidden(true)
                case nil: EmptyView()
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout).lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
                Spacer(minLength: 8)
                if let value {
                    Text(value).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .buttonStyle(ListRowButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.accessibilityLabel(title: title, subtitle: subtitle, value: value))
    }

    nonisolated static func accessibilityLabel(title: String, subtitle: String?, value: String?) -> String {
        [title, subtitle, value].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// The hover and press highlight `ListRowButton` uses, inset inside a grouped tile.
public struct ListRowButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        ListRowBody(configuration: configuration)
    }
}

private struct ListRowBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.primary.opacity(configuration.isPressed ? 0.12 : hovering && isEnabled ? 0.07 : 0))
            )
            .padding(.horizontal, 4)
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}
