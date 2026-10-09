import Foundation

/// Die Startzeiten der Erfassung (#274 / #279 A, Schnitt 1): fünf zusammenhängende Strecken vom Öffnen bis
/// zum Zuhören und die Zeit vom Zuhören bis zum ersten Ergebnis, in Sekunden. `SpeechCapture` misst, die Regel liest.
struct SpeechTimings: Equatable {
    let open: TimeInterval
    let modelCheck: TimeInterval
    let rights: TimeInterval
    let analyzer: TimeInterval
    let microphone: TimeInterval
    var firstResult: TimeInterval?

    /// Die Startdauer: Die Strecken schließen aneinander an, also ist sie ihre Summe.
    var start: TimeInterval { open + modelCheck + rights + analyzer + microphone }
}

/// Die Zeile „Ton ohne Text“ (#274): Kommt `threshold` Sekunden lang Ton an, ohne dass die Erkennung ein
/// einziges Ergebnis liefert, sieht der Nutzer eine Kurzdiagnose statt nichts. Rein, ohne Systemzugriff;
/// `SpeechCapture` zählt und fragt jede Sekunde nach. Mit Zeiten wird daraus nach dem ersten Ergebnis ein
/// Bericht, wenn der Start oder das erste Ergebnis zu lange dauerte (Schnitt 1).
struct SpeechDiagnosis: Equatable {
    /// Die eine Stelle für die Schwelle. Das erste Wort kam auf dem Gerät 0,6 s nach dem Sprechen (Lauf 5).
    static let threshold: TimeInterval = 6
    /// Die eine Stelle für den langsamen Start: im Prüfbau 0,6 s (#22), 3 s liegen weit darüber.
    static let slowStart: TimeInterval = 3

    let modelStatus: String
    let microphone: Bool
    let speech: Bool
    let buffers: Int
    let results: Int
    var timings: SpeechTimings?

    /// Fall W: Ton kommt an, kein Ergebnis, Schwelle erreicht (inklusive). Fall B: Ergebnisse da, und der Start
    /// dauerte mindestens `slowStart` oder das erste Ergebnis kam nach mindestens `threshold`. Ohne Zeiten kein Fall B.
    static func hint(
        buffers: Int, results: Int, secondsListening: TimeInterval,
        modelStatus: String, microphone: Bool, speech: Bool,
        timings: SpeechTimings? = nil
    ) -> SpeechDiagnosis? {
        let waiting = buffers > 0 && results == 0 && secondsListening >= threshold
        let report = results > 0 && timings.map(isSlow) == true
        guard waiting || report else { return nil }
        return SpeechDiagnosis(
            modelStatus: modelStatus, microphone: microphone, speech: speech,
            buffers: buffers, results: results, timings: timings
        )
    }

    private static func isSlow(_ timings: SpeechTimings) -> Bool {
        timings.start >= slowStart || (timings.firstResult.map { $0 >= threshold } ?? false)
    }

    /// Die Kurzzeile in der Gerätesprache; der Modellstatus bleibt der Rohwert des Systems.
    var text: String {
        guard let timings else { return waitingText }
        let join = String(localized: "Speech diagnosis join", defaultValue: " · ")
        let parts = Self.startText(timings)
        guard results > 0 else { return waitingText + join + parts }
        guard let first = timings.firstResult else { return parts }
        let after = Self.seconds(first)
        return String(localized: "Speech diagnosis first text after %@ s", defaultValue: "First text after \(after) s")
            + join + parts
    }

    private var waitingText: String {
        let mic = Self.word(microphone)
        let rec = Self.word(speech)
        return String(localized: "No text yet — model: \(modelStatus) · microphone: \(mic) · speech: \(rec) · buffers: \(buffers) · results: \(results)")
    }

    private static func startText(_ timings: SpeechTimings) -> String {
        let (sum, open, model) = (seconds(timings.start), seconds(timings.open), seconds(timings.modelCheck))
        let (rights, analyzer, mic) = (seconds(timings.rights), seconds(timings.analyzer), seconds(timings.microphone))
        return String(
            localized: "Speech diagnosis start: %@ s (opening %@ · model %@ · rights %@ · analyzer %@ · microphone %@)",
            defaultValue: "Start: \(sum) s (opening \(open) · model \(model) · rights \(rights) · analyzer \(analyzer) · microphone \(mic))"
        )
    }

    /// Eine Nachkommastelle in der Gerätesprache (Komma auf Deutsch, Punkt auf Englisch).
    private static func seconds(_ value: TimeInterval) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    private static func word(_ value: Bool) -> String {
        value
            ? String(localized: "Speech diagnosis yes", defaultValue: "yes")
            : String(localized: "Speech diagnosis no", defaultValue: "no")
    }
}
