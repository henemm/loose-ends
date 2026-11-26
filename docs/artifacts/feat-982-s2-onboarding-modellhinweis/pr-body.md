## #982 Schnitt 2 – Onboarding ohne Modellhinweis (ADR-22)

Der Hinweis über Apple Intelligence auf Schritt 1 des Onboardings entfällt samt Weg dorthin: `OnboardingFlow.ModelNote`/`modelNote(for:)`, `OnboardingView.modelUnavailableReason` und die Anzeige, `ContentView.onboardingModelReason` (Startargument `--ui-testing-model-reason`), drei Katalogschlüssel und ihre Tests. Im Produkt war der Hinweis seit Schnitt 1 schon unsichtbar.

- RED: UI-Test zeigte den Hinweis mit dem alten Argument; `scripts/test_onboarding_ohne_modell.py` 2 Fehlschläge gegen den Stand davor.
- GREEN: `test-proof OnboardingTests` 3/3 (Screenshot Schritt 1 ohne Hinweis), Unit 1394/1394 (13 übersprungen), Katalogwächter und Abwesenheitstest grün; Adversary VERIFIED (2 Runden).
- App-Code: 4 Dateien, −53 LoC. Kein Pfad der Geräteliste berührt.

Refs #982 (offen: Schnitt 3 Aufräumen, Stufe 3 über TestFlight).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
