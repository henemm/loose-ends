import AppIntents
import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Führt die beiden Aktionen aus, die hinter Hennings Kurzbefehlen stecken — genau so,
/// wie die Kurzbefehle-App sie aufruft.
///
/// Was hier NICHT geprüft werden kann: ob die erfasste Aufgabe anschließend im Speicher
/// der App steht. Unter Tests gibt `ModelContainerFactory.make()` bei jedem Aufruf einen
/// frischen Speicher im Arbeitsspeicher zurück (kein Zwischenspeicher wie im Betrieb), der
/// Test schaute also zwangsläufig in einen anderen Speicher als die Aktion schrieb. Ein
/// solcher Test schlägt immer fehl und beweist nichts — er stand hier einmal und hat mich
/// prompt zu einer falschen Aussage verleitet.
@MainActor
struct IntentExecutionTests {
    @Test("Aufgabe erfassen läuft ohne Fehler durch")
    func captureTextIntentPerforms() async throws {
        let intent = CaptureTextIntent()
        intent.text = "Heckenschere schärfen lassen"

        // Wirft die Aktion, schlägt der Test fehl — genau das wäre der Fall, den Henning
        // als „nichts passiert" sieht, wenn die Kurzbefehle-App den Fehler schluckt.
        _ = try await intent.perform()
    }

    @Test("Erinnerung über das Reminders-Schema anlegen liefert die neue Erinnerung zurück (#25)")
    func createReminderIntentPerforms() async throws {
        let intent = CreateReminderIntent()
        intent.title = "Heckenschere schärfen lassen"
        intent.dueDate = DateComponents(year: 2026, month: 10, day: 6)
        intent.list = ListEntity.inbox

        let result = try await intent.perform()
        let reminder = try #require(result.value)

        #expect(reminder.title == "Heckenschere schärfen lassen")
        #expect(reminder.list.id == ListEntity.inboxID)
        #expect(reminder.dueDate?.year == 2026)
        #expect(reminder.dueDate?.month == 10)
        #expect(reminder.dueDate?.day == 6)
    }

    @Test("Erfassung öffnen meldet der App, dass sie die Erfassung zeigen soll")
    func openCaptureIntentSignalsTheApp() async throws {
        CaptureRequest.shared.pending = false

        _ = try await OpenCaptureIntent().perform()

        #expect(CaptureRequest.shared.pending,
                "Der Kurzbefehl hat der App kein Signal zum Öffnen der Erfassung gegeben")
    }
}
