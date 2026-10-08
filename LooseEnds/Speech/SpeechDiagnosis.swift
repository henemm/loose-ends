import Foundation

/// Die Zeile „Ton ohne Text“ (#274): Kommt `threshold` Sekunden lang Ton an, ohne dass die Erkennung ein
/// einziges Ergebnis liefert, sieht der Nutzer eine Kurzdiagnose statt nichts. Rein, ohne Systemzugriff;
/// `SpeechCapture` zählt und fragt jede Sekunde nach.
struct SpeechDiagnosis: Equatable {
    /// Die eine Stelle für die Schwelle. Das erste Wort kam auf dem Gerät 0,6 s nach dem Sprechen (Lauf 5).
    static let threshold: TimeInterval = 6

    let modelStatus: String
    let microphone: Bool
    let speech: Bool
    let buffers: Int
    let results: Int

    /// Ein Wert genau dann, wenn Ton ankommt, kein Ergebnis kam und die Schwelle erreicht ist (inklusive).
    static func hint(
        buffers: Int, results: Int, secondsListening: TimeInterval,
        modelStatus: String, microphone: Bool, speech: Bool
    ) -> SpeechDiagnosis? {
        guard buffers > 0, results == 0, secondsListening >= threshold else { return nil }
        return SpeechDiagnosis(
            modelStatus: modelStatus, microphone: microphone, speech: speech,
            buffers: buffers, results: results
        )
    }

    /// Die Kurzzeile in der Gerätesprache; der Modellstatus bleibt der Rohwert des Systems.
    var text: String {
        let mic = Self.word(microphone)
        let rec = Self.word(speech)
        return String(localized: "No text yet — model: \(modelStatus) · microphone: \(mic) · speech: \(rec) · buffers: \(buffers) · results: \(results)")
    }

    private static func word(_ value: Bool) -> String {
        value
            ? String(localized: "Speech diagnosis yes", defaultValue: "yes")
            : String(localized: "Speech diagnosis no", defaultValue: "no")
    }
}
