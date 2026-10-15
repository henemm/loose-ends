---
entity_id: fix-409-watch-reset
type: bugfix
created: 2026-10-15
updated: 2026-10-15
status: draft
workflow: fix-409-watch-reset
---

# Spec: #409 Watch-Erfassung kehrt nach „Fertig“ zum leeren Feld zurück

## Approval

- [ ] Approved

## Purpose

Auf der Apple Watch bleibt die Erfassung nach „Fertig“ dauerhaft auf Häkchen und „Gespeichert“ stehen; eine zweite
Aufgabe geht erst nach einem Neustart der App (Henning, TestFlight-Build 57). Nach dieser Änderung zeigt die Watch das
Häkchen mit „Gespeichert“ etwa 1,5 s und danach von selbst das leere Feld „Ich höre zu“, ohne zusätzlichen Tipp. Henning
nennt die Anzeige „Gesichert“; gemeint ist derselbe Text „Saved“ / „Gespeichert“, er bleibt unverändert. Der Regelweg
genügt trivial: zwei Zuweisungen und ein Zeitablauf, ein Modell kommt nicht vor.

**Hat es bisher funktioniert?** Nein. Das Verhalten besteht seit dem Grundgerüst (#1), es ist keine Verschlechterung;
es fällt seit der Komplikation (#355) häufiger auf (Adversary-Finding F006).

## Source

- **Dateien:** `LooseEndsWatch/WatchCaptureView.swift`, `LooseEndsWatchUITests/WatchCaptureUITests.swift` (neu),
  `project.yml`, `scripts/sim.sh`
- **Ticket:** #409 (Henning zu TestFlight-Build 57, 2026-10-14; Entscheidung für einen Watch-UI-Test statt einer reinen
  Zustandsregel am 2026-10-15)
- **Analyse:** `docs/context/fix-409-watch-reset.md` (Root Cause, Nachstellung, Alternativen)
- **Nachstellung (2026-10-15, watchOS-27.0-Simulator „Apple Watch Series 12 (46mm)“):** Text „Milch kaufen“ → „Fertig“ →
  Häkchen und „Gespeichert“; 4 s später unverändert, das Eingabefeld existiert nicht mehr. Belege:
  `docs/artifacts/fix-409-watch-reset/repro-1-text-eingegeben.png`, `repro-2-gespeichert-nach-4s.png`;
  Spike-Testcode: `docs/artifacts/fix-409-watch-reset/spike-WatchSpikeUITests.swift.txt`.
- **Root Cause:** `WatchCaptureView.swift:37` setzt `saved = true`; nichts setzt es zurück, und `text` wird nie
  geleert. Im Zustand `saved` ist das Feld nicht im Baum, die Ansicht hat keinen Rückweg.

## Recherche (Quellen)

- XCUITest unterstützt watchOS seit Xcode 12.5; ältere Aussagen „nicht unterstützt“ sind veraltet. Quellen:
  https://github.com/evnik/XcodeRN/blob/master/Xcode12.5Beta3.md , https://developer.apple.com/forums/thread/678201
- Forenangabe, ein SwiftUI-`TextField` erscheine auf watchOS nur unter `otherElements` (FB9983700,
  https://developer.apple.com/forums/thread/704295): gilt auf watchOS 27 nicht mehr, im Probelauf liegt es unter
  `app.textFields`. Elemente werden trotzdem per `accessibilityIdentifier` gesucht, weil zwei Knöpfe „Fertig“ heißen
  (Eingabeblatt und App) und die Simulatorsprache die Texte ändert (Falle aus #193).
- Hängender Watch-Testläufer: wirksamster Ausweg ist, die Watch-App vor jedem Lauf im Simulator zu deinstallieren
  (https://developer.apple.com/forums/thread/805060); im Probelauf liefen drei von drei Läufen an.

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `CaptureService.save(_:via:in:)` (`Shared/Services`) | Bestehender Code | Sichern; wirft im Fehlerfall; bleibt unverändert |
| `ModelContainerFactory.make()` (`Shared/Persistence`) | Bestehender Code | Unter `--ui-testing` In-Memory-Store ohne CloudKit, gilt auch auf der Watch; kein Eingriff |
| `LooseEndsWatch/LooseEndsWatchApp.swift` | Nachbar | Einzige Szene `WatchCaptureView`; Komplikation und Siri öffnen dieselbe Ansicht |
| `LooseEnds/Resources/Localizable.xcstrings` | Bestehender Code | Texte „Saved“, „I'm listening“, „Done“, „Could not save“; unverändert |
| `scripts/sim_proof.py` | Bestehender Code | Maschineller Simulator-Beleg für `test-proof` (#145) |
| XCUITest auf watchOS | Framework | Watch-UI-Testziel mit Host `LooseEndsWatch` |

## Scope

### Affected Files

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `LooseEndsWatch/WatchCaptureView.swift` | MODIFY (~+15/−3) | Nach erfolgreichem Sichern `text = ""`; Bestätigung 1,5 s über `.task(id: saved)` mit `Task.sleep` (Abbruch = kein Wechsel), danach `saved = false`; `accessibilityIdentifier` für Feld, Fertig-Knopf und Bestätigung. Fehlerfall unverändert. |
| `LooseEndsWatchUITests/WatchCaptureUITests.swift` | CREATE (~+50) | Zwei Erfassungen hintereinander im watchOS-Simulator; vor dem Fix rot. |
| `project.yml` | MODIFY (~+22) | Ziel `LooseEndsWatchUITests` (watchOS, `TEST_TARGET_NAME: LooseEndsWatch`), Schema `LooseEndsWatch`. |
| `scripts/sim.sh` | MODIFY (~+30) | Watch-Simulatorwahl nach watchOS-Laufzeit ≥ Target (wie `sim_id` für iOS), App vor dem Lauf deinstallieren, `test-proof`-Weg für die Watch über `sim_proof.py`. |

### Estimated Changes

- Files: 4 (innerhalb von 4–5)
- LoC: ca. +120/−5 (unter 250); keine Funktion über 50 Zeilen

### Nicht Teil dieser Spec

- **CI-Job für Watch-UI-Tests:** läuft vorerst nur lokal über `sim.sh`; eigenes Issue.
- **Textänderung „Gespeichert“ → „Gesichert“:** der Text bleibt unverändert.
- **Auto-Fokus ins Diktat nach dem Reset:** nicht gefordert, wird nicht erfunden (kein öffentlicher Weg, siehe #355).
- Kein Testhaken in der App (kein Startargument, das einen Speicherfehler auslöst oder Text vorbelegt).
- Keine Regeldatei in `Shared/` (`WatchCaptureFlow` des Vorgänger-Workflows entfällt).

## Implementation Details

Der Zustand bleibt in der Ansicht (`text`, `saved`). `save()` ruft `CaptureService.save` wie bisher; nur im Erfolgsfall
wird `text = ""` gesetzt und `saved = true`. Im Fehlerfall bleibt alles wie heute: `saveFailed` zeigt den Alert „Could
not save“, `text` bleibt stehen, `saved` bleibt `false`.

Die Bestätigung hängt an `.task(id: saved)`: Wechselt `saved` auf `true`, schläft die Aufgabe 1,5 s mit `Task.sleep` und
setzt dann `saved = false`. Das Feld erscheint wieder, leer, mit dem Platzhalter „I'm listening“ („Ich höre zu“). Senkt
Henning das Handgelenk während der 1,5 s (App inaktiv oder im Hintergrund), bleibt die Ansicht im Baum und die Aufgabe
bestehen; wird der Prozess angehalten, endet der Schlaf beim Weiterlaufen (Frist verstrichen) und der Reset folgt
spätestens beim Zurückkommen — die App bleibt nicht auf „Gespeichert“ hängen. Wird die Ansicht tatsächlich abgebaut,
bricht SwiftUI die Aufgabe ab (`Task.sleep` wirft `CancellationError`, kein Wechsel); mit der Ansicht verschwindet auch
ihr `@State`, ein Neuaufbau beginnt mit leerem Feld. Ein abgebrochener Lauf löst keinen zweiten Reset aus, weil nur ein
erfolgreich beendeter Schlaf zurücksetzt und die Aufgabe pro Wert von `saved` genau einmal läuft. Kein `DispatchQueue`-Timer, Swift 6 strict concurrency bleibt erfüllt.

Identifikatoren: `watch.capture.field` (Eingabefeld), `watch.capture.done` (App-Knopf „Fertig“),
`watch.capture.saved` (Häkchen/„Gespeichert“). Der Knopf „Fertig“ des System-Eingabeblatts hat keinen eigenen
Identifikator; der Test unterscheidet ihn über seine Lage in der Navigationsleiste (`app.navigationBars.buttons`),
wie im Spike erprobt.

**Test (Aufbau).** Das Ziel `LooseEndsWatchUITests` startet `LooseEndsWatch` mit `--ui-testing` (In-Memory-Store).
`sim.sh` wählt einen watchOS-Simulator mit Laufzeit ≥ Deployment Target, deinstalliert die Watch-App vor dem Lauf (gegen
den hängenden Läufer) und reicht `test-proof` für die Watch an `sim_proof.py`. Der Beleg-Lauf nutzt eigene
`CLAUDE_SESSION_ID`/`LOOSEENDS_SIM` und das Lock `/tmp/loose-ends-testlauf.lock`.

Reihenfolge (TDD): Testziel, Schema und `sim.sh`-Weg anlegen; Test gegen den unveränderten Code rot sehen (Feld nach
„Gespeichert“ nie wieder da, kein Kompilierfehler); dann `WatchCaptureView` ändern und grün sehen.

## Test Plan

### Automated Tests (TDD RED)

Neue Datei `LooseEndsWatchUITests/WatchCaptureUITests.swift` (XCTest, watchOS-Simulator).

- [ ] Test 1: `testTwoCapturesInARowReturnToEmptyField` — GIVEN die Watch-App läuft mit `--ui-testing` und zeigt das
  leere Feld / WHEN „Milch kaufen“ getippt, im Eingabeblatt „Fertig“ und dann im App-Knopf `watch.capture.done` getippt
  wird / THEN erscheint `watch.capture.saved`, und spätestens nach 5 s ist `watch.capture.saved` weg und
  `watch.capture.field` wieder da, mit leerem Inhalt (Wert ist der Platzhalter, „Milch kaufen“ steht nicht mehr da).
  Danach GIVEN dasselbe leere Feld / WHEN „Brot holen“ ohne weiteren Tipp auf etwas anderes erfasst wird / THEN
  erscheint wieder `watch.capture.saved` und danach wieder das leere Feld. Vor dem Fix rot (das Feld kommt nach der
  ersten Bestätigung nie wieder).
- [ ] Test 2: `testConfirmationIsVisibleBeforeFieldReturns` — GIVEN eine eben gesicherte Aufgabe / WHEN unmittelbar nach
  dem Tipp auf „Fertig“ geprüft wird / THEN ist `watch.capture.saved` vorhanden und `watch.capture.field` noch nicht
  (kurze Bestätigung, kein sofortiges Leeren ohne Anzeige).

Beide Tests bestehen nur, wenn „Gespeichert“ erscheint; das geschieht nur nach erfolgreichem `CaptureService.save`
(sonst Alert). Damit gilt „beide Aufgaben gespeichert“ ohne Testhaken. Bestehende Läufe: `./scripts/sim.sh unit` und die
iOS-UI-Tests bleiben grün; `test_entitlements_sync.py` und `test_ci_xcode27.py` bleiben grün (`project.yml` ändert sich).

## Abnahme

- **Stufe 1:** `WatchCaptureUITests` erst rot, dann grün; `./scripts/sim.sh unit`; die Skripttests.
- **Stufe 2:** `./scripts/sim.sh generate`, Watch-Bau und iOS-Bau (`./scripts/sim.sh build`), `test-proof
  WatchCaptureUITests` mit maschinellem Beleg; Screenshots des Ablaufs im Simulator (Bestätigung, danach leeres Feld),
  geöffnet und beschrieben.
- **Stufe 3 greift** (`LooseEndsWatch/` und `project.yml` stehen auf der Geräteliste): Gerätepunkt über TestFlight in
  Hennings normaler App — Merge, TestFlight-Bau mit „Was testen“-Text auf Deutsch, dann Buildnummer und Prüfschritte.
  **Nichts auf seinen Geräten ohne sein wörtliches „jetzt ist ein Test möglich“.** Keine Modelländerung, daher kein
  `mac-schema-init`.
- Der Abschluss nach Stufe 2 ist nicht möglich; das Ticket bleibt offen, bis Henning den Gerätepunkt bestätigt.

## Acceptance Criteria

- **AC-1:** Bestätigung, dann leeres Feld — Nach erfolgreichem Sichern zeigt die Watch-Erfassung das Häkchen mit
  „Gespeichert“ (englisch „Saved“, Text unverändert) etwa 1,5 s, danach das leere Feld „Ich höre zu“; der vorige Text ist
  weg, ohne zusätzlichen Tipp. Nachweis: UI-Test `WatchCaptureUITests::testTwoCapturesInARowReturnToEmptyField`
  (Wartezeit ≤ 5 s), davor nachweislich rot; Screenshots über `test-proof`.
- **AC-2:** Bestätigung sichtbar — Direkt nach „Fertig“ ist die Bestätigung da und das Feld noch nicht. Nachweis:
  UI-Test `WatchCaptureUITests::testConfirmationIsVisibleBeforeFieldReturns`.
- **AC-3:** Zweite Aufgabe direkt erfassbar — Nach dem Reset lässt sich ohne Neustart und ohne Zusatzschritt eine zweite
  Aufgabe erfassen; beide wurden gesichert, belegt dadurch, dass „Gespeichert“ je Erfassung erscheint (nur nach
  erfolgreichem `CaptureService.save`). Nachweis: UI-Test `WatchCaptureUITests::testTwoCapturesInARowReturnToEmptyField`
  (zwei Durchläufe in einem Test).
- **AC-4:** Fehlerfall unverändert — Schlägt `CaptureService.save` fehl, erscheint der Alert „Could not save“, der Text
  bleibt im Feld stehen, es gibt keine Bestätigung und keinen Reset. Nachweis: Code-Review und Adversary an
  `WatchCaptureView.swift` (Reset nur im Erfolgszweig); im UI-Test nicht auslösbar ohne Testhaken, und ein Testhaken
  kommt nicht in die App.
- **AC-5:** Hintergrund während der 1,5 s — Geht die App während der Bestätigung in den Hintergrund, bleibt sie beim
  Zurückkommen nicht auf „Gespeichert“ hängen: die Aufgabe von `.task(id: saved)` läuft weiter bzw. endet nach dem
  Anhalten mit verstrichener Frist und setzt zurück; wird die Ansicht abgebaut, beginnt sie neu mit leerem Feld; ein
  abgebrochener Lauf löst keinen zweiten Reset aus. Nachweis: Code-Review und Adversary (Lebenszyklus der
  Aufgabe, `Task.sleep` mit Abbruchbehandlung); Gerätepunkt in AC-8.
- **AC-6:** Kein Auto-Fokus — Nach dem Reset öffnet sich kein Eingabeblatt und kein Diktat von selbst; das Feld wartet
  auf den Tipp. Nachweis: UI-Test (nach dem Reset ist das Feld da, kein Eingabeblatt sichtbar,
  `app.navigationBars.buttons` ohne Blatt-„Fertig“) und Code-Review.
- **AC-7:** Testaufbau — `project.yml` führt das Ziel `LooseEndsWatchUITests` (watchOS, `TEST_TARGET_NAME:
  LooseEndsWatch`) und das Schema `LooseEndsWatch`; `./scripts/sim.sh` wählt einen watchOS-Simulator mit Laufzeit ≥
  Target, deinstalliert die Watch-App vor dem Lauf, und `test-proof` für die Watch erzeugt den Beleg über
  `sim_proof.py`. Nachweis: Diff, ein grüner `test-proof`-Lauf mit Beleg; `test_entitlements_sync.py` und
  `test_ci_xcode27.py` grün.
- **AC-8:** Gerätepunkt (Stufe 3, TestFlight, wird nach dem Merge geschlossen) — Auf Hennings Watch zeigt die Erfassung
  nach „Fertig“ kurz „Gespeichert“ und danach das leere Feld „Ich höre zu“; eine zweite Aufgabe lässt sich direkt
  erfassen; beide sind gespeichert. Nachweis: Hennings Rückmeldung zum TestFlight-Bau (Buildnummer und Prüfschritte nach
  seinem „jetzt ist ein Test möglich“); bis dahin bleibt das Ticket offen.
- **AC-9:** Bestehendes bleibt grün — `./scripts/sim.sh unit` und die vorhandenen iOS-UI-Tests bestehen. Nachweis:
  Lauf-Ausgaben.

## Known Risks

1. **Hängender Watch-Testläufer.** Im Probelauf trat er nicht auf (drei von drei Läufen, mit Deinstallation vorab).
   Tritt er doch auf, wird der Weg in `sim.sh` repariert, nicht übersprungen.
2. **Watch-Bau mit `CODE_SIGNING_ALLOWED=NO`.** Das Watch-Target hängt als eingebettete App am iOS-Bau; der Probelauf
   baute es eigenständig für den Watch-Simulator, ein Fehler zeigt sich beim Bau sofort.
3. **Zeitabhängiger Test.** 1,5 s plus Toleranz (Wartezeit ≤ 5 s); Prüfung per `waitForExistence`, nie per `sleep`.
4. **Parallele Sitzungen** teilen Simulator und DerivedData: eigene `CLAUDE_SESSION_ID`/`LOOSEENDS_SIM`, Lock beachten.
5. **Kein CI-Beleg.** Der Watch-UI-Test läuft nur lokal; ein CI-Job ist ein eigenes Issue.

## Alternativen

- **Gewählt: Zustand in der Ansicht, `.task(id: saved)`, UI-Test im Watch-Simulator.** 4 Dateien, Nachweis über den
  echten Ablauf, wie Henning ihn am 2026-10-15 gewählt hat.
- **Regel in `Shared/` mit Unit-Test, UI-Test zusätzlich** (Vorgänger-Spec `fix-409-watch-ruecksprung`): 6 Dateien,
  sprengt das Dateilimit; die Regel ist zwei Zuweisungen, der Unit-Test belegt nichts, was der UI-Test nicht belegt.
- **Nur Regel und TestFlight, kein UI-Test** (Hennings Wahl vom 2026-10-14, weil der Läufer damals hing): überholt, der
  Läufer startet nachweislich.
- **Sofort leeren mit Haptik, ohne Zeitablauf:** schneller, aber ohne sichtbare Bestätigung; Henning will etwa 1,5 s
  „Gespeichert“.
- **Regel vor Modell:** nicht berührt; Zuweisungen und ein Zeitablauf, nichts zu verstehen.

## Definition of Done

- [ ] AC-1 bis AC-7 und AC-9 erfüllt und belegt (Stufen 1 und 2); AC-8 nach Hennings Rückmeldung zum TestFlight-Bau
- [ ] `WatchCaptureUITests` davor rot, danach grün; `test-proof` mit maschinellem Beleg; `./scripts/sim.sh unit` grün;
  Build erfolgreich, jeder Commit kompiliert
- [ ] Auf Hennings Watch: kurz „Gespeichert“, dann leeres Feld, zweite Aufgabe direkt erfassbar
- [ ] CI grün; TestFlight-Bau mit „Was testen“-Text auf Deutsch (Aufgabe diktieren, Fertig, kurz Häkchen, dann leeres
  Feld, zweite Aufgabe)
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
- [ ] Folgeticket für einen CI-Job der Watch-UI-Tests angelegt; Vorgänger-Workflow `fix-409-watch-ruecksprung` aufgegeben

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — Grund: Verhaltenskorrektur einer Ansicht plus Testziel nach bestehendem Muster, keine
Architekturentscheidung.

- **Rationale:** Zwei Zuweisungen und ein `.task(id:)` in einer SwiftUI-Ansicht, ein Watch-UI-Testziel analog zu
  `LooseEndsUITests`. Keine neue Schicht, keine Daten- oder Berechtigungsänderung, keine ADR gekippt.

## Changelog

- 2026-10-15: Initial spec created (Zustand in der Ansicht, Watch-UI-Test mit zwei Erfassungen; löst den Vorgänger-Workflow
  `fix-409-watch-ruecksprung` ab).
