---
entity_id: fix-402-menueleiste-layout
type: bugfix
created: 2026-10-13
updated: 2026-10-13
status: draft
workflow: fix-402-menueleiste-layout
---

# Spec: #402 Menüleisten-Panel ruhig (Diagnose nur bei Problem) und #405 Doku zur Plattformwahl

## Approval

- [ ] Approved (Henning)

## Purpose

**Teil A, #402** (Henning, 2026-10-13): Das Erfassen-Feld unter dem Menüleisten-Symbol am Mac hat verdeckte Knöpfe und eine
dominante, dreizeilige Diagnosezeile.

**Hat es bisher funktioniert?** Das Panel kam mit #356, #382 machte es höher; ein letzter guter Stand ist nicht belegt (Analyse
in `docs/context/fix-402-menueleiste-layout.md`). Nachgestellt am 2026-10-13 im Mac-Prüfbau (Screenshots unter
`docs/artifacts/402-menueleiste-layout/`): Das Panel wächst nicht mit, wenn die Diagnosezeile später erscheint; die Knöpfe
überdecken dann die Fußzeile. Die sichtbare Zeile war Fall B (Bericht „Erster Text nach 7,8 s · Start …“), ausgelöst nur durch
Schweigen: `firstResult` zählt ab Zuhörbeginn, nicht ab erstem Sprechen. Fall W (Puffer da, kein Ergebnis) trennt Stille
ebenfalls nicht von einem Defekt, weil Puffer auch bei Stille kommen.

**Schon auf main (#401), hier nicht noch einmal gebaut:** Panelhöhe über `.fixedSize(vertical:)` und die Abstände in
`LooseEnds/Mac/MenuBarCapture.swift`. Diese Spec ändert diese Datei nicht.

Freigegeben (Henning, 2026-10-13): Variante „Eine Zeile bei Problem“. Vorschau:
`docs/artifacts/402-menueleiste-layout/index.html`. Verworfen: Diagnose nur im Fenster, nur Symbol.

**Teil B, #405** (Henning: „Build 55 installiert kein Menü-Icon“). Befund, belegt am 2026-10-13 auf Hennings Mac:
`/Applications/Loose Ends.app` ist die iOS-App im Mac-Wrapper (`Wrapper/LooseEnds.app`, aus TestFlight mit Plattformwahl „iOS“,
3,7 MB), nicht die native Mac-App; das Menüleistensymbol steht unter `#if os(macOS)` und fehlt dort deshalb. Die Mac-Fassung ist
in TestFlight vorhanden (Plattformwahl „macOS“ steht zur Auswahl, Henning bestätigt; `upload-mac` und `confirm-mac` von Build 55
grün). Quelltext Build 53 → 55: nur `MenuBarCapture.swift` (6 Zeilen), unbeteiligt. `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD` ist
in der erzeugten Projektdatei bereits NO; ein Verbot per `project.yml` ist **kein** Fix und wird nicht vorgeschlagen. Der Fehler
liegt also in der Bedienung (falsche Plattformwahl), nicht im Bau. Teil B ist deshalb **reine Doku** (ein Satz in
`docs/reference/testflight.md`); keine Hinweiszeile in der App, keine neue Regel, keine neuen Texte.

Regelweg-Vermerk (Regeln vor Modell): Kein Modell beteiligt; alles sind reine Regeln.

## Lösung

### Teil A — #402

1. **`LooseEnds/Speech/SpeechDiagnosis.swift`.**
   - Neue benannte Schwelle `SpeechDiagnosis.audibleLevel` (Pegel auf der 0…1-Skala von `Waveform`, −55…−25 dBFS; Startwert 0,1
     ≈ −52 dBFS, knapp über Stille). Die Wartezeit `threshold` (6 s) bleibt unverändert und bleibt die einzige Stelle dafür.
   - `hint(...)` bekommt statt `secondsListening` den Parameter `secondsAudible: TimeInterval?` (Sekunden seit dem ersten
     Pegel über `audibleLevel`; `nil` = bisher nur Stille) und `showsReport: Bool` (Standard `false`).
   - Fall W: `buffers > 0 && results == 0 && (secondsAudible ?? 0) >= threshold` (inklusive wie bisher; `nil` löst nie aus).
   - Fall B: wie bisher (`results > 0` und langsam), aber nur wenn `showsReport` wahr ist (Messbericht, kein Problem).
   - Neue Kurztext-Eigenschaft `shortText` für die Mac-Zeile (lokalisiert, siehe 3); `text` (alle Einzelwerte) bleibt unverändert.
2. **`LooseEnds/Speech/SpeechCapture.swift`.** Der Mikrofonabgriff merkt sich den Zeitpunkt des ersten Pegels über
   `audibleLevel` (`firstAudibleAt`, im vorhandenen `@MainActor`-Pfad `waveform.append`, zurückgesetzt wie `listeningSince`).
   `updateDiagnosis` übergibt `secondsAudible` und `showsReport: LaunchTimings.isProbeBuild(bundleID: Bundle.main.bundleIdentifier)`.
   Keine weitere Änderung der Zähler oder Uhren.
3. **`LooseEnds/Views/CaptureView.swift`** (nur `#if os(macOS)` für die Optik). Auf dem Mac ersetzt eine **einzige** graue Zeile die
   mehrzeilige: SF Symbol `exclamationmark.circle` (Umriss) + `diagnosis.shortText`, `.font(.footnote)`, `.foregroundStyle(.secondary)`,
   `lineLimit(1)`. Text de „Ton kommt an, aber kein Text erkannt“, en „Sound arrives, but no text recognized“. Die Einzelwerte
   (`diagnosis.text`) stehen in `.help(...)` (Hinweis beim Darüberfahren) und als Accessibility-Label (Kennung
   `speechDiagnosisLabel` bleibt). Der Platz der Zeile ist **immer reserviert** (gleiche Höhe mit und ohne Zeile, Zeile
   unsichtbar statt entfernt), damit das Panel nie springt und die Knöpfe die Fußzeile nie überdecken. Auf iPhone/iPad bleiben
   Text, Umbruch und Optik der Diagnosezeile unverändert; dort gelten nur die geänderten Regeln aus 1.
4. **`LooseEnds/Resources/Localizable.xcstrings`.** Neuer Eintrag für den Kurztext (de/en).
5. **`LooseEndsTests/SpeechDiagnosisTests.swift`** (Swift Testing, Bestand angepasst und erweitert), siehe Test Plan.

### Teil B — #405 (nur Doku)

6. **`docs/reference/testflight.md`.** Im Mac-Abschnitt (Absatz „Die Mac-App (#389)“) ein Satz: In der TestFlight-App am Mac oben
   rechts „macOS“ wählen; sonst installiert TestFlight die iOS-Fassung im Mac-Wrapper (`/Applications/Loose Ends.app` mit
   `Wrapper/LooseEnds.app`), die kein Menüleistensymbol hat (#405).

## Scope

### Affected Files

| Datei | Änderung | Teil | Beschreibung |
|---|---|---|---|
| `LooseEnds/Speech/SpeechDiagnosis.swift` | MODIFY | A | Schwelle `audibleLevel`, Fall W ab erstem Pegel, Fall B nur mit `showsReport`, `shortText` |
| `LooseEnds/Speech/SpeechCapture.swift` | MODIFY | A | `firstAudibleAt`, Übergabe an die Regel, `isProbeBuild` |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | A | Mac: eine Zeile mit Symbol, `lineLimit(1)`, `.help`, reservierter Platz |
| `LooseEndsTests/SpeechDiagnosisTests.swift` | MODIFY | A | Bestandstests an neue Signatur, neue Regelfälle |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | A | ein neuer Text (de/en) |
| `docs/reference/testflight.md` | MODIFY | B | ein Satz zur Plattformwahl (reine Doku, kein Code) |

Geschätzt **ca. +130 / −20 LoC** (Teil A) plus wenige Doku-Zeilen (Teil B), innerhalb von ±250. Keine neue Funktion über 50 LoC.

**Dateigrenze:** Es sind **6 Dateien**: fünf Code- und Testdateien (Teil A) plus `testflight.md`, eine **reine Doku-Datei ohne
Code**. Vorschlag: die Doku-Datei gesondert zählen (Code-Grenze 4–5 Dateien bleibt mit fünf eingehalten). Siehe Offene Fragen.

**Geräteliste (CLAUDE.md):** Berührt wird `LooseEnds/Speech/` (Mikrofon und Spracherkennung). `Shared/`, `project.yml`,
`*.entitlements` und `Info.plist` werden **nicht** berührt. Stufe 3 gilt daher **nur für die Mac-Abnahme** (Panel und Regel mit
echtem Mikrofon) und läuft erst nach Hennings wörtlichem „jetzt ist ein Test möglich“; vorher nichts auf seinen Geräten, auch nichts
Lesendes. Teil B berührt keinen Pfad der Geräteliste (nur Doku); sein einziger Gerätepunkt ist Hennings Sicht auf das Symbol in der
Mac-App aus TestFlight (G-1).

**Side-Effects:** Keine Änderung an Datenmodell, Berechtigungen, Info.plist, AppStorage-Schlüsseln oder Audio. Die Diagnoseregel
gilt auch auf iPhone/iPad: dort erscheint Fall W erst nach 6 s **Ton** statt 6 s Zuhören, und der Bericht (Fall B) erscheint nur im
Prüfbau; ein Defekt mit Stille am Mikrofon (Pegel nie über `audibleLevel`) bleibt dort stumm, das ist gewollt (Schweigen löst
nichts aus).

### Nicht in diesem Ticket

- Panelhöhe über `.fixedSize` und Abstände (#401, schon auf main), `MenuBarCapture.swift` bleibt unberührt.
- Ein Verbot der iOS-Fassung auf dem Mac per `project.yml` (kein Fix, siehe Purpose).
- Eine Reparatur der Plattformzuweisung in App Store Connect (nicht lesbar, nicht nötig).
- Die Nebenursache „Hidden Bar“ auf Hennings Mac.

## Test Plan

### Automated Tests (TDD RED zuerst)

`LooseEndsTests/SpeechDiagnosisTests.swift` (Swift Testing, bestehende Suite „Speech diagnosis (#274)“):

- Bestandstests auf die neue Signatur umgestellt (`secondsAudible`), Inhalt unverändert: Schwelle 6 s, kein Treffer davor, Treffer
  bei exakt 6 s (inklusive), bleibt danach, kein Treffer ohne Puffer oder mit Ergebnis, Neustart zeigt nichts.
- `silenceIsNoProblem`: `secondsAudible == nil` bei 100 s Zuhören, Puffer da, kein Ergebnis → `nil`.
- `audibleLevelStartsTheClock`: `secondsAudible` 5,9 → `nil`, 6,0 → Treffer (Schwelle inklusive), unabhängig von der Gesamtzeit.
- `audibleLevelIsOneNamedConstant`: `audibleLevel` liegt zwischen 0 und 1 und über dem Pegel von Stille (0).
- `reportOnlyInProbeBuild`: Fall B mit langsamem Start: `showsReport: false` → `nil`, `showsReport: true` → Bericht (Schwellen
  `slowStart` 3 s und `threshold` 6 s inklusive wie bisher).
- `shortTextIsOneLineWithoutFigures`: `shortText` enthält keine Zahlen der Einzelwerte, `text` weiterhin alle (Bestandstest
  `textCarriesAllFacts`).
- Die Verdrahtung in `SpeechCapture` (erster Pegel setzt die Uhr) belegt der Durchlauf auf dem Mac (AC-7), nicht ein Unit-Test.

Bestehender UI-Test `LooseEndsUITests/SpeechDiagnosisLineTests.swift` (iOS-Fixture `--ui-testing-speech-diagnosis`) bleibt
unverändert und muss grün bleiben: Beleg, dass die iPhone/iPad-Zeile unverändert ist.

**Mac-Layout — es gibt keinen automatisierten Test.** `MenuBarExtra` ist im Simulator nicht erreichbar, Tests laufen nie auf dem
Mac als Host. Ein erfundener Test wäre nicht lauffähig und wird nicht geschrieben. Der Nachweis für die Panelhöhe ist AC-7
(Screenshots aus dem Mac-Prüfbau). Siehe Risiken und Offene Fragen.

### Abnahme (Stufen)

1. **Tests:** neue und angepasste Regeltests rot (vorher), grün (nachher); `./scripts/sim.sh unit` grün.
2. **Simulator:** `./scripts/sim.sh generate`, `./scripts/sim.sh build`, `./scripts/sim.sh test-proof SpeechDiagnosisLineTests`;
   iPhone-Zeile unverändert (Screenshot geöffnet und beschrieben).
3. **Gerät (nur Mac-Abnahme, wegen `LooseEnds/Speech/`):** nach Hennings wörtlichem „jetzt ist ein Test möglich“ AC-7 mit
   `./scripts/sim.sh mac`. Vorher ist alles gebaut und startklar. Begründung, dass keine weitere Gerätestufe nötig ist: „Kein Pfad der
   Geräteliste berührt“ gilt für alles außer `LooseEnds/Speech/`, und dort nur für den Mac.

## Acceptance Criteria

- **AC-1:** Given kein hörbarer Pegel (nie über `SpeechDiagnosis.audibleLevel`) / When beliebig lange zugehört wird, Puffer kommen,
  kein Ergebnis / Then liefert `SpeechDiagnosis.hint` `nil` (Schweigen ist kein Problem). Belegt durch Unit-Test `silenceIsNoProblem`
  (zuerst rot).
- **AC-2:** Given ein erster Pegel über `audibleLevel` / When `secondsAudible` die Schwelle `threshold` (6 s) erreicht (inklusive, 5,9 s
  noch nicht), Puffer da, kein Ergebnis / Then liefert `hint` Fall W; die Wartezeit zählt ab dem ersten Pegel, nicht ab Zuhörbeginn.
  Belegt durch Unit-Test `audibleLevelStartsTheClock`; `threshold` und `audibleLevel` stehen je an genau einer Stelle.
- **AC-3:** Given Ergebnisse da und ein langsamer Start (`slowStart` 3 s) oder spätes erstes Ergebnis (`threshold` 6 s, inklusive) /
  When `showsReport` falsch ist (Produkt) / Then liefert `hint` `nil`; mit `showsReport` wahr (Prüfbau, `LaunchTimings.isProbeBuild`)
  liefert er den Bericht wie bisher. Belegt durch Unit-Test `reportOnlyInProbeBuild` und Code-Prüfung am Diff
  (`SpeechCapture` übergibt `isProbeBuild(bundleID:)`).
- **AC-4:** Given macOS und Fall W / When die Erfassungsmaske die Diagnose zeigt / Then steht **eine** graue Zeile mit SF Symbol
  `exclamationmark.circle` (kein Emoji, kein Ersatzzeichen), `lineLimit(1)`, `.footnote`, `.secondary`, Text „Ton kommt an, aber kein
  Text erkannt“ (de) bzw. „Sound arrives, but no text recognized“ (en, beide im Zeichenkatalog), und die Einzelwerte (Modell, Mikrofon,
  Sprache, Puffer, Ergebnisse) stehen unverändert in `.help` und im Accessibility-Label. Belegt durch Code-Prüfung am Diff, den Test
  `shortTextIsOneLineWithoutFigures` und die Screenshots aus AC-7.
- **AC-5:** Given iPhone und iPad / When die Diagnosezeile erscheint / Then sind Text, Umbruch und Optik unverändert (alle
  Optikänderungen unter `#if os(macOS)`); nur die Regeln aus AC-1 bis AC-3 gelten auch dort. Belegt durch den unveränderten, grünen
  UI-Test `SpeechDiagnosisLineTests` und Diff-Prüfung.
- **AC-6:** Given `docs/reference/testflight.md` / When der Mac-Abschnitt gelesen wird / Then steht dort, dass in der TestFlight-App
  am Mac oben rechts „macOS“ gewählt werden muss, weil sonst die iOS-Fassung (Mac-Wrapper) ohne Menüleistensymbol installiert wird.
  Belegt durch Diff-Prüfung.
- **AC-7:** Given der Mac-Prüfbau (`./scripts/sim.sh mac`, **nur** nach Hennings wörtlichem „jetzt ist ein Test möglich“) / When das
  Panel unter dem Menüleistensymbol geöffnet wird, mit und ohne Problemzeile (Problemzeile durch Ton ohne erkannten Text, z. B. mit
  deaktivierter Erkennung) / Then sind Text, Pegel, Knöpfe „Abbrechen/Fertig“ und die Fußzeile vollständig sichtbar, die Knöpfe
  überdecken die Fußzeile nie, das Panel ist mit und ohne Zeile gleich hoch, und im Alltag (Panel öffnen, 8 s schweigen) erscheint
  keine Diagnosezeile. Belegt durch Desktop-Screenshots in **hell und dunkel**, jeweils mit und ohne Problemzeile, die geöffnet und
  beschrieben werden (Ablage unter `docs/artifacts/402-menueleiste-layout/`). Kein automatisierter Test (siehe Risiken).
- **AC-8:** Given der Diff / When er geprüft wird / Then berührt er nur die sechs genannten Dateien (Teil A: fünf, Teil B: `testflight.md`),
  nicht `MenuBarCapture.swift`, `SettingsView.swift`, `Shared/`, `project.yml`, Entitlements oder `Info.plist`; kein `try?`, kein
  `print`; und alle bestehenden Tests sind grün.

### Nachgelagert (Gerät, Stufe 3) — kein Prüfpunkt des Gates

Das Gate kennt kein „nachgelagert“ (Memory zu AC-Gate); dieser Punkt steht deshalb hier statt in der AC-Liste und bleibt
verbindlich.

- **Nachgelagert G-1 (#405):** Nur nach Hennings wörtlichem „jetzt ist ein Test möglich“ : Er wählt in der TestFlight-App am Mac
  oben rechts „macOS“, installiert und sieht das Menüleistensymbol der nativen Mac-App. Zeigt sich das nicht, ist die Ursache eine andere als die
  Plattformwahl und #405 wird neu aufgenommen. Der PR verweist mit `Refs #405`, **nicht** `Closes #405`; geschlossen wird erst, wenn Henning
  das Symbol in der Mac-App aus TestFlight gesehen hat. Bis dahin bleibt #405 offen.

## Dependencies

| Komponente | Beschreibung |
|---|---|
| `Waveform` | Pegelskala 0…1 (−55…−25 dBFS); `audibleLevel` liegt auf dieser Skala |
| `LaunchTimings.isProbeBuild(bundleID:)` | Unterscheidung Prüfbau (`.probe`) und Produkt |
| Zeichenkatalog `LooseEnds/Resources/Localizable.xcstrings` | ein neuer Text de/en |
| #401 (Panelhöhe) | Voraussetzung, schon auf main |

Keine neue externe Abhängigkeit.

## Risiken

- **Kein automatisierter Mac-Layout-Test (mittel):** Die Panelhöhe ist nur durch AC-7 (Screenshots, einmalig, nur nach Hennings Wort)
  belegt; eine spätere Regression fängt nichts ab. `MenuBarExtra` ist per XCUITest und im Simulator nicht erreichbar. Vorschlag nur
  falls ohne Mehraufwand möglich: die reservierte Zeilenhöhe als benannte Konstante und kleine reine Höhenregel
  (`Layout.diagnosisLineHeight` ≥ eine `footnote`-Zeile) mit Unit-Test; wird nur gebaut, wenn sie beim Umsetzen ohnehin entsteht.
  Sie würde nicht beweisen, dass das Panel passt, nur dass der Platz reserviert ist.
- **Schwelle `audibleLevel` (niedrig bis mittel):** Der Startwert 0,1 ist nicht am Gerät gemessen. Zu hoch: ein leises Mikrofon löst
  nie aus. Zu niedrig: Rauschen startet die Uhr. Gegenmittel: AC-7 mit echtem Ton; Wert steht an einer Stelle und ist änderbar.
- **Echter Defekt bei Stille (niedrig):** Liefert das Mikrofon nur Stille wegen eines Defekts, bleibt die Zeile stumm. Gewollt laut
  Entscheidung („Schweigen löst nichts aus“); die Pegelanzeige zeigt es weiter.
- **Regel wirkt auch auf iPhone/iPad (niedrig):** Fall W kommt später (ab Ton), Fall B nur im Prüfbau. Gedeckt durch die Freigabe.
- **Nur die Plattformwahl als Ursache von #405 (mittel):** Belegt ist, dass der Mac die iOS-Fassung führt; dass die Auswahl „macOS“
  das Symbol bringt, ist erst mit G-1 belegt; eine Doku-Zeile verhindert das Missverständnis nicht von selbst.
- **Dateigrenze (niedrig):** sechs Dateien, davon eine reine Doku-Datei, siehe Scope.

## Alternativen

- **Diagnose im Panel ganz weglassen**, nur im Fenster oder Prüfbau (ruhigster Alltag, am Mac blind für #274). Verworfen von Henning.
  Gekippt würde die Festlegung aus #274 „Diagnose immer als Text unter dem Pegel“.
- **Diagnose nur als Symbol** neben dem Mikrofon, Text erst bei Klick. Verworfen von Henning.
- **Den Fall W behalten, wie er ist, und nur die Optik beruhigen:** löst das Schweigen-Problem nicht (Fehlalarm bleibt). Verworfen.
- **#405: iOS-Fassung auf dem Mac verbieten** (`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: NO`): in der erzeugten Projektdatei schon NO, daher
  kein Fix. Nicht vorgeschlagen.
- **#405: Hinweiszeile in den Einstellungen der iOS-Fassung** (`isiOSAppOnMac`): wäre sichtbarer, ist aber auf Entscheidung des Tech
  Leads gestrichen (Doku genügt, die Ursache ist die Plattformwahl).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: Reine Regel- und Anzeigeänderung (Zeitbasis der Diagnose, Sichtbarkeit des Berichts, ein Doku-Satz);
  weder Speicherort, Datenmodell, Plattformzuschnitt noch Abgleich ändern sich. Die Festlegung aus #274 (Diagnose als Text) wird für
  den Mac im Alltag zugunsten einer ruhigen Zeile bei Problem angepasst, ohne eine ADR zu kippen.

## Offene Fragen

- Sechste Datei (`testflight.md`) ist reine Doku ohne Code: gesondert zählen? Vorschlag: ja, Code-/Testdateien bleiben bei fünf.
- Startwert von `audibleLevel` (0,1): am Mac mit echtem Ton in AC-7 bestätigen oder anpassen.
- Mac-Layout ohne automatisierten Test akzeptiert? Alternative ohne Mehraufwand ist nur die kleine Höhenregel (siehe Risiken).
- Englischer Wortlaut des neuen Kurztexts (Vorschlag oben) zur Bestätigung.

## Definition of Done

- AC-1 bis AC-6 und AC-8 erfüllt; die neuen Regeltests zuerst rot, dann grün; alle bestehenden Tests grün, auch
  `SpeechDiagnosisLineTests`.
- AC-7 mit Screenshots (hell, dunkel, mit und ohne Zeile) unter `docs/artifacts/402-menueleiste-layout/`, geöffnet und beschrieben,
  nach Hennings wörtlichem „jetzt ist ein Test möglich“.
- #402 schließt der PR von Teil A (`Closes #402`) nach AC-7. Teil B verweist mit `Refs #405`; #405 bleibt offen, bis Henning in der
  Mac-App aus TestFlight das Symbol sieht (G-1).
- Abschlussbericht ohne Git-Vokabular: Das Menüleisten-Feld zeigt im Alltag keine Diagnose mehr, bei echtem Problem eine ruhige Zeile;
  die Doku nennt, dass er am Mac in TestFlight „macOS“ wählen muss.

## Changelog

- 2026-10-13: Initiale Spec für #402 (Teil A) und #405 (Teil B).
- 2026-10-13: Teil B auf reine Doku gekürzt (keine Hinweiszeile, keine Regel, keine Strings).
