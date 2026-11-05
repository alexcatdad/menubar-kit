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
