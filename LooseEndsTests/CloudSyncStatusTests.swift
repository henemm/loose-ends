import CoreData
import Foundation
import Testing
@testable import LooseEnds

/// The iCloud line in the Settings (#377): the device says whether its mirroring ever ran, runs,
/// failed or is fine — instead of looking the same in every case.
@Suite("CloudKit mirroring summary") struct CloudSyncStatusTests {
    static let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    static func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    @Test("Without any event the device never contacted iCloud")
    func neverContacted() {
        #expect(CloudSyncSummary().state == .neverContacted)
    }

    @Test("A running event shows as running, whatever ran before")
    func running() {
        var summary = CloudSyncSummary()
        summary.record(CloudSyncEvent(kind: .setup, startedAt: Self.at(0), endedAt: Self.at(1), error: nil))
        summary.record(CloudSyncEvent(kind: .import, startedAt: Self.at(2), endedAt: nil, error: nil))
        #expect(summary.state == .running(.import))
    }

    @Test("A failed event wins over earlier successes and names its error")
    func failed() {
        var summary = CloudSyncSummary()
        summary.record(CloudSyncEvent(kind: .setup, startedAt: Self.at(0), endedAt: Self.at(1), error: nil))
        summary.record(CloudSyncEvent(kind: .export, startedAt: Self.at(2), endedAt: Self.at(3), error: "CKError 6"))
        #expect(summary.state == .failed(.export, "CKError 6"))
    }

    @Test("All ended well: ok with the most recent end")
    func ok() {
        var summary = CloudSyncSummary()
        summary.record(CloudSyncEvent(kind: .setup, startedAt: Self.at(0), endedAt: Self.at(1), error: nil))
        summary.record(CloudSyncEvent(kind: .import, startedAt: Self.at(2), endedAt: Self.at(5), error: nil))
        summary.record(CloudSyncEvent(kind: .export, startedAt: Self.at(3), endedAt: Self.at(4), error: nil))
        #expect(summary.state == .ok(Self.at(5)))
        #expect(summary.latest(.import)?.endedAt == Self.at(5))
    }

    @Test("The newest event per kind replaces the older one, never the other way round")
    func newestPerKind() {
        var summary = CloudSyncSummary()
        summary.record(CloudSyncEvent(kind: .import, startedAt: Self.at(10), endedAt: Self.at(11), error: nil))
        summary.record(CloudSyncEvent(kind: .import, startedAt: Self.at(5), endedAt: Self.at(6), error: "late delivery"))
        #expect(summary.latest(.import)?.startedAt == Self.at(10))
        #expect(summary.state == .ok(Self.at(11)))
    }

    @Test("Core Data event types map onto the three kinds")
    func mapping() {
        let setup = CloudSyncEvent(type: .setup, startedAt: Self.at(0), endedAt: nil, error: nil)
        let imp = CloudSyncEvent(type: .import, startedAt: Self.at(0), endedAt: Self.at(1), error: nil)
        let exp = CloudSyncEvent(type: .export, startedAt: Self.at(0), endedAt: Self.at(1), error: Failure())
        #expect(setup?.kind == .setup && setup?.isRunning == true)
        #expect(imp?.kind == .import && imp?.failed == false)
        #expect(exp?.kind == .export && exp?.failed == true && exp?.error?.isEmpty == false)
    }

    @Test("The collector records what it is handed")
    @MainActor func collector() {
        let status = CloudSyncStatus()
        status.record(CloudSyncEvent(kind: .setup, startedAt: Self.at(0), endedAt: Self.at(1), error: nil))
        #expect(status.summary.state == .ok(Self.at(1)))
    }

    private struct Failure: Error {}
}
