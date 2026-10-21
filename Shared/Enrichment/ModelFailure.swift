import Foundation
#if canImport(FoundationModels) && !os(watchOS)
import FoundationModels
#endif

/// Which model failures cannot succeed on a retry (#535). Not implemented yet: nothing is permanent.
enum ModelFailure {
    static func isPermanent(_ error: Error) -> Bool {
        false
    }
}
