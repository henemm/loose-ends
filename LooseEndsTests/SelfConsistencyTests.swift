import Foundation
import Testing
@testable import LooseEnds

/// Spike #65 Schritt 2 (#108): does agreement across repeated model runs of the same note track
/// whether the answer is actually right? Pure grouping/counting over already-measured values, no
/// model call ([[feedback-phone-is-not-a-test-bench]]) — runs in CI like `MeasurementRunTests`.
@Suite("Selbstkonsistenz über mehrere Läufe (#108)")
struct SelfConsistencyTests {
    @Test("Mehrheitswert und Einstimmigkeit für ein Einzelwert-Feld (AC-5)")
    func majorityAndAgreementForSingleValueField() {
        let values = ["high", "high", "high", "medium", "high"]
        #expect(SelfConsistency.majority(values) == "high")
        #expect(SelfConsistency.agreement(values) == 0.8)
    }

    @Test("Mehrheitswert und Einstimmigkeit für ein Mengenfeld, Reihenfolge ist irrelevant (AC-6)")
    func majorityAndAgreementForSetField() {
        let values: [[String]] = [["a", "b"], ["b", "a"], ["a", "b"], ["a"], ["a", "b"]]
        #expect(SelfConsistency.majoritySet(values) == Set(["a", "b"]))
        #expect(SelfConsistency.agreementSet(values) == 0.8)
    }

    @Test("Die Mehrheitsantwort eines Mengenfelds gilt nur bei exakter Mengengleichheit als richtig (AC-6)")
    func setMajorityMustMatchTruthExactly() {
        let values: [[String]] = [["a", "b"], ["b", "a"], ["a", "b"], ["a"], ["a", "b"]]
        let majority = SelfConsistency.majoritySet(values)
        #expect(majority != Set(["a"]))   // contextsTruth = ["a"]: kein Teiltreffer
    }

    @Test("Die Trefferquote-über-Abdeckung-Tabelle rechnet Abdeckung und Trefferquote je Schwelle (AC-7)")
    func tableComputesCoverageAndHitRate() {
        let outcomes = [
            SelfConsistency.Outcome(agreement: 1.0, correct: true),
            SelfConsistency.Outcome(agreement: 1.0, correct: true),
            SelfConsistency.Outcome(agreement: 0.8, correct: true),
            SelfConsistency.Outcome(agreement: 0.8, correct: false),
            SelfConsistency.Outcome(agreement: 0.4, correct: false),
        ]
        let table = SelfConsistency.table(field: "importance", outcomes: outcomes)
        // Schwelle 0.8: 4 von 5 Sätzen erreichen sie (Abdeckung 80%), davon 3 richtig (Trefferquote 75%).
        #expect(table.contains("| 0.8 | 80% | 75% |"))
        // Schwelle 1.0: 2 von 5 Sätzen (Abdeckung 40%), beide richtig (Trefferquote 100%).
        #expect(table.contains("| 1.0 | 40% | 100% |"))
    }
}
