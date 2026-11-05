import AppKit
import SwiftUI

/// The Settings window layout every app shares: a grouped `Form`, 460pt wide.
///
/// ```swift
/// Settings {
///     SettingsForm {
///         NotificationSettingsSection(notifier: notifier, toggleTitle: "Notify me when a project goes live")
///         Section("Startup") { … }
///         SettingsAboutSection(repository: URL(string: "https://github.com/alexcatdad/app"))
///     }
/// }
/// ```
public struct SettingsForm<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        Form { content }
            .formStyle(.grouped)
            .frame(width: MenubarMetrics.settingsWidth)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension MenubarMetrics {
    /// The Settings window width, in points.
    public static let settingsWidth: CGFloat = 460
}

/// A footnote under a Settings control: secondary, wraps instead of truncating.
public struct SettingsNote: View {
    private let text: AttributedString

    public init(_ text: String) {
        self.text = AttributedString(text)
    }

    public init(_ text: AttributedString) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.footnote).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The standard Notifications section: the opt-in toggle, an optional sound
/// toggle, and a note that follows macOS permission live.
///
/// Turning the toggle on asks macOS for permission (once). While the section
/// is visible it re-reads the permission, so allowing or blocking the app in
/// System Settings updates the note without reopening the window. When macOS
/// blocks the app, a button opens System Settings › Notifications.
public struct NotificationSettingsSection: View {
    private let notifier: MenubarNotifier
    private let title: String
    private let toggleTitle: String
    private let explanation: String?
    private let offersSound: Bool
    @AppStorage private var enabled: Bool
    @AppStorage private var soundEnabled: Bool
    @State private var permission: NotificationPermission?
    @State private var requestError: String?

    /// - Parameters:
    ///   - toggleTitle: What the user opts into, for example "Notify me when a check fails".
    ///   - explanation: Shown under the toggle while nothing needs attention.
    ///   - offersSound: Shows "Play a sound". Notifications are silent otherwise.
    ///   - enabledKey, soundEnabledKey: The `UserDefaults` keys the notifier's preferences read.
    public init(
        notifier: MenubarNotifier,
        title: String = "Notifications",
        toggleTitle: String,
        explanation: String? = nil,
        offersSound: Bool = true,
        enabledKey: String = NotificationPreferences.enabledKey,
        soundEnabledKey: String = NotificationPreferences.soundEnabledKey
    ) {
        self.notifier = notifier
        self.title = title
        self.toggleTitle = toggleTitle
        self.explanation = explanation
        self.offersSound = offersSound
        _enabled = AppStorage(wrappedValue: false, enabledKey)
        _soundEnabled = AppStorage(wrappedValue: false, soundEnabledKey)
    }

    public var body: some View {
        Section(title) {
            Toggle(toggleTitle, isOn: $enabled)
                .onChange(of: enabled) { isOn in
                    if isOn { Task { await request() } }
                }
            if offersSound {
                Toggle("Play a sound", isOn: $soundEnabled).disabled(!enabled)
            }
            if let note = Self.note(
                enabled: enabled, permission: permission, requestError: requestError, explanation: explanation)
            {
                SettingsNote(note)
            }
            if enabled && permission == .denied {
                Button("Open Notification Settings…") { Self.openSystemNotificationSettings() }
            }
        }
        .task {
            for await update in notifier.permissionUpdates() {
                permission = update
                if update != .notDetermined { requestError = nil }
            }
        }
    }

    private func request() async {
        do {
            requestError = nil
            permission = try await notifier.requestPermission()
        } catch PermissionRequestError.alreadyInProgress {
            // The open request will report through permissionUpdates.
        } catch {
            requestError = error.localizedDescription
        }
    }

    /// The note under the toggles, or `nil` for none.
    nonisolated static func note(
        enabled: Bool, permission: NotificationPermission?, requestError: String?, explanation: String?
    ) -> String? {
        guard enabled else { return explanation }
        if let requestError {
            return "macOS could not ask for permission: \(requestError)"
        }
        switch permission {
        case .denied:
            return "Notifications are blocked for this app in System Settings › Notifications."
        case .notDetermined:
            return "macOS will ask for permission to show notifications."
        case .authorized, nil:
            return explanation
        }
    }

    /// Opens System Settings › Notifications.
    @MainActor
    public static func openSystemNotificationSettings() {
        var components = URLComponents()
        components.scheme = "x-apple.systempreferences"
        components.path = "com.apple.Notifications-Settings.extension"
        if let id = Bundle.main.bundleIdentifier {
            components.queryItems = [URLQueryItem(name: "id", value: id)]
        }
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
}

/// The closing About section: version, an optional note and a link to the repository.
public struct SettingsAboutSection: View {
    private let version: String
    private let note: String?
    private let repository: URL?

    /// - Parameters:
    ///   - note: For example what the app never does with the user's data.
    ///   - repository: Shown as "View on GitHub".
    public init(bundle: Bundle = .main, note: String? = nil, repository: URL? = nil) {
        self.version = VersionLabel.of(bundle)
        self.note = note
        self.repository = repository
    }

    public var body: some View {
        Section("About") {
            LabeledContent("Version", value: version)
            if let note { SettingsNote(note) }
            if let repository { Link("View on GitHub", destination: repository) }
        }
    }
}
