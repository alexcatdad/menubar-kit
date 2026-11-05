import AppKit
import SwiftUI

/// The `MenuBarExtra` label every app uses.
///
/// - The glyph never changes: the 18pt template image, or `fallbackSymbol`
///   when the image could not be loaded.
/// - When the tone is not `.ok`, a heavy 9pt `exclamationmark` badge follows
///   the glyph, so attention is a visible mark, not just a colour change. The
///   badge is drawn into the same template image (see `TrayIconComposer`)
///   because `MenuBarExtra` drops any second image in its label.
/// - Development builds show a "DEV" caption.
/// - VoiceOver reads one element: "<App>, <status word>".
public struct TrayLabel: View {
    private let icon: NSImage?
    private let fallbackSymbol: String
    private let tone: StatusTone
    private let statusWord: String
    private let appName: String
    private let isDevelopment: Bool

    /// - Parameters:
    ///   - icon: From `TrayIconLoader.load`. `nil` shows `fallbackSymbol`.
    ///   - fallbackSymbol: SF Symbol shown when `icon` is `nil`.
    ///   - tone: The current status tone; anything but `.ok` adds the badge.
    ///   - statusWord: Spoken after the app name. Defaults to `tone.defaultWord`.
    ///   - appName: The app's display name, without any DEV suffix.
    ///   - isDevelopment: Adds the "DEV" caption and speaks "<App> DEV".
    public init(
        icon: NSImage?,
        fallbackSymbol: String,
        tone: StatusTone,
        statusWord: String? = nil,
        appName: String,
        isDevelopment: Bool = false
    ) {
        self.icon = icon
        self.fallbackSymbol = fallbackSymbol
        self.tone = tone
        self.statusWord = statusWord ?? tone.defaultWord
        self.appName = appName
        self.isDevelopment = isDevelopment
    }

    /// Convenience for apps that already hold a `MenubarStatus`.
    public init(
        icon: NSImage?, fallbackSymbol: String, status: MenubarStatus, appName: String, isDevelopment: Bool = false
    ) {
        self.init(
            icon: icon, fallbackSymbol: fallbackSymbol, tone: status.tone, statusWord: status.word,
            appName: appName, isDevelopment: isDevelopment)
    }

    public var body: some View {
        // MenuBarExtra shows only one image from its label, so the badge is
        // composited into the glyph's template image instead of laid out beside it.
        HStack(spacing: 3) {
            Image(nsImage: TrayIconComposer.image(icon: icon, fallbackSymbol: fallbackSymbol, tone: tone))
                .renderingMode(.template)
            if isDevelopment {
                Text("DEV").font(.caption2.weight(.semibold))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            TrayAccessibility.label(
                appName: isDevelopment ? "\(appName) DEV" : appName,
                statusWord: statusWord
            ))
    }
}
