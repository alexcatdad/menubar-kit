import AppKit
import SwiftUI

/// Opens the app's SwiftUI `Settings` scene from a menu bar (LSUIElement) app.
///
/// An accessory app is not active when its panel is clicked, so the Settings
/// window would open behind other apps. These helpers activate the app first,
/// open the scene (`openSettings` on macOS 14+, `showSettingsWindow:` on 13),
/// then bring the Settings window to the front.
public enum SettingsOpener {
    /// Activates the app so the next window it opens comes to the front.
    @MainActor
    public static func activateApp() {
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Opens Settings on macOS 13 via the responder chain. On macOS 14 and
    /// later use `OpenSettingsButton` instead, because SwiftUI no longer
    /// handles `showSettingsWindow:` there.
    @MainActor
    public static func openLegacy() {
        activateApp()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        bringSettingsWindowForward()
    }

    /// Orders the Settings window front on the next run loop turn, once SwiftUI has created it.
    @MainActor
    public static func bringSettingsWindowForward() {
        DispatchQueue.main.async {
            let window = NSApp.windows.first { window in
                window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
                    || window.frameAutosaveName == "com_apple_SwiftUI_Settings_window"
            }
            window?.makeKeyAndOrderFront(nil)
            activateApp()
        }
    }
}

/// A button that opens the Settings scene and brings it to the front,
/// on macOS 13 and later. Style it like any button, for example inside a
/// `MenuSection` it picks up `MenuRowButtonStyle`.
public struct OpenSettingsButton: View {
    private let title: String

    public init(_ title: String = "Settings…") {
        self.title = title
    }

    public var body: some View {
        if #available(macOS 14, *) {
            ModernOpenSettingsButton(title: title)
        } else {
            Button(title) { SettingsOpener.openLegacy() }
        }
    }
}

@available(macOS 14, *)
private struct ModernOpenSettingsButton: View {
    let title: String
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(title) {
            SettingsOpener.activateApp()
            openSettings()
            SettingsOpener.bringSettingsWindowForward()
        }
    }
}
