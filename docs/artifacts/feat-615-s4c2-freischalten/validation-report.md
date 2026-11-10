# Validation Report: feat-615-s4c2-freischalten (#615 Schnitt 4c-2a)

Datum: 2026-11-09, Stand 5a7b4b9 (plus Doku-Nachtrag in CLAUDE.md)

## Test Results
- Python: test_asc_store_version 22 OK, test_asc_what_to_test 28 OK, test_entitlements_sync 4 OK, test_info_plist_sync 4 OK, test_catalog_languages 8 OK; 0 übersprungen
- `./scripts/sim.sh generate`: kein Diff an versionierten Dateien
- `./scripts/sim.sh sim-unit` (alle Unit-Tests, iPhone 17, iOS 27.2): TEST SUCCEEDED, 1454 bestanden, 0 fehlgeschlagen, 13 übersprungen.
  Die 13 sind Mess- und Modelltests ohne Eingabedatei oder Modell im Simulator: Korpus/Rohsätze (Ergebnisdatei und Korpus, Echte Rohsätze,
  Hilfstests für das Skript), Modell-Latenz/Guardrail (Every text twice through the real model, One cold and ten warm calls, Apple Intelligence
  is available on this Mac, Every note gets an answer in time, Most titles keep a word of their note), Berichte (Selbstkonsistenz AC-9,
  Textform-Bericht), Speech-Latenz (The first word arrives within 3 s, The final text keeps the key words; de_DE im Simulator nicht unterstützt).
- `./scripts/sim.sh test-proof AccountSettingsTests`: 7/7 bestanden, Beleg `simulator-run.txt`; Bilder geöffnet: Gruppe „Claude“ unter iCloud
  (Testmodus), Lösch-Dialog, Satz „not yet cleared for Claude“ – unverändert gegenüber 4c-1.
- `mac-build` (Implement-Phase, `mac-build-output.txt`): Build Succeeded.

## Stufe 2 ohne Testmodus
- Gebaute App: `LEAccountEnabled` Typ `bool`, Wert `false`; `LEServiceURL` fehlt.
- `./scripts/sim.sh launch` ohne `--ui-testing`: App startet normal (Einführung), Bild `ohne-testmodus-start.png` geöffnet.
- Abweichung: die Einstellungsseite ohne Testmodus ist ohne Tippwerkzeug nicht erreichbar; dass `false` die Gruppe verbirgt, belegen die
  Unit-Tests aus 4c-1 (`AccountSectionTests`: `isEnabled` false, `forApp == nil`), im vollen `sim-unit`-Lauf grün.

## Spec Compliance
- AC-1 bis AC-13 erfüllt (Fundstellen im Agentenbericht). Kleinigkeiten ohne Funktionslücke:
  AC-10 „kein Antworten“ hat keinen eigenen Test (gleicher Codepfad wie 500); AC-12 Doku formuliert die Regel als
  „nie zugeordnet und nie eingereicht, solange der Konto-Teil des Datenschutztextes nicht online steht“ – inhaltsgleich.

## Regression Check
- Keine Regressionen.

## Scope Check
- Produktdateien 4 (project.yml, testflight.yml, asc_what_to_test.py, asc_store_version.py): +105/−8 = 113 LoC (Grenze 250 eingehalten)
- Tests 320 LoC (Schätzung 160), generierte Abbilder 6, Doku 15 (+2 Zeilen CLAUDE.md im Doku-Abgleich)
- Gesamt ohne Belege ≈ 456 LoC, 10 Dateien; Überschreitung nur durch Tests/Abbilder/Doku, bei der Spec-Freigabe angenommen.
- Keine Dateien außerhalb der Tabelle „Affected Files“.

## Result: PASS
