import Foundation
import Speech

/// What the capture scene shows before it listens (#64): the on-device model is there, can be
/// loaded, is loading, or this language has none. Pure over the system's answer, so the mapping is
/// testable without a device. The simulator has no speech models at all and always answers
/// `.unsupported` (docs/context/spracherfassung-teststufen.md).
enum SpeechReadiness: Equatable, Sendable {
    case unsupported
    /// Supported, but the model is not on the device. Loaded only after the user taps "Load".
    case needsModel
    /// The system is already loading it, e.g. for another app. A tap joins that download.
    case loading
    case ready

    static func from(_ status: AssetInventory.Status) -> SpeechReadiness {
        switch status {
        case .unsupported: .unsupported
        case .supported: .needsModel
        case .downloading: .loading
        case .installed: .ready
        @unknown default: .unsupported
        }
    }

    /// 0...1 for the progress line; a download that has not reported its size yet reads 0, never NaN.
    static func fraction(completed: Int64, total: Int64) -> Double {
        guard total > 0, completed > 0 else { return 0 }
        return min(1, Double(completed) / Double(total))
    }

    static func fraction(_ progress: Progress) -> Double {
        fraction(completed: progress.completedUnitCount, total: progress.totalUnitCount)
    }
}
