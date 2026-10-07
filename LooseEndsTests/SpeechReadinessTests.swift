import Foundation
import Speech
import Testing
@testable import LooseEnds

/// What the capture scene shows before it listens (#64): honest about the on-device model,
/// never a download without a tap.
@Suite("Speech readiness (#64)") struct SpeechReadinessTests {
    @Test("Each model status maps to what the capture scene shows")
    func mapping() {
        #expect(SpeechReadiness.from(.unsupported) == .unsupported)
        #expect(SpeechReadiness.from(.supported) == .needsModel)
        #expect(SpeechReadiness.from(.downloading) == .loading)
        #expect(SpeechReadiness.from(.installed) == .ready)
    }

    @Test("Progress is 0...1 and never NaN")
    func fraction() {
        #expect(SpeechReadiness.fraction(completed: 0, total: 0) == 0)
        #expect(SpeechReadiness.fraction(completed: 5, total: 0) == 0)
        #expect(SpeechReadiness.fraction(completed: 50, total: 100) == 0.5)
        #expect(SpeechReadiness.fraction(completed: 120, total: 100) == 1)
        #expect(SpeechReadiness.fraction(completed: -1, total: 100) == 0)
    }

    @Test("Progress is read from Foundation's Progress")
    func fromProgress() {
        let progress = Progress(totalUnitCount: 4)
        progress.completedUnitCount = 1
        #expect(SpeechReadiness.fraction(progress) == 0.25)
    }
}
