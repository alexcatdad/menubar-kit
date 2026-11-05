import Foundation
import Testing
import UserNotifications

@testable import MenubarKit

private actor FakeCenter: NotificationCenterClient {
    var status: UNAuthorizationStatus
    var grant: Bool
    private(set) var requests = 0
    private(set) var posted: [(MenubarNotification, Bool)] = []

    init(status: UNAuthorizationStatus, grant: Bool = true) {
        self.status = status
        self.grant = grant
    }

    func setStatus(_ value: UNAuthorizationStatus) { status = value }

    func requestAuthorization() async throws -> Bool {
        requests += 1
        status = grant ? .authorized : .denied
        return grant
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func add(_ notification: MenubarNotification, playSound: Bool) async throws {
        posted.append((notification, playSound))
    }
}

private final class Prefs: @unchecked Sendable {
    private let lock = NSLock()
    private var value: NotificationPreferences
    init(_ value: NotificationPreferences) { self.value = value }
    func get() -> NotificationPreferences { lock.withLock { value } }
    func set(_ newValue: NotificationPreferences) { lock.withLock { value = newValue } }
}

private let sample = MenubarNotification(
    title: "Server offline", body: "Captures are queued.", threadIdentifier: "outage")

@Test func preferencesDefaultToOff() {
    #expect(NotificationPreferences() == NotificationPreferences(enabled: false, soundEnabled: false))
}

@Test func nothingIsPostedOrRequestedWhileToggleIsOff() async {
    let center = FakeCenter(status: .notDetermined)
    let notifier = MenubarNotifier(center: center, preferences: { NotificationPreferences() })
    #expect(await notifier.deliver(sample) == .disabled)
    #expect(await center.requests == 0)
    #expect(await center.posted.isEmpty)
}

@Test func permissionIsRequestedOnlyFromTheToggleAndOnlyOnce() async {
    let center = FakeCenter(status: .notDetermined)
    let notifier = MenubarNotifier(center: center, preferences: { NotificationPreferences(enabled: true) })
    #expect(await notifier.permission() == .notDetermined)
    #expect(await notifier.deliver(sample) == .notAuthorized)
    #expect(await center.requests == 0)

    #expect(await notifier.userEnabledNotifications() == .authorized)
    #expect(await notifier.userEnabledNotifications() == .authorized)
    #expect(await center.requests == 1)
}

@Test func deniedPromptReportsDenied() async {
    let center = FakeCenter(status: .notDetermined, grant: false)
    let notifier = MenubarNotifier(center: center, preferences: { NotificationPreferences(enabled: true) })
    #expect(await notifier.userEnabledNotifications() == .denied)
}

@Test func deliveryIsSilentByDefaultAndKeepsThread() async throws {
    let center = FakeCenter(status: .authorized)
    let notifier = MenubarNotifier(center: center, preferences: { NotificationPreferences(enabled: true) })
    #expect(await notifier.deliver(sample) == .delivered)
    let posted = try #require(await center.posted.first)
    #expect(posted.0 == sample)
    #expect(posted.0.threadIdentifier == "outage")
    #expect(posted.1 == false)
}

@Test func soundPlaysOnlyWhenEnabled() async throws {
    let center = FakeCenter(status: .authorized)
    let notifier = MenubarNotifier(
        center: center, preferences: { NotificationPreferences(enabled: true, soundEnabled: true) })
    #expect(await notifier.deliver(sample) == .delivered)
    #expect(try #require(await center.posted.first).1 == true)
}

@Test func deliveryRechecksPermissionAndPreferencesEachTime() async {
    let center = FakeCenter(status: .authorized)
    let prefs = Prefs(NotificationPreferences(enabled: true))
    let notifier = MenubarNotifier(center: center, preferences: { prefs.get() })
    #expect(await notifier.deliver(sample) == .delivered)

    await center.setStatus(.denied)
    #expect(await notifier.deliver(sample) == .notAuthorized)

    await center.setStatus(.authorized)
    prefs.set(NotificationPreferences(enabled: false))
    #expect(await notifier.deliver(sample) == .disabled)
    #expect(await center.posted.count == 1)
}

@Test func permissionMapping() {
    #expect(NotificationPermission(.provisional) == .authorized)
    #expect(NotificationPermission(.denied) == .denied)
    #expect(NotificationPermission(.notDetermined) == .notDetermined)
}

@Test func subtitleAndUserInfoReachTheContent() {
    let notification = MenubarNotification(
        title: "Review requested", subtitle: "owner/repo #42", body: "Fix the thing",
        threadIdentifier: "PR_1", identifier: "n1", userInfo: ["url": "https://example.com/pr/42"])
    let content = SystemNotificationCenter.content(for: notification, playSound: false)
    #expect(content.title == "Review requested")
    #expect(content.subtitle == "owner/repo #42")
    #expect(content.body == "Fix the thing")
    #expect(content.threadIdentifier == "PR_1")
    #expect(content.userInfo as? [String: String] == ["url": "https://example.com/pr/42"])
    #expect(content.sound == nil)
    #expect(SystemNotificationCenter.content(for: notification, playSound: true).sound != nil)
}

@Test func existingInitializerStillCompilesWithEmptyExtras() {
    let notification = MenubarNotification(title: "t", body: "b", threadIdentifier: "x", identifier: "i")
    #expect(notification.subtitle == nil)
    #expect(notification.userInfo.isEmpty)
    #expect(SystemNotificationCenter.content(for: notification, playSound: false).subtitle == "")
}

@Test func foregroundPresentationIsOffByDefault() {
    let quiet = MenubarNotificationResponder { _ in }
    #expect(quiet.foregroundPresentationOptions.isEmpty)
    let loud = MenubarNotificationResponder(presentInForeground: true) { _ in }
    #expect(loud.foregroundPresentationOptions.contains(.banner))
    #expect(loud.foregroundPresentationOptions.contains(.list))
}

@MainActor
@Test func clicksReachTheHandlerWithUserInfo() {
    var received: [NotificationClick] = []
    let responder = MenubarNotificationResponder { received.append($0) }
    let click = NotificationClick(identifier: "n1", threadIdentifier: "PR_1", userInfo: ["url": "u"])
    responder.handle(click)
    #expect(received == [click])
    #expect(!click.isDismissal)
}

@Test func clickUserInfoKeepsOnlyStrings() {
    let raw: [AnyHashable: Any] = ["url": "u", "count": 3, 7: "x"]
    #expect(NotificationClick.stringUserInfo(raw) == ["url": "u"])
}
