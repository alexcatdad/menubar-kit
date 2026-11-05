import Foundation
import UserNotifications
import os

/// A notification to post through `MenubarNotifier`.
public struct MenubarNotification: Equatable, Sendable {
    public var title: String
    /// A secondary line under the title, for example "owner/repo #42".
    public var subtitle: String?
    public var body: String
    /// Groups related notifications in Notification Center, for example one thread per incident kind.
    public var threadIdentifier: String?
    /// Reusing an identifier replaces the earlier notification instead of stacking a new one.
    public var identifier: String
    /// Returned to the click handler (`NotificationClick.userInfo`), for example a URL or record ID to open.
    public var userInfo: [String: String]

    public init(
        title: String,
        subtitle: String? = nil,
        body: String,
        threadIdentifier: String? = nil,
        identifier: String = UUID().uuidString,
        userInfo: [String: String] = [:]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.threadIdentifier = threadIdentifier
        self.identifier = identifier
        self.userInfo = userInfo
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

    /// The calling task was cancelled before anything was posted. Compare with
    /// `==` or match with `case .cancelled:`.
    public static let cancelled = DeliveryOutcome.failed("cancelled")
}

/// Why `MenubarNotifier.requestPermission()` did not return a permission.
public enum PermissionRequestError: Error, Equatable, Sendable {
    /// Another permission request from this notifier has not finished yet.
    case alreadyInProgress
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
        let content = Self.content(for: notification, playSound: playSound)
        let request = UNNotificationRequest(identifier: notification.identifier, content: content, trigger: nil)
        try await UNUserNotificationCenter.current().add(request)
    }

    /// The content posted for `notification`. Silent unless `playSound` is true.
    public static func content(for notification: MenubarNotification, playSound: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        if let subtitle = notification.subtitle {
            content.subtitle = subtitle
        }
        content.body = notification.body
        if let thread = notification.threadIdentifier {
            content.threadIdentifier = thread
        }
        content.userInfo = notification.userInfo
        content.sound = playSound ? .default : nil
        return content
    }
}

/// Opt-in, attributed, quiet-by-default notifications.
///
/// - Off until the user turns the app's toggle on (`NotificationPreferences.enabled`).
/// - Permission is requested only from that toggle, via `userEnabledNotifications()`.
/// - Every delivery re-reads the preferences and re-checks macOS permission,
///   so revoking either takes effect immediately.
/// - One permission request at a time; a cancelled delivery posts nothing.
/// - Silent unless `NotificationPreferences.soundEnabled` is true.
public final class MenubarNotifier: Sendable {
    private let center: any NotificationCenterClient
    private let preferences: @Sendable () -> NotificationPreferences
    private let requestGate = OSAllocatedUnfairLock(initialState: false)

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
    ///
    /// A failed request reads as `.denied` and a request made while another is
    /// still open reads as the current permission. Use `requestPermission()`
    /// to see either case.
    public func userEnabledNotifications() async -> NotificationPermission {
        do {
            return try await requestPermission()
        } catch PermissionRequestError.alreadyInProgress {
            return await permission()
        } catch {
            return .denied
        }
    }

    /// Like `userEnabledNotifications()`, but reports failures instead of
    /// collapsing them to `.denied`.
    ///
    /// - Throws: `PermissionRequestError.alreadyInProgress` while another
    ///   request from this notifier is open (macOS shows one prompt; a second
    ///   call would race it), or the error macOS returned for the request.
    public func requestPermission() async throws -> NotificationPermission {
        let current = await permission()
        guard current == .notDetermined else { return current }
        guard
            requestGate.withLock({ inFlight in
                if inFlight { return false }
                inFlight = true
                return true
            })
        else { throw PermissionRequestError.alreadyInProgress }
        defer { requestGate.withLock { $0 = false } }
        return try await center.requestAuthorization() ? .authorized : .denied
    }

    /// Whether a permission request from this notifier is open.
    public var isRequestingPermission: Bool {
        requestGate.withLock { $0 }
    }

    /// The current permission now, then again each time it changes, for
    /// example after the user changes it in System Settings. macOS has no
    /// change callback, so this re-reads it every `interval`. Iterate it in a
    /// view's `.task` so polling stops when the view goes away.
    public func permissionUpdates(every interval: Duration = .seconds(2)) -> AsyncStream<NotificationPermission> {
        AsyncStream { continuation in
            let task = Task {
                var last: NotificationPermission?
                while !Task.isCancelled {
                    let current = await permission()
                    if current != last {
                        last = current
                        continuation.yield(current)
                    }
                    try? await Task.sleep(for: interval)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Posts `notification` if the user enabled notifications and macOS still allows them.
    /// Returns `.cancelled` without posting if the calling task is cancelled,
    /// including while the permission check is in flight.
    @discardableResult
    public func deliver(_ notification: MenubarNotification) async -> DeliveryOutcome {
        guard !Task.isCancelled else { return .cancelled }
        let prefs = preferences()
        guard prefs.enabled else { return .disabled }
        guard await permission() == .authorized else { return .notAuthorized }
        guard !Task.isCancelled else { return .cancelled }
        do {
            try await center.add(notification, playSound: prefs.soundEnabled)
            return .delivered
        } catch {
            return .failed(String(describing: error))
        }
    }
}
