import Foundation
import UserNotifications

/// What the user clicked: the posted notification's identity and `userInfo`.
public struct NotificationClick: Equatable, Sendable {
    public var identifier: String
    public var threadIdentifier: String?
    public var userInfo: [String: String]
    /// `UNNotificationDefaultActionIdentifier` for a plain click on the banner.
    public var actionIdentifier: String

    public init(
        identifier: String,
        threadIdentifier: String? = nil,
        userInfo: [String: String] = [:],
        actionIdentifier: String = UNNotificationDefaultActionIdentifier
    ) {
        self.identifier = identifier
        self.threadIdentifier = threadIdentifier
        self.userInfo = userInfo
        self.actionIdentifier = actionIdentifier
    }

    /// Whether the user dismissed the notification rather than opening it.
    public var isDismissal: Bool { actionIdentifier == UNNotificationDismissActionIdentifier }

    /// Keeps the string pairs of a raw `userInfo`, which is all `MenubarNotification` posts.
    public static func stringUserInfo(_ raw: [AnyHashable: Any]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in raw {
            if let key = key as? String, let value = value as? String {
                result[key] = value
            }
        }
        return result
    }
}

/// The app's `UNUserNotificationCenterDelegate`, opted into explicitly.
///
/// Create one early (in `applicationDidFinishLaunching` or the `App` init),
/// keep a strong reference (the center holds its delegate weakly), and call
/// `install()`. Clicks are delivered to `onClick` on the main actor.
///
/// Notifications that arrive while the app is frontmost are not shown unless
/// `presentInForeground` is true. Menu bar apps are rarely frontmost, so the
/// default (off) only matters while a settings or main window has focus.
public final class MenubarNotificationResponder: NSObject, UNUserNotificationCenterDelegate, Sendable {
    /// Whether notifications are shown while the app is active. Off by default.
    public let presentInForeground: Bool
    private let onClick: @MainActor @Sendable (NotificationClick) -> Void

    public init(
        presentInForeground: Bool = false,
        onClick: @escaping @MainActor @Sendable (NotificationClick) -> Void
    ) {
        self.presentInForeground = presentInForeground
        self.onClick = onClick
    }

    /// Makes this responder the current `UNUserNotificationCenter` delegate.
    public func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// The options used for a notification that arrives while the app is active.
    /// Sound still only plays if the notification itself carries one.
    public var foregroundPresentationOptions: UNNotificationPresentationOptions {
        presentInForeground ? [.banner, .list, .sound] : []
    }

    /// Hands a click to `onClick`. Exposed so apps can route clicks from tests or other sources.
    @MainActor
    public func handle(_ click: NotificationClick) {
        onClick(click)
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        foregroundPresentationOptions
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let request = response.notification.request
        let thread = request.content.threadIdentifier
        let click = NotificationClick(
            identifier: request.identifier,
            threadIdentifier: thread.isEmpty ? nil : thread,
            userInfo: NotificationClick.stringUserInfo(request.content.userInfo),
            actionIdentifier: response.actionIdentifier
        )
        await handle(click)
    }
}
