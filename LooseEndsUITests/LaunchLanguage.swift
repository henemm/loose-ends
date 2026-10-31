import Foundation

/// The language a UI test launches the app in (#761, Epic #750). CI sets `LOOSEENDS_UI_LANG` once per shipped
/// language (`ui-smoke-lang`, passed through by `sim.sh` as `TEST_RUNNER_LOOSEENDS_UI_LANG`); without it every
/// test runs in English, as before. Tests that read a word off the screen take it from `phrase`, so a new
/// shipped language fails here with its name, not with a wrong label somewhere in a test.
enum LaunchLanguage {
    static var code: String { ProcessInfo.processInfo.environment["LOOSEENDS_UI_LANG"] ?? "en" }

    static var locale: String {
        switch code {
        case "en": return "en_US"
        case "de": return "de_DE"
        default: return "\(code)_\(code.uppercased())"
        }
    }

    /// `-AppleLanguages` and `-AppleLocale` for `app.launchArguments`.
    static var arguments: [String] { ["-AppleLanguages", "(\(code))", "-AppleLocale", locale] }

    /// What the start screen says in each language, for the assertions of the matrix classes.
    private static let phrases: [String: [String: String]] = [
        "question": ["en": "What should I remember?", "de": "Was soll ich aufnehmen?"],
        "lookOver": ["en": "to look over", "de": "zum Durchsehen"],
    ]

    static func phrase(_ key: String) -> String {
        guard let text = phrases[key]?[code] else {
            preconditionFailure("LaunchLanguage: no \"\(key)\" for language \(code), add it to `phrases`")
        }
        return text
    }
}
