import Foundation
import UserNotifications

/// A notification to post through `MenubarNotifier`.
public struct MenubarNotification: Equatable, Sendable {
    public var title: String
    public var body: String
    /// Groups related notifications in Notification Center, for example one thread per incident kind.
    public var threadIdentifier: String?
    /// Reusing an identifier replaces the earlier notification instead of stacking a new one.
    public var identifier: String

    public init(title: String, body: String, threadIdentifier: String? = nil, identifier: String = UUID().uuidString) {
        self.title = title
        self.body = body
        self.threadIdentifier = threadIdentifier
        self.identifier = identifier
    }
}

/// macOS notification permission, collapsed to what the UI shows.
public enum NotificationPermission: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied

    public init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .authorized, .provisional, .ephemeral: self = .authorized
        case .denied: self = .denied
        @unknown default: self = .denied
        }
    }
}

/// The app's own notification settings. Both default to off.
public struct NotificationPreferences: Equatable, Sendable {
    /// The user's "Notify me" toggle. Nothing is ever posted while this is false.
    public var enabled: Bool
    /// Plays the default sound. Notifications are silent unless the app offers and enables this.
    public var soundEnabled: Bool

    public init(enabled: Bool = false, soundEnabled: Bool = false) {
        self.enabled = enabled
        self.soundEnabled = soundEnabled
    }

    /// Default `UserDefaults` keys. Bind `@AppStorage` toggles to the same keys.
    public static let enabledKey = "menubarKit.notificationsEnabled"
    public static let soundEnabledKey = "menubarKit.notificationSoundEnabled"

    /// Reads preferences from `UserDefaults.standard`; missing keys read as `false`.
    public static func standard(
        enabledKey: String = enabledKey,
        soundEnabledKey: String = soundEnabledKey
    ) -> NotificationPreferences {
        let defaults = UserDefaults.standard
        return NotificationPreferences(
            enabled: defaults.bool(forKey: enabledKey),
            soundEnabled: defaults.bool(forKey: soundEnabledKey)
        )
    }
}

/// The result of `MenubarNotifier.deliver`.
public enum DeliveryOutcome: Equatable, Sendable {
    case delivered
    /// The user's toggle is off.
    case disabled
    /// macOS permission is missing or was revoked since the toggle was turned on.
    case notAuthorized
    case failed(String)
}

/// The system calls `MenubarNotifier` needs. Production uses
/// `SystemNotificationCenter`; tests inject a fake, because
/// `UNUserNotificationCenter` needs a real app bundle.
public protocol NotificationCenterClient: Sendable {
    func requestAuthorization() async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func add(_ notification: MenubarNotification, playSound: Bool) async throws
}

/// `UNUserNotificationCenter.current()`. Notifications are attributed to the
/// calling app bundle; there is no osascript or shell fallback.
public struct SystemNotificationCenter: NotificationCenterClient {
    public init() {}

    /// Requests `[.alert, .sound]` only. No badge, no provisional delivery.
    public func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    public func add(_ notification: MenubarNotification, playSound: Bool) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        if let thread = notification.threadIdentifier {
            content.threadIdentifier = thread
        }
        content.sound = playSound ? .default : nil
        let request = UNNotificationRequest(identifier: notification.identifier, content: content, trigger: nil)
        try await UNUserNotificationCenter.current().add(request)
    }
}

/// Opt-in, attributed, quiet-by-default notifications.
///
/// - Off until the user turns the app's toggle on (`NotificationPreferences.enabled`).
/// - Permission is requested only from that toggle, via `userEnabledNotifications()`.
/// - Every delivery re-reads the preferences and re-checks macOS permission,
///   so revoking either takes effect immediately.
/// - Silent unless `NotificationPreferences.soundEnabled` is true.
public final class MenubarNotifier: Sendable {
    private let center: any NotificationCenterClient
    private let preferences: @Sendable () -> NotificationPreferences

    /// - Parameters:
    ///   - center: Defaults to `SystemNotificationCenter()`.
    ///   - preferences: Read on every delivery. Defaults to `NotificationPreferences.standard()`.
    public init(
        center: any NotificationCenterClient = SystemNotificationCenter(),
        preferences: @escaping @Sendable () -> NotificationPreferences = { NotificationPreferences.standard() }
    ) {
        self.center = center
        self.preferences = preferences
    }

    /// The current macOS permission, without prompting.
    public func permission() async -> NotificationPermission {
        NotificationPermission(await center.authorizationStatus())
    }

    /// Call from the user's toggle when it is turned on. Prompts for
    /// `[.alert, .sound]` if macOS has not asked yet, then reports the result.
    /// When the toggle is turned off, call `permission()` instead.
    public func userEnabledNotifications() async -> NotificationPermission {
        let current = await permission()
        guard current == .notDetermined else { return current }
        do {
            return try await center.requestAuthorization() ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    /// Posts `notification` if the user enabled notifications and macOS still allows them.
    @discardableResult
    public func deliver(_ notification: MenubarNotification) async -> DeliveryOutcome {
        let prefs = preferences()
        guard prefs.enabled else { return .disabled }
        guard await permission() == .authorized else { return .notAuthorized }
        do {
            try await center.add(notification, playSound: prefs.soundEnabled)
            return .delivered
        } catch {
            return .failed(String(describing: error))
        }
    }
}
