import Foundation

/// What the capture field shows while it is empty (#279, #297): "Listening …" while the microphone
/// listens, the usual placeholder otherwise, nothing once there is text. Pure, no system access.
enum ListeningHint: Equatable {
    case hint
    case placeholder
    case none

    static func state(isListening: Bool, text: String) -> ListeningHint {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .none }
        return isListening ? .hint : .placeholder
    }
}
