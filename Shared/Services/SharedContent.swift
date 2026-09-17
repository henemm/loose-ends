import Foundation

/// What the share sheet handed over, reduced to what capture needs: the text to prefill, the link
/// back to the source, and the channel. Mail wins over links, links over plain text. Pure, so the
/// header parsing is testable without an extension host.
struct SharedContent: Equatable, Sendable {
    var prefill: String
    var sourceURL: URL?
    var channel: CaptureChannel

    static let empty = SharedContent(prefill: "", sourceURL: nil, channel: .share)

    /// `mails` are raw RFC 822 messages (what Mail shares); `texts` and `urls` come as they are.
    static func make(texts: [String], urls: [URL], mails: [String]) -> SharedContent {
        let text = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        let messageLink = urls.first { $0.scheme?.lowercased() == "message" }

        if let mail = mails.first {
            let subject = subject(ofMail: mail)
            return SharedContent(
                prefill: subject ?? text ?? "",
                sourceURL: messageLink ?? messageURL(ofMail: mail),
                channel: .mail
            )
        }
        if let link = messageLink {
            return SharedContent(prefill: text ?? "", sourceURL: link, channel: .mail)
        }
        if let url = urls.first {
            return SharedContent(prefill: text ?? url.absoluteString, sourceURL: url, channel: .share)
        }
        return SharedContent(prefill: text ?? "", sourceURL: nil, channel: .share)
    }

    // MARK: - Mail headers

    static func subject(ofMail raw: String) -> String? {
        header("Subject", in: raw).map(decodeEncodedWords)
    }

    /// Mail opens `message://%3Cmessage-id%3E`; the angle brackets are percent-encoded.
    static func messageURL(ofMail raw: String) -> URL? {
        guard let id = header("Message-ID", in: raw)?.trimmingCharacters(in: .whitespaces), !id.isEmpty else { return nil }
        let bracketed = id.hasPrefix("<") ? id : "<\(id)>"
        guard let encoded = bracketed.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._@"))) else { return nil }
        return URL(string: "message://\(encoded)")
    }

    /// First occurrence of a header in the header section, unfolded. Nil when absent or empty.
    static func header(_ name: String, in raw: String) -> String? {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        let headerSection = normalized.components(separatedBy: "\n\n").first ?? normalized
        var lines: [String] = []
        for line in headerSection.split(separator: "\n", omittingEmptySubsequences: false) {
            if let first = line.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += " " + line.trimmingCharacters(in: .whitespaces)
            } else {
                lines.append(String(line))
            }
        }
        let prefix = name.lowercased() + ":"
        for line in lines where line.lowercased().hasPrefix(prefix) {
            let value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// RFC 2047 encoded words (`=?UTF-8?B?...?=` and `=?UTF-8?Q?...?=`) become plain text.
    static func decodeEncodedWords(_ value: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"=\?([^?]+)\?([BbQq])\?([^?]*)\?="#) else { return value }
        var result = ""
        var cursor = value.startIndex
        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
        for (index, match) in matches.enumerated() {
            guard let whole = Range(match.range, in: value),
                  let charsetRange = Range(match.range(at: 1), in: value),
                  let kindRange = Range(match.range(at: 2), in: value),
                  let payloadRange = Range(match.range(at: 3), in: value) else { continue }
            let between = value[cursor..<whole.lowerBound]
            // Whitespace between two encoded words is not part of the text.
            if index == 0 || !between.allSatisfy(\.isWhitespace) { result += between }
            let charset = String(value[charsetRange])
            let payload = String(value[payloadRange])
            let data: Data?
            if value[kindRange].uppercased() == "B" {
                data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters)
            } else {
                data = decodeQuotedPrintable(payload.replacingOccurrences(of: "_", with: " "))
            }
            result += data.flatMap { decode($0, charset: charset) } ?? String(value[whole])
            cursor = whole.upperBound
        }
        result += value[cursor...]
        return result
    }

    private static func decodeQuotedPrintable(_ text: String) -> Data? {
        var bytes: [UInt8] = []
        var iterator = Array(text.utf8).makeIterator()
        while let byte = iterator.next() {
            if byte == UInt8(ascii: "="),
               let high = iterator.next(), let low = iterator.next(),
               let value = UInt8(String(decoding: [high, low], as: UTF8.self), radix: 16) {
                bytes.append(value)
            } else {
                bytes.append(byte)
            }
        }
        return Data(bytes)
    }

    private static func decode(_ data: Data, charset: String) -> String? {
        switch charset.lowercased() {
        case "iso-8859-1", "latin1": String(data: data, encoding: .isoLatin1)
        case "windows-1252": String(data: data, encoding: .windowsCP1252)
        default: String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        }
    }
}
