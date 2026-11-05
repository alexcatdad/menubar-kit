import Foundation
import Testing

@testable import MenubarKit

private enum Incident: Hashable, Sendable { case outage, storage, blocked }
private let start = Date(timeIntervalSince1970: 1_800_000_000)

@Test func immediateIncidentReportsOnceAndRecoversOnce() {
    var tracker = IncidentDeduplicator<Incident>()
    #expect(tracker.observe(.storage, isActive: true, at: start) == .incident(.storage))
    #expect(tracker.observe(.storage, isActive: true, at: start) == nil)
    #expect(tracker.observe(.storage, isActive: false, at: start) == .recovered(.storage))
    #expect(tracker.observe(.storage, isActive: false, at: start) == nil)
}

@Test func healthyObservationsNeverReport() {
    var tracker = IncidentDeduplicator<Incident>()
    #expect(tracker.observe(.storage, isActive: false) == nil)
}

@Test func delayedIncidentWaitsPastThreshold() {
    var tracker = IncidentDeduplicator<Incident>(delays: [.outage: 60])
    #expect(tracker.observe(.outage, isActive: true, at: start) == nil)
    #expect(tracker.observe(.outage, isActive: true, at: start.addingTimeInterval(60)) == nil)
    #expect(tracker.observe(.outage, isActive: true, at: start.addingTimeInterval(61)) == .incident(.outage))
    #expect(tracker.observe(.outage, isActive: false, at: start.addingTimeInterval(90)) == .recovered(.outage))
}

@Test func shortBlipBelowThresholdReportsNothing() {
    var tracker = IncidentDeduplicator<Incident>(delay: 60)
    #expect(tracker.observe(.outage, isActive: true, at: start) == nil)
    #expect(tracker.observe(.outage, isActive: false, at: start.addingTimeInterval(30)) == nil)
    // The clock restarts after the blip.
    #expect(tracker.observe(.outage, isActive: true, at: start.addingTimeInterval(40)) == nil)
    #expect(tracker.observe(.outage, isActive: true, at: start.addingTimeInterval(95)) == nil)
    #expect(tracker.observe(.outage, isActive: true, at: start.addingTimeInterval(101)) == .incident(.outage))
}

@Test func keysAreIndependent() {
    var tracker = IncidentDeduplicator<Incident>(delay: 0, delays: [.outage: 60])
    #expect(tracker.observe(.outage, isActive: true, at: start) == nil)
    #expect(tracker.observe(.blocked, isActive: true, at: start) == .incident(.blocked))
    #expect(tracker.reportedIncidents == [.blocked])
}

@Test func deduplicationSurvivesRelaunch() {
    var first = IncidentDeduplicator<Incident>()
    #expect(first.observe(.storage, isActive: true) == .incident(.storage))

    var relaunched = IncidentDeduplicator<Incident>(reportedIncidents: first.reportedIncidents)
    #expect(relaunched.isReported(.storage))
    #expect(relaunched.observe(.storage, isActive: true) == nil)
    #expect(relaunched.observe(.storage, isActive: false) == .recovered(.storage))
    #expect(relaunched.reportedIncidents.isEmpty)
}

@Test func resetForgetsWithoutClaimingRecovery() {
    var tracker = IncidentDeduplicator<Incident>()
    #expect(tracker.observe(.storage, isActive: true) == .incident(.storage))
    tracker.reset(.storage)
    #expect(tracker.observe(.storage, isActive: false) == nil)
}
