import Foundation
import OSLog

/// What in a note can be tapped (#439): phone numbers, links, mail addresses and street addresses,
/// found by `NSDataDetector` — a rule, not the model. Pure; the view turns the hits into links.
/// The links shown in a note stay with the detector; capture (title, note) uses `PhoneRule`, so it
/// comes out the same on every device (#786).
enum NoteLinks {
    enum Kind: Equatable, Sendable {
        case phone, link, mail, address
    }

    struct Hit: Equatable, Sendable {
        let kind: Kind
        let range: Range<String.Index>
        /// What a tap opens: `tel:`, the link itself, `mailto:`, or Apple Maps searching the address.
        let url: URL
    }

    private static let logger = Logger(subsystem: "com.henning.looseends", category: "NoteLinks")

    static func hits(in text: String) -> [Hit] {
        let types: NSTextCheckingResult.CheckingType = [.phoneNumber, .link, .address]
        let detector: NSDataDetector
        do {
            detector = try NSDataDetector(types: types.rawValue)
        } catch {
            logger.error("No data detector: \(error, privacy: .public)")
            return []
        }
        let whole = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: whole).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            switch match.resultType {
            case .phoneNumber:
                guard let number = match.phoneNumber, let url = phoneURL(number) else { return nil }
                return Hit(kind: .phone, range: range, url: url)
            case .link:
                guard let url = match.url else { return nil }
                return Hit(kind: url.scheme == "mailto" ? .mail : .link, range: range, url: url)
            case .address:
                guard let url = mapsURL(String(text[range])) else { return nil }
                return Hit(kind: .address, range: range, url: url)
            default:
                return nil
            }
        }
    }

    /// The note with each hit as a link, for `Text`: the system opens `tel:`, `mailto:` and web links.
    static func attributed(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        for hit in hits(in: text) {
            guard let lower = AttributedString.Index(hit.range.lowerBound, within: result),
                  let upper = AttributedString.Index(hit.range.upperBound, within: result) else { continue }
            result[lower..<upper].link = hit.url
        }
        return result
    }

    /// Digits and a leading plus only: "02 51 / 4 65 56" dials as "tel:025146556".
    static func phoneURL(_ number: String) -> URL? {
        let dialable = number.enumerated().compactMap { index, character -> Character? in
            if character.isASCII, character.isNumber { return character }
            return index == 0 && character == "+" ? character : nil
        }
        guard dialable.contains(where: \.isNumber) else { return nil }
        return URL(string: "tel:" + String(dialable))
    }

    static func mapsURL(_ address: String) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: address)]
        return components?.url
    }
}
