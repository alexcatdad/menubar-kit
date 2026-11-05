import Foundation

/// The five states every menu bar app reports.
///
/// Each tone has its own SF Symbol shape, so meaning never depends on colour
/// alone. Colour (see `StatusTone.color`) only reinforces the shape.
public enum StatusTone: String, CaseIterable, Equatable, Hashable, Sendable {
    case ok, warning, error, off, update

    /// The SF Symbol for this tone. Every tone uses a different shape.
    public var symbol: String {
        switch self {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        case .off: "stop.circle.fill"
        case .update: "arrow.up.circle.fill"
        }
    }

    /// Whether the tray glyph carries the attention badge. Everything but `.ok` does.
    public var needsAttention: Bool { self != .ok }

    /// A generic status word, used when the app does not supply its own.
    public var defaultWord: String {
        switch self {
        case .ok: "Running"
        case .warning: "Needs attention"
        case .error: "Error"
        case .off: "Off"
        case .update: "Update available"
        }
    }
}

/// One description of an app's state, shared by the tray label and the panel
/// header so every surface uses the same words.
public struct MenubarStatus: Equatable, Hashable, Sendable {
    public var tone: StatusTone
    /// The short status word, used in the tray's VoiceOver label ("<App>, <word>").
    public var word: String
    public var headline: String
    public var detail: String

    public init(tone: StatusTone, word: String? = nil, headline: String, detail: String = "") {
        self.tone = tone
        self.word = word ?? tone.defaultWord
        self.headline = headline
        self.detail = detail
    }
}

/// One title/value line in a grouped tile, with its own tone symbol.
public struct MenubarStatusRow: Equatable, Hashable, Sendable, Identifiable {
    public var title: String
    public var value: String
    public var tone: StatusTone

    public var id: String { title }

    public init(title: String, value: String, tone: StatusTone) {
        self.title = title
        self.value = value
        self.tone = tone
    }
}

/// Formats an app version for the panel footer: `1.2.3` or `1.2.3 (45)`.
/// The build number is omitted when missing, empty or equal to the version.
public enum VersionLabel {
    public static func format(version: String?, build: String?) -> String {
        let version = (version?.isEmpty == false ? version : nil) ?? "unknown"
        guard let build, !build.isEmpty, build != version else { return version }
        return "\(version) (\(build))"
    }

    /// The version label of `bundle` from `CFBundleShortVersionString` and `CFBundleVersion`.
    public static func of(_ bundle: Bundle) -> String {
        format(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }
}

/// The text VoiceOver reads for a tray item: "<App>, <status word>".
public enum TrayAccessibility {
    public static func label(appName: String, statusWord: String) -> String {
        "\(appName), \(statusWord)"
    }
}
