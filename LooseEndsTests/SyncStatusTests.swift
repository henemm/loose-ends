import Foundation
import Testing
@testable import LooseEnds

/// The settings row "iCloud sync" (#377): the Mac shows other tasks than iPhone and iPad, and nothing in the
/// app said whether it mirrors at all. The rule behind the row is pure: events in, state out, state in,
/// symbol and role out. No test here talks to CloudKit.
@Suite("SyncStatus (#377)") @MainActor struct SyncStatusTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func event(_ kind: SyncStatus.Kind, ended: Date?, error: String? = nil) -> SyncStatus.Event {
        SyncStatus.Event(kind: kind, endDate: ended, errorMessage: error)
    }

    @Test("A fresh status is waiting")
    func startsWaiting() {
        #expect(SyncStatus().state == .waiting)
    }

    @Test("A finished event without error makes the state alive, with its kind and time")
    func successfulEventBecomesAlive() {
        for kind in [SyncStatus.Kind.setup, .imported, .exported] {
            let state = SyncStatus.reduce(.waiting, event: event(kind, ended: t0))
            #expect(state == .alive(kind, at: t0))
        }
    }

    @Test("A failed event shows the error, a later success replaces it")
    func failedEventBecomesFailed() {
        let failed = SyncStatus.reduce(.alive(.imported, at: t0), event: event(.exported, ended: t0 + 5, error: "CKError 6"))
        #expect(failed == .failed(message: "CKError 6", at: t0 + 5))
        let healed = SyncStatus.reduce(failed, event: event(.imported, ended: t0 + 9))
        #expect(healed == .alive(.imported, at: t0 + 9))
    }

    @Test("An event still running changes nothing")
    func unfinishedEventChangesNothing() {
        let states: [SyncStatus.State] = [.waiting, .alive(.exported, at: t0), .failed(message: "x", at: t0)]
        for state in states {
            #expect(SyncStatus.reduce(state, event: event(.imported, ended: nil)) == state)
        }
    }

    @Test("After a fall back to the local store no event changes the state, for either reason")
    func localOnlyIsFinal() {
        for reason in [SyncStatus.FallbackReason.appGroupMissing, .containerFailed] {
            let status = SyncStatus()
            status.fellBack(reason: reason)
            #expect(status.state == .localOnly(reason))
            status.apply(event(.imported, ended: t0))
            status.apply(event(.exported, ended: t0, error: "boom"))
            #expect(status.state == .localOnly(reason))
        }
    }

    @Test("Each state has its sign and role; only alive is accent")
    func summaryPerState() {
        let cases: [(SyncStatus.State, SyncStatus.Headline, String, SyncStatus.Role)] = [
            (.waiting, .waiting, "icloud", .secondary),
            (.alive(.imported, at: t0), .active, "checkmark.icloud", .accent),
            (.failed(message: "CKError 6", at: t0), .disturbed, "exclamationmark.icloud", .secondary),
            (.localOnly(.appGroupMissing), .localOnly, "icloud.slash", .secondary),
            (.localOnly(.containerFailed), .localOnly, "icloud.slash", .secondary),
        ]
        for (state, headline, symbol, role) in cases {
            let summary = SyncStatus.summary(for: state, now: t0)
            #expect(summary.headline == headline)
            #expect(summary.symbol == symbol)
            #expect(summary.role == role)
        }
        #expect(SyncStatus.summary(for: .failed(message: "CKError 6", at: t0), now: t0).detail == "CKError 6")
        #expect(SyncStatus.summary(for: .alive(.exported, at: t0), now: t0).activity == .exported)
    }

    @Test("The age counts whole minutes; a time in the future (clock drift) counts as 0")
    func ageInMinutes() {
        func age(_ seconds: TimeInterval) -> Int? {
            SyncStatus.summary(for: .alive(.imported, at: t0), now: t0 + seconds).ageMinutes
        }
        #expect(age(0) == 0)
        #expect(age(59) == 0)
        #expect(age(120) == 2)
        #expect(age(7_500) == 125)
        #expect(age(-300) == 0)
        #expect(SyncStatus.summary(for: .waiting, now: t0).ageMinutes == nil)
    }

    @Test("No state uses red: the role is accent or secondary, nothing else exists")
    func noRedAnywhere() {
        let states: [SyncStatus.State] = [
            .waiting, .alive(.setup, at: t0), .failed(message: "x", at: t0),
            .localOnly(.appGroupMissing), .localOnly(.containerFailed),
        ]
        for state in states {
            let role = SyncStatus.summary(for: state, now: t0).role
            #expect(role == .accent || role == .secondary)
        }
        #expect(SyncStatus.Role.allCases.count == 2)
    }
}
