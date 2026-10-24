# Mini-Spec: FieldSettingsStoreTests hängen nicht mehr an den echten App-Defaults (#638)

## Was ändert sich
- `LooseEnds/App/FieldSettingsStore.swift`: `forApp(arguments:)` bekommt einen zweiten Parameter
  `defaults: UserDefaults = .standard`. Ohne `--ui-testing` baut es `FieldSettingsStore(defaults: defaults)`
  statt `FieldSettingsStore()`. Der App-Aufruf `forApp()` bleibt unverändert und liest weiter die echten Defaults.
- `LooseEndsTests/DetailFieldsTests.swift`: `uiTestsEverything` übergibt eine eigene, leere Suite und prüft
  weiter, dass der Unit-Prozess den Standard sieht. Neu dazu: ein Test, der zeigt, dass `forApp` die
  übergebenen Defaults wirklich liest (Suite mit `["notes", "energy"]` → genau diese zwei an).

## Nachgestellt (Intake 2026-10-24, iPhone 17 / iOS 27.0)
- `defaults write com.henning.looseends offeredFields -array notes energy` im Simulator, dann
  `./scripts/sim.sh sim-unit FieldSettingsStoreTests`: `uiTestsEverything` rot
  (`DetailFieldsTests.swift:166`, `settings == .standard` verletzt), die drei anderen Tests grün.
- Der Schreiber des Schlüssels in die echten Defaults ist nicht gefunden (`CaptureCancelCrashTests` ohne
  `--ui-testing` setzte ihn nicht); für den Fix unerheblich, der Test darf von diesem Zustand nicht abhängen.

## Acceptance Criteria
- **AC-1:** `FieldSettingsStore.forApp(arguments:defaults:)` nimmt die Defaults entgegen; ohne `--ui-testing` liest der Store genau diese, mit `--ui-testing` bleibt alles wie bisher (eigene Suite, alles an, kein iCloud).
- **AC-2:** `uiTestsEverything` benutzt eine eigene Suite und ist grün, auch wenn die echten Defaults der App `offeredFields` tragen. Beleg: Schlüssel von Hand gesetzt, derselbe Lauf wie oben ist grün, ohne Deinstallation.
- **AC-3:** Ein Test belegt, dass `forApp` die übergebenen Defaults liest (Suite mit `["notes", "energy"]` ergibt `.on == [.notes, .energy]`).
- **AC-4:** Der Test prüft weiter, dass nur der UI-Test-Prozess alle Schalter an hat: `isUITesting` ist im Unit-Prozess falsch, und `standardArgument` bleibt `--ui-testing-fields-standard`.

## Was sich nicht ändern darf
- Verhalten der App und der UI-Tests: `LooseEndsApp` ruft `forApp()` unverändert auf, `FieldsSmokeTests` und alle Smoke-Tests sehen dieselben Schalter wie bisher.
- Keine Änderung an Persistenz, Schlüsselnamen (`offeredFields`, `weekReward`), CloudKit oder Info.plist. Kein Pfad der Geräteliste berührt.

## Manuelle Test-Schritte
Entfällt, alles läuft automatisiert im Simulator.

## Inline-Test (wird während Implementierung geschrieben)
- [ ] Rot vor dem Fix: Schlüssel setzen, `sim-unit FieldSettingsStoreTests` → `uiTestsEverything` rot.
- [ ] Grün nach dem Fix: gleicher Zustand, gleicher Lauf → alle Tests der Suite grün; Schlüssel danach wieder löschen.
- [ ] Voller `sim-unit` grün.
