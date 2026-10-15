# Context: fix-409-watch-reset

## Request Summary
Nach „Fertig“ bleibt die Watch-Erfassung dauerhaft auf „Gesichert“; eine zweite Aufgabe geht nur nach Neustart der App
(Henning, TestFlight-Build 57, 2026-10-14). Gewünscht: etwa 1,5 s „Gesichert“, dann automatisch das leere Feld
„Ich höre zu“. Nachweis per watchOS-UI-Test mit zwei Erfassungen hintereinander (Henning wählte am 2026-10-15 den
Aufbau eines Watch-UI-Tests statt einer reinen Zustandsregel).

**Hat es bisher funktioniert?** Nein. Das Verhalten besteht seit dem Grundgerüst (#1); es ist keine Verschlechterung
durch #355, fällt aber seit der Komplikation öfter auf (Adversary-Finding F006 in #355 Schnitt 3a).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsWatch/WatchCaptureView.swift` | Ursache: `save()` setzt `saved = true` (Z. 37), nichts setzt es zurück, `text` wird nie geleert. Fehlerfall: `saveFailed` → Alert „Could not save“, Text bleibt. |
| `LooseEndsWatch/LooseEndsWatchApp.swift` | Einstieg: `ModelContainerFactory.make()`, eine `WindowGroup` mit `WatchCaptureView`. Keine eigenen Startargumente. |
| `Shared/Persistence/ModelContainerFactory.swift` | `make()` liefert unter `--ui-testing` (Z. 46–48, 77–79) bereits einen In-Memory-Store ohne CloudKit — gilt auch für die Watch, ein UI-Test berührt keine echten Daten. |
| `Shared/Services/CaptureService.swift` | `CaptureService.save(_:via:in:)` — speichert und wirft im Fehlerfall; unverändert. |
| `LooseEnds/Resources/Localizable.xcstrings` | Deutsche Texte (geprüft): „Saved“ → „Gespeichert“ (Ticket und Henning sagen „Gesichert“ — gemeint ist dieselbe Anzeige, Text bleibt), „I'm listening“ → „Ich höre zu“, „Done“ → „Fertig“, „Could not save“ → „Konnte nicht sichern“. Die Watch kompiliert diese Datei mit (project.yml Z. 117–123). |
| `project.yml` | Targets `LooseEndsWatch` (Z. 111ff.), `LooseEndsUITests` (Z. 310ff., nur iOS/macOS, Host `LooseEnds`), Schema `LooseEnds` (Z. 324ff.). Ein Watch-UI-Testziel und ein Schema dafür fehlen. Steht auf der Geräteliste. |
| `scripts/sim.sh` | `sim_id()` (Z. 96–115) findet nur iOS-Laufzeiten; `test`/`test-proof` (Z. 305–357) laufen nur gegen `platform=iOS Simulator`. Kein Watch-Weg. `test-proof` erzeugt den maschinellen Beleg über `scripts/sim_proof.py`. |
| `.github/workflows/ci.yml` | UI Smoke nur auf iPhone 17 / iOS 27.0 (~53–62 Min). Kein Watch-Job. |
| `docs/specs/intents/feat-355-s3-komplikation.md` | Komplikation öffnet die Watch-Erfassung per Tipp; dort F006 als Folgefund. |

## Existing Patterns
- UI-Tests starten die App mit `--ui-testing` (In-Memory-Store, Onboarding aus) — für die Watch wiederverwendbar.
- Zeitgesteuerte UI-Rückkehr gibt es bisher nicht in der Watch; in iOS-Views wird mit `Task { try await Task.sleep … }`
  bzw. `.task(id:)` gearbeitet (Swift 6 strict concurrency, kein `DispatchQueue`-Timer nötig).
- `test-proof <Klasse>` ist der verpflichtende maschinelle Simulator-Beleg (#145) — bislang nur iOS.
- Texte im Code englisch, Übersetzung über `Localizable.xcstrings`; UI-Tests laufen in der Simulatorsprache
  (Falle aus #193: deutscher Dialogtitel) — Elemente besser per `accessibilityIdentifier` finden.

## Dependencies
- Upstream: `CaptureService`, `ModelContainerFactory`, `AppVersion`, SwiftData-Umgebung.
- Downstream: Komplikation (`LooseEndsWatchWidgets`) und Siri-Kurzbefehl öffnen dieselbe Ansicht; keine anderen Nutzer.

## Recherche (2026-10-15)
- XCUITest unterstützt watchOS seit Xcode 12.5 (`XCUIApplication` auf der Watch);
  ältere Quellen sagen „nicht unterstützt“ — veraltet.
  Quellen: [Xcode 12.5 Release Notes (Spiegel)](https://github.com/evnik/XcodeRN/blob/master/Xcode12.5Beta3.md),
  [Apple Forum 678201](https://developer.apple.com/forums/thread/678201).
- SwiftUI-`TextField` erscheint auf watchOS nicht unter `app.textFields`, sondern unter `app.otherElements`
  (FB9983700). Quelle: [Apple Forum 704295](https://developer.apple.com/forums/thread/704295).
- Ungeklärt: Ob `typeText` in das systemseitige Texteingabe-Sheet der Watch tippen kann. Ein Tipp aufs Feld öffnet
  dort Diktat/Kritzeln/Tastatur — das muss die Analyse im Simulator klären. Ausweg, falls nicht: ein Startargument nur
  unter `--ui-testing`, das den Text vorbelegt (Prüfhaken statt Tippen).
- Kommandozeilenläufe für Watch-UI-Tests melden in Foren gelegentlich „unable to find destination“; Ziel muss
  `platform=watchOS Simulator,id=…` mit watchOS-27.0-Laufzeit sein (vorhanden: Apple Watch Series 11, watchOS 27.0).

## Existing Specs
- `docs/specs/intents/feat-355-s3-komplikation.md` — Komplikation, F006.
- `docs/specs/intents/feat-355-s1-siri-saetze-watch.md` — Siri auf der Watch.

## Risks & Considerations
- **Testaufbau ist der größere Teil:** neues Testziel (watchOS, Host `LooseEndsWatch`), eigenes Schema, `sim.sh` braucht
  Watch-Simulatorwahl und einen Watch-Weg für `test-proof`. Scoping-Limit (4–5 Dateien, ±250 LoC) im Blick behalten;
  ein CI-Job für die Watch wäre eher ein eigenes Ticket.
- **Watch-Target hängt am iOS-Bau** (`platformFilter: iOS` als eingebettete App): ein Watch-UI-Test baut die Watch-App
  eigenständig für den Watch-Simulator — prüfen, dass das mit `CODE_SIGNING_ALLOWED=NO` und den Entitlements
  (App-Gruppe, CloudKit, Siri) geht; `ModelContainerFactory` fällt ohne App-Gruppe auf lokalen Store zurück, unter
  `--ui-testing` ohnehin In-Memory.
- **Zeitsteuerung:** Die App kann während der 1,5 s in den Hintergrund gehen (Handgelenk gesenkt). Beim Zurückkommen
  darf sie nicht auf „Gesichert“ hängen bleiben. Ein abgebrochener Timer darf keinen zweiten Reset auslösen.
- **Fehlerfall unverändert:** Alert „Could not save“, Text bleibt stehen, kein Reset.
- **Diktat:** Ob das Feld nach dem Reset automatisch wieder ins Diktat springt, ist nicht gefordert („leeres Feld
  ‚Ich höre zu‘“) — kein Auto-Fokus erfinden.
- **Stufe 3:** `LooseEndsWatch/` und `project.yml` stehen auf der Geräteliste → Gerätepunkt über TestFlight nach dem Merge.
- **Parallele Sitzungen:** teilen Simulator und DerivedData; eigene `CLAUDE_SESSION_ID`/`LOOSEENDS_SIM`, Lock
  `/tmp/loose-ends-testlauf.lock` beachten.

## Analysis

### Type
Bug (besteht seit #1, keine Verschlechterung).

### Nachgestellt (2026-10-15, watchOS-27.0-Simulator „Apple Watch Series 12 (46mm)“)
Probelauf in einer Wegwerf-Kopie mit vorläufigem Watch-UI-Testziel (Testcode:
`docs/artifacts/fix-409-watch-reset/spike-WatchSpikeUITests.swift.txt`):
- **Der Watch-Testläufer startet hier.** Drei Läufe, je ~75 s Bau + Test, alle angelaufen. Der „test runner hung“ des
  Vorgängers (fix-409-watch-ruecksprung, 2026-10-14) trat nicht auf; vor jedem Lauf wurde die Watch-App im Simulator
  deinstalliert (wirksamster Ausweg laut https://developer.apple.com/forums/thread/805060).
- **Tippen geht:** Das SwiftUI-`TextField` erscheint auf watchOS 27 unter `app.textFields` (die Forenangabe FB9983700
  „nur otherElements“ gilt hier nicht mehr). Tipp öffnet das System-Eingabeblatt (`TextInputHost`, Tastatur), `typeText`
  schreibt hinein, Blatt-Knopf „Fertig“ (`app.navigationBars.buttons`, zweiter) übernimmt den Text ins Feld. Kein
  Startargument zum Vorbelegen nötig.
- **Fehler ausgelöst:** Text „Milch kaufen“ → App-Knopf „Fertig“ → Häkchen + „Gespeichert“; 4 s später unverändert,
  `app.textFields.firstMatch.exists == false`. Belege: `docs/artifacts/fix-409-watch-reset/repro-1-text-eingegeben.png`,
  `repro-2-gespeichert-nach-4s.png` (angesehen: Feld mit „Milch kaufen“; danach nur Häkchen und „Gespeichert“).
- Falle: Zwei Knöpfe heißen „Fertig“ (Eingabeblatt und App). Im Test per `accessibilityIdentifier` trennen.

### Root Cause
`LooseEndsWatch/WatchCaptureView.swift:37` setzt `saved = true`; nichts setzt es zurück und `text` wird nie geleert. Im
Zustand `saved` ist das Feld nicht im Baum, die Ansicht hat keinen Rückweg.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsWatch/WatchCaptureView.swift` | MODIFY | Nach erfolgreichem Sichern `text = ""`, Bestätigung 1,5 s über `.task(id: saved)` mit `Task.sleep` (Abbruch = kein Wechsel), dann `saved = false`; `accessibilityIdentifier` für Feld, Knopf, Bestätigung. Fehlerfall unverändert. ~+15/−3 |
| `LooseEndsWatchUITests/WatchCaptureUITests.swift` | CREATE | Zwei Erfassungen hintereinander: tippen → Blatt-Fertig → App-Fertig → „Gespeichert“ → leeres Feld (Wartezeit ≤ 5 s) → zweite Aufgabe → wieder „Gespeichert“ → leeres Feld. Vor dem Fix rot. ~+50 |
| `project.yml` | MODIFY | Ziel `LooseEndsWatchUITests` (watchOS, `TEST_TARGET_NAME: LooseEndsWatch`), Schema `LooseEndsWatch` (wie im Probelauf erprobt). ~+22 |
| `scripts/sim.sh` | MODIFY | Watch-Weg: Simulatorwahl nach watchOS-Laufzeit ≥ Target (wie `sim_id` für iOS), vor dem Lauf App deinstallieren, `test-proof` mit Ziel/Schema der Watch (Beleg über `sim_proof.py` wie gehabt). ~+30 |

### Scope Assessment
- Files: 4
- Estimated LoC: ~+120/−5
- Risk Level: LOW für das Produkt (eine Ansicht), MEDIUM für den Testaufbau (neues Ziel, Skriptpfad; `project.yml` auf
  der Geräteliste → Stufe 3 über TestFlight).

### Technical Approach (Empfehlung)
Zustand bleibt in der Ansicht (`text`, `saved`), keine eigene Regeldatei: Henning hat heute den Nachweis über den echten
Ablauf gewählt, und der UI-Test prüft genau den. Die gestrige Regel `WatchCaptureFlow` (Vorgänger) entfällt damit samt
Unit-Test; das hält den Schnitt bei 4 Dateien. Die Bestätigung hängt an `.task(id: saved)`: startet beim Wechsel auf
`true`, schläft 1,5 s, setzt zurück; geht die Ansicht weg, bricht die Aufgabe ab, beim Wiederkommen startet sie neu.
Kein Auto-Fokus ins Diktat (nicht gefordert).

### Alternativen
- **Regel in `Shared/` + Unit-Test, UI-Test zusätzlich** (Vorgänger-Spec): 6 Dateien, sprengt das Dateilimit; die Regel
  ist zwei Zuweisungen, der Unit-Test belegt nichts, was der UI-Test nicht belegt.
- **Nur Regel + TestFlight, kein UI-Test** (Hennings Wahl vom 2026-10-14, weil der Läufer damals hing): überholt, der
  Läufer startet nachweislich.
- **Kein Zeitablauf, sofort leeren mit Haptik:** schneller, aber ohne sichtbare Bestätigung; Henning wollte ~1,5 s
  „Gespeichert“.

### Dependencies
`CaptureService.save(_:via:in:)` unverändert; `ModelContainerFactory` liefert unter `--ui-testing` einen In-Memory-Store
(auch auf der Watch, im Probelauf bestätigt: keine echten Daten). Komplikation und Siri öffnen dieselbe Ansicht.

### Offene Punkte (technisch, von mir entschieden)
- **CI:** Watch-UI-Test läuft vorerst nur lokal über `sim.sh`; ein CI-Job ist ein eigenes Ziel → eigenes Issue.
- **„Beide gespeichert“:** belegt dadurch, dass „Gespeichert“ nur nach erfolgreichem `CaptureService.save` erscheint
  (sonst Alert); kein Testhaken in der App.
- **Vorgänger-Workflow `fix-409-watch-ruecksprung`** (Worktree deep-strolling-quilt, liegt seit 2026-10-14 brach, keine
  Sitzung daran): wird nach dieser Analyse aufgegeben, damit #409 nur einen Workflow hat.

## TDD RED (2026-10-15) — Abweichungen vom Spec-Dateiplan
- **Testpfad:** `LooseEndsUITests/Watch/WatchCaptureUITests.swift` statt `LooseEndsWatchUITests/…`. Grund: Das Edit-Gate
  liest `openspec.yaml` aus dem Hauptordner (Worktree → Hauptrepo), dort kennt `always_allowed_dirs` nur
  `LooseEndsUITests/`; ein neuer Testordner wäre erst nach dem Merge erlaubt. `project.yml`: iOS-Ziel schließt
  `Watch/**` aus, `LooseEndsWatchUITests` nimmt nur `LooseEndsUITests/Watch`.
- **Elementsuche:** Feld über `app.textFields.firstMatch` (einziges Feld nach geschlossenem Eingabeblatt), App-Knopf und
  Bestätigung über `identifier OR label IN {…}`. So ist der RED-Lauf am unveränderten Code aus dem richtigen Grund rot
  (Bestätigung gesehen, Feld kommt nicht zurück) statt an fehlenden Identifikatoren; die Identifikatoren
  `watch.capture.done`/`watch.capture.saved`/`watch.capture.field` kommen in `/50-implement` in die Ansicht.
- **5. Datei `scripts/sim_proof.py`:** xcresult meldet für den Watch-Simulator den Namen des gekoppelten iPhones
  („iPhone 18 Pro Max, iOS 27.0“); der Beleg soll „Apple Watch Series 12, watchOS 27.0“ nennen (AC-7). RED-Test in
  `scripts/test_sim_proof.py`.
- **RED-Ergebnis:** `testTwoCapturesInARowReturnToEmptyField` rot („Feld kommt nach „Milch kaufen“ nicht zurück“),
  `testConfirmationIsVisibleBeforeFieldReturns` grün (Schutz gegen sofortiges Leeren ohne Anzeige, muss grün bleiben).
  Beleg: `test-red-output.txt`, `simulator-run-red.txt`, `red-gespeichert-haengt.png` (angesehen: Häkchen + „Gespeichert“).
- Testlauf: `scratchpad/run-watch-test.sh` = `CLAUDE_SESSION_ID=velvet409 ./scripts/sim.sh watch-test-proof
  WatchCaptureUITests` unter `/tmp/loose-ends-testlauf.lock`.
