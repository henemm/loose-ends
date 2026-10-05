import Foundation

/// The onboarding (design briefing, screen 12, #29): three steps, each skippable, and the whole of
/// it too. Pure: the defaults and launch arguments come in from the caller. Per device on purpose —
/// a second device should show it again, so the marker stays in `UserDefaults`, not in the store.
struct OnboardingFlow: Equatable {
    enum Step: Int, CaseIterable {
        case siri, notifications, contexts
    }

    /// What to say when Apple Intelligence is not there (screen 12). The rules still sort dates,
    /// importance, urgency and recognised texts without it (#95, #117, #136).
    enum ModelNote: Equatable {
        case turnedOff, notReady, notEligible
    }

    static let doneKey = "onboardingDone"
    /// UI tests start on the start screen; only this argument brings the onboarding up under them.
    static let uiTestArgument = "--ui-testing-onboarding"

    private(set) var step: Step = .siri

    /// The last step's button finishes instead of moving on.
    var isLastStep: Bool { step == Step.allCases.last }

    /// Moves to the next step. False once there is none: the caller finishes.
    mutating func advance() -> Bool {
        guard let next = Step(rawValue: step.rawValue + 1) else { return false }
        step = next
        return true
    }

    static func shouldShow(defaults: UserDefaults = .standard, arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        if arguments.contains(uiTestArgument) { return true }
        if arguments.contains("--ui-testing") { return false }
        return !isDone(defaults: defaults)
    }

    static func isDone(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: doneKey)
    }

    /// Finished or skipped, it does not come back on this device.
    static func finish(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: doneKey)
    }

    /// Maps the model's unavailability reason (`FoundationModelsEnricher.unavailableReason`, the
    /// system's case name) to the note; nil while the model is there.
    static func modelNote(for reason: String?) -> ModelNote? {
        guard let reason else { return nil }
        if reason.contains("appleIntelligenceNotEnabled") { return .turnedOff }
        if reason.contains("modelNotReady") { return .notReady }
        return .notEligible
    }
}
