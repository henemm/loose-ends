import Foundation

/// The one way a raw text is broken into words, shared by the product and the measurement code
/// (#136). It used to live as `TitleCheck.normalized`/`TitleCheck.words(in:)` in `Measurement/`,
/// outside the product path — a second tokenizer in the product would have meant the measurement
/// measures something other than what the app does.
///
/// Pure `Foundation` on purpose: `Shared/` also compiles into the watch, the widgets and the share
/// extension, and this file is compiled into the measurement targets as plain source, which carry no
/// `import LooseEnds`.
enum RawTextWords {
    /// Lowercased and stripped of diacritics, so "Özdemir" matches "özdemir" and "Muell" is still
    /// not "Müll" (a real change of the text, which should count).
    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
    }

    /// Splits on everything that is neither letter, digit nor hyphen, so "Mutter-Kind-Kur" stays one
    /// word. No length filter here: `LeaveOneOut.similarityWords` adds one for its similarity
    /// search, `RecognitionRule` must not have one because it compares for equality.
    static func words(in text: String) -> [String] {
        text.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" }).map(String.init)
    }
}
