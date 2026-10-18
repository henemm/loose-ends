import Foundation

/// The subtitle of a wide list (#477 Schnitt 1): how many tasks are open and how long they take
/// together. Counted and added up over `status` and `duration`, no model. Free of SwiftUI, so it is
/// testable without a screen; it lives here and not in `Shared/` because the text needs the app's strings.
struct ListSummary: Equatable {
    let openCount: Int
    /// Sum of the open tasks' duration buckets; tasks without a duration add nothing.
    let minutes: Int
    /// "2 h and more" counts as 120, so the sum is only a lower bound.
    let isAtLeast: Bool

    static func of(_ tasks: [TaskItem]) -> ListSummary {
        let open = tasks.filter { $0.status != .done }
        let buckets = open.compactMap(\.duration)
        return ListSummary(
            openCount: open.count,
            minutes: buckets.reduce(0) { $0 + minutes(of: $1) },
            isAtLeast: buckets.contains(.hours2plus)
        )
    }

    static func minutes(of bucket: DurationBucket) -> Int {
        switch bucket {
        case .minutes5: 5
        case .minutes15: 15
        case .minutes30: 30
        case .hour1: 60
        case .hours2plus: 120
        }
    }

    /// "2 open · 20 min", "1 open · at least 2 h"; nil when nothing is open.
    func text(bundle: Bundle = .main) -> String? {
        guard openCount > 0 else { return nil }
        let count = String(localized: "\(openCount) open", bundle: bundle)
        guard minutes > 0 else { return count }
        let time = isAtLeast ? String(localized: "at least \(duration(bundle: bundle))", bundle: bundle) : duration(bundle: bundle)
        return "\(count) · \(time)"
    }

    /// Under an hour in minutes, from an hour in hours with the rest in minutes.
    private func duration(bundle: Bundle) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return String(localized: "\(rest) min", bundle: bundle) }
        if rest == 0 { return String(localized: "\(hours) h", bundle: bundle) }
        return String(localized: "\(hours) h \(rest) min", bundle: bundle)
    }
}
