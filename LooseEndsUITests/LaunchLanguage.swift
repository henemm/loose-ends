import Foundation

/// The language a UI test launches the app in (#761, Epic #750). CI sets `LOOSEENDS_UI_LANG` once per shipped
/// language (`ui-smoke-lang`, passed through by `sim.sh` as `TEST_RUNNER_LOOSEENDS_UI_LANG`); without it every
/// test runs in English, as before. Tests that read a word off the screen take it from `phrase`, so a new
/// shipped language fails here with its name, not with a wrong label somewhere in a test.
/// A class with its own default (`StoreScreenshotsTests`: German, #842) passes its language to the `for:`/`in:` forms.
enum LaunchLanguage {
    static var code: String { ProcessInfo.processInfo.environment["LOOSEENDS_UI_LANG"] ?? "en" }

    static var locale: String { locale(for: code) }

    static func locale(for language: String) -> String {
        switch language {
        case "en": return "en_US"
        case "de": return "de_DE"
        default: return "\(language)_\(language.uppercased())"
        }
    }

    /// `-AppleLanguages` and `-AppleLocale` for `app.launchArguments`.
    static var arguments: [String] { arguments(for: code) }

    static func arguments(for language: String) -> [String] {
        ["-AppleLanguages", "(\(language))", "-AppleLocale", locale(for: language)]
    }

    /// What the start screen says in each language, for the assertions of the matrix classes; the `store…`
    /// keys are the made-up tasks and the words `StoreScreenshotsTests` looks for (#842 Schnitt 4a).
    private static let phrases: [String: [String: String]] = [
        "question": ["en": "What should I remember?", "de": "Was soll ich aufnehmen?"],
        "lookOver": ["en": "to look over", "de": "zum Durchsehen"],
        "storeTask1": ["en": "Check the tax notice today", "de": "Steuerbescheid heute prüfen"],
        "storeTask2": ["en": "Call Anna today about Sunday", "de": "Anna heute wegen Sonntag anrufen"],
        "storeTask3": ["en": "Water the flowers today", "de": "Blumen heute gießen"],
        "storeTask4": ["en": "Mow the lawn", "de": "Rasen mähen"],
        "storeTyped": ["en": "Take the bike in for a service", "de": "Fahrrad zur Inspektion bringen"],
        "storeThirty": ["en": "30 min", "de": "30 Min."],
        "storeComplete": ["en": "flowers", "de": "Blumen"],
        "storeDue": ["en": "tax notice", "de": "Steuerbescheid"],
    ]

    static func phrase(_ key: String) -> String { phrase(key, in: code) }

    static func phrase(_ key: String, in language: String) -> String {
        guard let text = phrases[key]?[language] else {
            preconditionFailure("LaunchLanguage: no \"\(key)\" for language \(language), add it to `phrases`")
        }
        return text
    }
}
