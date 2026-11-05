import Foundation

/// A change worth one notification.
public enum IncidentTransition<Key: Hashable & Sendable>: Equatable, Sendable {
    /// The condition has held past its delay and has not been reported yet.
    case incident(Key)
    /// A reported incident has cleared.
    case recovered(Key)
}

/// Coalesces repeated observations of a condition into one incident and one recovery.
///
/// Feed every poll result to `observe(_:isActive:at:)`. A condition is
/// reported once it has been continuously active for longer than its delay,
/// then never again until it clears; it reports recovery only if the incident
/// was reported. Observations that are inconclusive (for example a stale
/// probe) should simply not be passed in.
///
/// Persist `reportedIncidents` and pass it back to `init` to keep
/// de-duplication across relaunches.
public struct IncidentDeduplicator<Key: Hashable & Sendable>: Sendable {
    private var activeSince: [Key: Date] = [:]
    private var reported: Set<Key>
    private let defaultDelay: TimeInterval
    private let delays: [Key: TimeInterval]

    /// - Parameters:
    ///   - delay: How long a condition must hold before it is reported. 0 reports on the first active observation.
    ///   - delays: Per-key overrides, for example 60s for a network outage but 0 for a storage failure.
    ///   - reportedIncidents: Incidents already reported before a relaunch.
    public init(delay: TimeInterval = 0, delays: [Key: TimeInterval] = [:], reportedIncidents: Set<Key> = []) {
        defaultDelay = delay
        self.delays = delays
        reported = reportedIncidents
    }

    /// Incidents reported and not yet recovered. Persist this across relaunches.
    public var reportedIncidents: Set<Key> { reported }

    public func isReported(_ key: Key) -> Bool { reported.contains(key) }

    /// Records one observation of `key` and returns the transition to notify about, if any.
    public mutating func observe(_ key: Key, isActive: Bool, at now: Date = .now) -> IncidentTransition<Key>? {
        if isActive {
            let since = activeSince[key] ?? now
            activeSince[key] = since
            guard !reported.contains(key) else { return nil }
            let delay = delays[key] ?? defaultDelay
            guard delay <= 0 || now.timeIntervalSince(since) > delay else { return nil }
            reported.insert(key)
            return .incident(key)
        }
        activeSince[key] = nil
        guard reported.remove(key) != nil else { return nil }
        return .recovered(key)
    }

    /// Forgets `key` without reporting recovery, for example after the user
    /// deliberately stopped the thing that was failing.
    public mutating func reset(_ key: Key) {
        activeSince[key] = nil
        reported.remove(key)
    }
}
