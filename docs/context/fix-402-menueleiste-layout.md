# Context: fix-402-menueleiste-layout

## Request Summary
Henning (2026-10-13): Das Erfassen-Feld unter dem Menüleisten-Symbol (Mac) hat verdeckte Knöpfe
(„Abbrechen“/„Fertig“ unter der Fußzeile) und eine dominante dreizeilige Diagnosezeile. Alles soll sichtbar
sein, die Panelhöhe zum Inhalt passen, die Diagnose im Alltag ruhig. Entwurf vorab zur Freigabe.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Mac/MenuBarCapture.swift:10-38` | `MenuBarCaptureView`: `VStack { CaptureView; Divider; Fußzeile }`, nur `.frame(width: 440)` — keine Höhe |
| `LooseEnds/Views/CaptureView.swift:75-130` | Maske: Feld (`lineLimit(3...10)`), `listeningRow`, `Spacer()`, Knöpfe; macOS `.frame(minWidth: 440, minHeight: 240)`; sie liegt in einem `NavigationStack` |
| `LooseEnds/Views/CaptureView.swift:190-205` | Diagnosezeile `Text(diagnosis.text)`, `.footnote`, `fixedSize(vertical: true)`, darf umbrechen |
| `LooseEnds/Speech/SpeechDiagnosis.swift` | Regel `hint`: Fall W = `buffers > 0 && results == 0 && secondsListening >= 6` |
| `LooseEnds/Speech/SpeechCapture.swift:284-310` | `updateDiagnosis` jede Sekunde; `buffers` zählt Ton-Puffer, auch Stille |
| `LooseEnds/App/LooseEndsApp.swift:79-88` | `MenuBarExtra … .menuBarExtraStyle(.window)`: Fenstergröße folgt dem Inhalt |
| `LooseEndsUITests/SpeechDiagnosisLineTests.swift` | bestehender Test der Zeile (iOS-Fixture `--ui-testing-speech-diagnosis`) |

## Existing Patterns
- #356: Panel zeigt dieselbe `CaptureView` wie das Fenster; `onFinish` setzt Knöpfe in die Maske statt in die Toolbar.
- #274: Diagnosezeile grau, reiner Text. #382 beruhigte Feld und Abstände (siehe Ticket), nicht die Höhe.
- Keine Mac-Layout-Tests im Repo (`grep menuBar` in `LooseEndsUITests`: kein Treffer).

## Dependencies
- Upstream: `SpeechCapture` (Zähler, Uhr), `SpeechDiagnosis` (Regel, Text).
- Downstream: `CaptureView` wird auch von iPhone/iPad (Sheet) und Fenster genutzt — Änderungen dort dürfen iOS nicht verschieben.

## Existing Specs
- `docs/specs/…/fix-366-menubar-faden.md` (nur Symbol, unberührt). Keine Spec zum Panel-Layout.

## Risks & Considerations
- **Vermutung, nicht belegt (Layout):** `NavigationStack` + `Spacer` + `minHeight` in einem inhaltsbemessenen `.window`-Panel: die Maske bekommt von der Hülle eine ideale Höhe kleiner als der Inhalt, die Fußzeile überdeckt den Rest. Erst am laufenden Mac nachstellen.
- **Vermutung, nicht belegt (Diagnose):** Fall W löst auch bei **Stille** aus (Puffer kommen immer, Ergebnisse nur bei Sprache). Öffnet man das Panel und schweigt 6 s, erscheint die Zeile obwohl nichts defekt ist. Der Ticket-Satz „nur bei echtem Problem“ hängt daran, ob die Regel Stille von Defekt trennen kann (Pegel liegt in `levels` vor).
- Reproduktion braucht den Mac-Prüfbau (`sim.sh mac`) — Hennings Gerät, nur nach seinem wörtlichen „jetzt ist ein Test möglich“. Simulator zeigt kein `MenuBarExtra`.
- Mac-Stufe 3 greift laut Ticket; `Speech/` steht in der Geräteliste (nur falls die Diagnose-Regel geändert wird).
- Scoping: ≤ 4–5 Dateien, ±250 LoC.

## Analysis

### Type
Bug (Layout, Mac-Panel) + Feature-Anteil (Diagnosezeile beruhigen). Hat es bisher funktioniert? Das Panel kam mit #356; #382 (Abstände, Feldfläche) machte es höher; die Diagnosezeile (#274/#279) gibt es länger. Ein „letzter guter Stand" ist nicht belegt.

### Nachgestellt (2026-10-13, Mac-Prüfbau, Henning „jetzt ist ein Test möglich")
- `docs/artifacts/402-menueleiste-layout/heute-ohne-diagnose.png` (Desktop-Screenshot 16:50:30): direkt nach dem Öffnen. Knöpfe „Abbrechen/Fertig" sitzen unmittelbar über der Trennlinie der Fußzeile, kein Abstand unten.
- `docs/artifacts/402-menueleiste-layout/heute-mit-diagnose.png` (Bild aus Aufnahme, 16:49): nach etwa 8 s Schweigen erscheint die Diagnose („Erster Text nach 7,8 s · Start: 0,5 s (Öffnen … Mikrofon 0,2)", zwei Zeilen). Das Panel ist nicht mitgewachsen: „Abbrechen/Fertig" liegen über „Loose Ends beenden" und überdecken die Fußzeile.

### Ursache (belegt durch Aufnahme + Recherche)
1. **Panelhöhe wächst nicht mit.** `.menuBarExtraStyle(.window)` bemisst das Fenster beim ersten Layout. Nachträglich hinzukommende Zeilen (Diagnose, Hinweis) vergrößern es nicht; bekannter Fehler, Workaround `.fixedSize(vertical: true)` am Inhalt (Apple-Forum 741601, 741553). `CaptureView` hat auf macOS `minHeight: 280`, `Spacer()` und `NavigationStack`; die Hülle bekommt dadurch keine verlässliche Idealhöhe.
2. **Diagnose löst bei Schweigen aus.** Die sichtbare Zeile in der Aufnahme ist Fall B (`results > 0`, `firstResult >= 6 s`): `firstResult` zählt ab Zuhörbeginn, nicht ab erstem Sprechen. Wer das Panel öffnet und erst nach 7 s spricht, bekommt einen „Bericht" über einen Defekt, den es nicht gibt. Fall W (`buffers > 0`, `results == 0` nach 6 s) trennt Stille ebenfalls nicht von Defekt (Puffer kommen immer).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Mac/MenuBarCapture.swift` | MODIFY | Hülle: `.fixedSize(horizontal: false, vertical: true)`, Fußzeile mit festem Abstand |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | macOS: `Spacer`/`minHeight` im Panel nicht mehr dehnen; Diagnose ruhiger (eine Zeile, `lineLimit`, Detail als Tooltip) |
| `LooseEnds/Speech/SpeechDiagnosis.swift` | MODIFY (je nach Entwurf) | Regel: Zeit ab erstem Pegel statt ab Zuhörbeginn; Bericht Fall B nicht im Alltag |
| `LooseEndsTests/SpeechDiagnosisTests.swift` | MODIFY | neue Regelfälle (Schweigen ≠ Defekt) |
| `LooseEndsUITests/` (Mac) | CREATE | Layout-Test Panelhöhe (siehe Offene Fragen) |

### Scope Assessment
- Files: 4–5, LoC ca. +120/−30. Risk: MITTEL (CaptureView wird auch von iPhone/iPad genutzt; Änderungen nur unter `#if os(macOS)`; Regeländerung in `Speech/` löst Stufe 3 aus).

### Technical Approach
Regelweg zuerst (ohne Modell, Henning 2026-09-20): reine Layout- und Schwellwertregeln, kein Modell. Empfehlung: Panel mit `fixedSize(vertical:)` und reservierter Diagnosehöhe (Panel springt nie), Diagnose als eine graue Zeile „Kein Text erkannt — Details" mit Tooltip; Regel zählt die 6 s ab dem ersten Pegel über Schwelle (`levels`).
**Alternative A:** Diagnose im Panel ganz weglassen, nur im Fenster/Prüfbau (ruhigster Alltag, aber #274 auf dem Mac blind). **Alternative B:** Diagnose als Symbol (Ausrufezeichen, SF Symbol) neben dem Mikrofon, Text erst bei Klick. Gekippt würde jeweils die Festlegung aus #274 „Diagnose immer als Text unter dem Pegel".

### Dependencies
`SpeechCapture.updateDiagnosis` ruft `SpeechDiagnosis.hint` jede Sekunde; `CaptureView` iOS unverändert halten.

### Open Questions
- [ ] Entwurf: welche der drei Diagnose-Varianten (Eine Zeile / Symbol / nur Fenster)?
- [ ] Mac-Layout-Test: `MenuBarExtra` ist per XCUITest schwer erreichbar. Vorschlag: reine Höhenregel als Unit-Test plus UI-Test der Maske in einem Fenster mit Panelmaßen.

### Entscheidung (Henning, 2026-10-13)
Entwurf freigegeben: Variante „Eine Zeile bei Problem“. Panel immer gleich hoch, unten mit Abstand; im Alltag keine Diagnose; bei Problem eine graue Zeile mit Symbol, Einzelwerte im Hinweis; Regel zählt ab dem ersten hörbaren Pegel, Schweigen löst nichts aus. Vorschau: `docs/artifacts/402-menueleiste-layout/index.html` (veröffentlicht: https://claude.ai/artifact/7f8Ej5Cs82azki89wc8V5Q). Verworfen: Diagnose nur im Fenster, nur Symbol.
Abnahme: Mac-Stufe 3 (Layout) und `Speech/` (Regel) greifen; Prüfbau-Test nur nach Hennings Wort. Der Prüfbau ist beendet.

## #405 (Menüleistensymbol fehlt, Henning: mit #402 mitreparieren, ohne eigenen Workflow)

Nachgestellt/untersucht am 2026-10-13 18:51 auf Hennings Mac (nach „jetzt ist ein Test möglich“, nur lesend):
- `/Applications/Loose Ends.app` (installiert 16:23) enthält `WrappedBundle -> Wrapper/LooseEnds.app`: das ist die **iOS-App, die auf dem Mac läuft** („Designed for iPhone/iPad“), keine native Mac-App. Der Quelltext des Symbols steht unter `#if os(macOS)`, die iOS-Fassung hat darum kein Menüleistensymbol.
- Die TestFlight-App auf dem Mac zeigt LooseEnds 0.1.0 (55), 3,7 MB, mit Plattformwahl „iOS ▾“ oben rechts. Der Lauf Build 55 hat den macOS-Bau hochgeladen und Apple meldete ihn `VALID` (Jobs „upload-mac“, „confirm-mac“ grün). Ob die Auswahl auch „macOS“ anbietet, ist noch nicht gesehen (Klick wurde abgelehnt).
- Der Quelltext-Unterschied Build 53 → 55 ist nur `MenuBarCapture.swift` (6 Zeilen, #401); er erklärt nichts.
- Auf dem Mac ist außerdem „Hidden Bar“ installiert (blendet Menüleistensymbole aus); als Nebenursache nicht ausgeschlossen, aber für die iOS-Fassung ohne Belang.
- Ursache (belegt für den Teil „keine native Mac-App installiert“): Hennings Mac führt die iOS-Fassung. Offen: warum nicht die macOS-Fassung — Plattformwahl in TestFlight auf „iOS“ gelassen, oder macOS-Bau der Gruppe nicht zugewiesen (App Store Connect, für mich nicht lesbar).
- Alternative zum bisherigen Weg (ADR „ein Ziel, alle Plattformen“): iOS-App auf dem Mac gar nicht zulassen (`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: NO` in `project.yml`), dann bietet TestFlight am Mac nur die native Fassung an und das Missverständnis kann nicht mehr entstehen.
