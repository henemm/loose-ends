import Foundation
import Testing
@testable import LooseEnds

@Suite("Onboarding (#29)") struct OnboardingFlowTests {
    /// A suite of its own per test, so no test reads or writes the real defaults.
    private func freshDefaults() throws -> UserDefaults {
        let name = "OnboardingFlowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Three steps in order: Siri, notifications, contexts; then it is over")
    func stepsInOrder() {
        var flow = OnboardingFlow()
        #expect(flow.step == .siri)
        #expect(!flow.isLastStep)
        #expect(flow.advance())
        #expect(flow.step == .notifications)
        #expect(flow.advance())
        #expect(flow.step == .contexts)
        #expect(flow.isLastStep)
        #expect(!flow.advance(), "after the last step the caller finishes")
        #expect(flow.step == .contexts)
    }

    @Test("Shown on a fresh device, never again once finished or skipped")
    func shownOnce() throws {
        let defaults = try freshDefaults()
        #expect(OnboardingFlow.shouldShow(defaults: defaults, arguments: []))
        #expect(!OnboardingFlow.isDone(defaults: defaults))

        OnboardingFlow.finish(defaults: defaults)

        #expect(!OnboardingFlow.shouldShow(defaults: defaults, arguments: []))
        #expect(OnboardingFlow.isDone(defaults: defaults))
    }

    @Test("UI tests start on the start screen unless they ask for the onboarding")
    func uiTestArguments() throws {
        let defaults = try freshDefaults()
        #expect(!OnboardingFlow.shouldShow(defaults: defaults, arguments: ["--ui-testing"]))
        #expect(OnboardingFlow.shouldShow(defaults: defaults, arguments: ["--ui-testing", OnboardingFlow.uiTestArgument]))

        OnboardingFlow.finish(defaults: defaults)
        #expect(OnboardingFlow.shouldShow(defaults: defaults, arguments: ["--ui-testing", OnboardingFlow.uiTestArgument]),
                "the onboarding test runs whatever an earlier run left behind")
    }

    @Test("The model note follows the reason the system gives; none while the model is there")
    func modelNote() {
        #expect(OnboardingFlow.modelNote(for: nil) == nil)
        #expect(OnboardingFlow.modelNote(for: "appleIntelligenceNotEnabled") == .turnedOff)
        #expect(OnboardingFlow.modelNote(for: "modelNotReady") == .notReady)
        #expect(OnboardingFlow.modelNote(for: "deviceNotEligible") == .notEligible)
        #expect(OnboardingFlow.modelNote(for: "somethingNew") == .notEligible, "an unknown reason still says the model is missing")
    }
}
