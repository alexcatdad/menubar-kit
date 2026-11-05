import Foundation
import Testing
import UserNotifications

@testable import MenubarKit

private struct PromptFailed: Error, Equatable {}

/// A center whose permission request and status read can be held open, so tests
/// can act while either is in flight.
private actor HeldCenter: NotificationCenterClient {
    var status: UNAuthorizationStatus
    var failRequest = false
    var holdRequest = false
    var holdStatus = false
    private(set) var requests = 0
    private(set) var posted: [MenubarNotification] = []
    private var heldRequest: CheckedContinuation<Void, Never>?
    private var heldStatus: CheckedContinuation<Void, Never>?

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func configure(failRequest: Bool = false, holdRequest: Bool = false, holdStatus: Bool = false) {
        self.failRequest = failRequest
        self.holdRequest = holdRequest
        self.holdStatus = holdStatus
    }

    func setStatus(_ value: UNAuthorizationStatus) { status = value }

    var isHoldingRequest: Bool { heldRequest != nil }
    var isHoldingStatus: Bool { heldStatus != nil }

    func releaseRequest() {
        heldRequest?.resume()
        heldRequest = nil
    }

    func releaseStatus() {
        heldStatus?.resume()
        heldStatus = nil
    }

    func requestAuthorization() async throws -> Bool {
        requests += 1
        if holdRequest {
            await withCheckedContinuation { heldRequest = $0 }
        }
        if failRequest { throw PromptFailed() }
        status = .authorized
        return true
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        if holdStatus {
            holdStatus = false
            await withCheckedContinuation { heldStatus = $0 }
        }
        return status
    }

    func add(_ notification: MenubarNotification, playSound: Bool) async throws {
        posted.append(notification)
    }
}

private let sample = MenubarNotification(title: "Device connected", body: "SanDisk Extreme")

/// Polls `condition` until it holds, so tests wait for a task to reach a held call.
private func eventually(_ condition: @Sendable () async -> Bool) async throws {
    for _ in 0..<500 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(2))
    }
    Issue.record("condition never held")
}

@Test func requestPermissionKeepsTheError() async {
    let center = HeldCenter(status: .notDetermined)
    await center.configure(failRequest: true)
    let notifier = MenubarNotifier(center: center, preferences: { NotificationPreferences(enabled: true) })

    await #expect(throws: PromptFailed.self) { try await notifier.requestPermission() }
    // The existing API still collapses the failure for apps that only show a state.
    #expect(await notifier.userEnabledNotifications() == .denied)
}

@Test func requestPermissionReturnsWithoutPromptingOnceDecided() async throws {
    let center = HeldCenter(status: .denied)
    let notifier = MenubarNotifier(center: center, preferences: { NotificationPreferences(enabled: true) })
    #expect(try await notifier.requestPermission() == .denied)
    #expect(await center.requests == 0)
}

@Test func concurrentPermissionRequestsAreRefused() async throws {
    let center = HeldCenter(status: .notDetermined)
    await center.configure(holdRequest: true)
    let notifier = MenubarNotifier(center: center, preferences: { NotificationPreferences(enabled: true) })

    let first = Task { try await notifier.requestPermission() }
    try await eventually { await center.isHoldingRequest }
    #expect(notifier.isRequestingPermission)

    await #expect(throws: PermissionRequestError.alreadyInProgress) { try await notifier.requestPermission() }
    // The toggle API reports the current permission instead of a second prompt.
    #expect(await notifier.userEnabledNotifications() == .notDetermined)

    await center.releaseRequest()
    #expect(try await first.value == .authorized)
    #expect(await center.requests == 1)
    #expect(!notifier.isRequestingPermission)
}

@Test func failedRequestReleasesTheGate() async throws {
    let center = HeldCenter(status: .notDetermined)
    await center.configure(failRequest: true)
    let notifier = MenubarNotifier(center: center, preferences: { NotificationPreferences(enabled: true) })
    _ = try? await notifier.requestPermission()
    #expect(!notifier.isRequestingPermission)
    await center.configure(failRequest: false)
    #expect(try await notifier.requestPermission() == .authorized)
}

@Test func cancelledDeliveryPostsNothing() async {
    let center = HeldCenter(status: .authorized)
    let notifier = MenubarNotifier(center: center, preferences: { NotificationPreferences(enabled: true) })
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return await notifier.deliver(sample)
    }
    #expect(await task.value == .cancelled)
    #expect(await center.posted.isEmpty)
}

@Test func cancellationDuringThePermissionCheckPostsNothing() async throws {
    let center = HeldCenter(status: .authorized)
    await center.configure(holdStatus: true)
    let notifier = MenubarNotifier(center: center, preferences: { NotificationPreferences(enabled: true) })

    let task = Task { await notifier.deliver(sample) }
    try await eventually { await center.isHoldingStatus }
    task.cancel()
    await center.releaseStatus()

    let outcome = await task.value
    #expect(outcome == .cancelled)
    switch outcome {
    case .cancelled: break
    default: Issue.record("expected .cancelled to match as a pattern")
    }
    #expect(await center.posted.isEmpty)
}

@Test func permissionUpdatesReportChangesOnly() async throws {
    let center = HeldCenter(status: .notDetermined)
    let notifier = MenubarNotifier(center: center, preferences: { NotificationPreferences() })
    var updates = notifier.permissionUpdates(every: .milliseconds(5)).makeAsyncIterator()

    #expect(await updates.next() == .notDetermined)
    await center.setStatus(.authorized)
    #expect(await updates.next() == .authorized)
    await center.setStatus(.provisional)  // Still .authorized: not reported again.
    await center.setStatus(.denied)
    #expect(await updates.next() == .denied)
}
