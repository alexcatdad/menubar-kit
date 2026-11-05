import AppKit
import SwiftUI

/// Design tokens: macOS materials and system colours plus one accent.
///
/// The accent is only ever a fill and always carries `ink` text; `accentInk`
/// is the readable variant for accent-coloured text or icons. The default is
/// Scratchpad's amber, the reference look for every app using this package.
public struct MenubarTheme: Sendable {
    public var accent: Color
    public var accentInk: Color
    public var ink: Color

    public init(accent: Color, accentInk: Color, ink: Color = MenubarTheme.defaultInk) {
        self.accent = accent
        self.accentInk = accentInk
        self.ink = ink
    }

    public static let defaultInk = Color(red: 0.102, green: 0.102, blue: 0.102)

    /// Scratchpad amber: the golden-standard accent.
    public static let amber = MenubarTheme(
        accent: Color(
            nsColor: NSColor(name: "menubarKitAmber") { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(srgbRed: 1.0, green: 0.788, blue: 0.235, alpha: 1)
                    : NSColor(srgbRed: 0.949, green: 0.718, blue: 0.02, alpha: 1)
            }),
        accentInk: Color(
            nsColor: NSColor(name: "menubarKitAmberInk") { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(srgbRed: 1.0, green: 0.788, blue: 0.235, alpha: 1)
                    : NSColor(srgbRed: 0.541, green: 0.353, blue: 0, alpha: 1)
            })
    )

    /// The colour reinforcing a tone's symbol.
    public func color(for tone: StatusTone) -> Color {
        switch tone {
        case .ok: .green
        case .warning: .orange
        case .error: .red
        case .off: .secondary
        case .update: accentInk
        }
    }
}

private struct MenubarThemeKey: EnvironmentKey {
    static let defaultValue = MenubarTheme.amber
}

extension EnvironmentValues {
    /// The theme used by MenubarKit views. Defaults to `MenubarTheme.amber`.
    public var menubarTheme: MenubarTheme {
        get { self[MenubarThemeKey.self] }
        set { self[MenubarThemeKey.self] = newValue }
    }
}

extension View {
    /// Sets the MenubarKit theme for this view hierarchy.
    public func menubarTheme(_ theme: MenubarTheme) -> some View {
        environment(\.menubarTheme, theme)
    }
}
