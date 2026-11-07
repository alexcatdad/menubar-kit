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

/// Formats an app version for the panel footer and About section.
///
/// The apps release with four-part CalVer tags (`2026.11.06.2`). Bundle
/// versions allow only three parts, so builds pack the date (`2026.1106.2`).
/// People see the release tag: `ReleaseVersion` from Info.plist when present,
/// otherwise the packed bundle version unpacked again. The build number is
/// shown only when it adds information.
public enum VersionLabel {
    public static func format(version: String?, build: String?) -> String {
        let version = (version?.isEmpty == false ? version : nil) ?? "unknown"
        guard let build, !build.isEmpty, build != version else { return version }
        return "\(version) (\(build))"
    }

    /// The release version people see: `releaseVersion` when set, else the
    /// unpacked CalVer bundle version, else `format(version:build:)`.
    public static func release(releaseVersion: String?, shortVersion: String?, build: String?) -> String {
        if let releaseVersion, !releaseVersion.isEmpty { return releaseVersion }
        if let shortVersion, let unpacked = unpackedCalVer(shortVersion) {
            let redundant = build == nil || build?.isEmpty == true || build == shortVersion
            return redundant ? unpacked : format(version: unpacked, build: build)
        }
        return format(version: shortVersion, build: build)
    }

    /// `2026.1106.2` → `2026.11.06.2`; nil for anything that is not a packed
    /// CalVer version (year, month and day, build).
    public static func unpackedCalVer(_ packed: String) -> String? {
        let parts = packed.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCII) && Int($0) != nil }),
            parts[0].count == 4, (3...4).contains(parts[1].count),
            let monthDay = Int(parts[1])
        else { return nil }
        let month = monthDay / 100, day = monthDay % 100
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        return String(format: "%@.%02d.%02d.%@", parts[0], month, day, parts[2])
    }

    /// The version label of `bundle`: `ReleaseVersion`, `CFBundleShortVersionString`
    /// and `CFBundleVersion` through `release(releaseVersion:shortVersion:build:)`.
    public static func of(_ bundle: Bundle) -> String {
        release(
            releaseVersion: bundle.object(forInfoDictionaryKey: "ReleaseVersion") as? String,
            shortVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
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
