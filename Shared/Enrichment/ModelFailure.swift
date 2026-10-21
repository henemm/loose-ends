import Foundation
#if canImport(FoundationModels) && !os(watchOS)
import FoundationModels
#endif

/// Which model failures cannot succeed on a retry (#535): the same note hits the same guardrail
/// and the same context window again. Everything else (time, load, device state, unknown) stays
/// retryable; without FoundationModels nothing is permanent.
enum ModelFailure {
    static func isPermanent(_ error: Error) -> Bool {
        #if canImport(FoundationModels) && !os(watchOS)
        if let model = error as? LanguageModelError {
            switch model {
            case .guardrailViolation, .contextSizeExceeded: return true
            default: return false
            }
        }
        #endif
        return false
    }
}
