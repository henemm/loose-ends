---
entity_id: fix-418-ortanmeldung
type: bugfix
created: 2026-10-24
updated: 2026-10-24
status: draft
workflow: fix-418-ortanmeldung
---

# Spec: #418 Ortsanmeldung — eine gescheiterte Anfrage blockiert die übrigen nicht

## Approval

- [ ] Approved (Henning)

## Purpose

Was der Nutzer erlebt: Scheitert beim System die Anmeldung der Ortsmitteilung für **einen** Ort dauerhaft (z. B.
ungültige Region), werden die anderen Orte trotzdem angemeldet und melden sich beim Ankommen oder Verlassen. Heute
bricht der Abgleich beim ersten Fehler ab: Die Merkliste wird nicht geschrieben, alle Orte dahinter (sortiert nach
Kennung) werden in keinem Lauf mehr angemeldet.

Ohne Modell: Es ist keines im Spiel; eine Schleife mit Fehlerbehandlung je Anfrage genügt (Regeln vor dem Modell).

## Source

Details: `docs/context/fix-418-ortanmeldung.md` (Abschnitt „Analysis"). Die Ursache ist am roten Test
`permanentFailureDoesNotBlockTheRest` belegt: zwei Orte, der mit der kleineren Kennung scheitert für immer → der
zweite wird nie angemeldet (`added == []`), die Merkliste bleibt ungeschrieben. Hat es bisher funktioniert? Ja, solange
nichts dauerhaft scheiterte; keine Verschlechterung, sondern eine Lücke aus der Prüfung von #240 Schnitt 2 (F002).

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Notifications/PlaceNotificationCenter.swift` | MODIFY | `scheduler.add` je Anfrage mit eigenem `do/catch`; Fehler mit `Logger.error` und Kennung protokollieren, Aufgabe merken. Merkliste = `changes.handover`, aber für jede gescheiterte Aufgabe auf den vorherigen Eintrag (oder keinen) zurückgesetzt. Schreiben nur, wenn sich die Liste gegenüber der gespeicherten ändert. Ca. +30 / −6. |
| `LooseEndsTests/PlaceNotificationCenterTests.swift` | MODIFY | Roter Test `permanentFailureDoesNotBlockTheRest` liegt schon vor; Tests für AC-2 und AC-3 kommen dazu. Ca. +60. |
| `docs/specs/feat-240-schnitt-2-zustellung.md` | MODIFY | AC-9 auf „je Anfrage; Merkliste enthält nur Übergebenes" angepasst, Changelog-Zeile. |

Erwartet: 3 Dateien, ca. +95 / −6 Zeilen (Produkt ca. 35). Keine Funktion über 50 Zeilen. Keine neue Datei, daher kein
`generate` nötig.

Side-Effects: keine neuen Berechtigungen, keine neuen `UserDefaults`-Schlüssel (`placeHandover` bleibt, Inhalt nur
genauer), keine Änderung an Modell, CloudKit-Schema, Entitlements, `Info.plist`, `project.yml`. Fälligkeitslauf
(`DueNotificationCenter.reschedule()`) unberührt.

### Out of Scope

- **Keine Wiederholungsbremse:** Eine dauerhaft scheiternde Anfrage wird bei jedem Lauf erneut versucht und
  protokolliert (Log-Lärm, kein Absturz). Zähler/Sperrfrist wäre eigener Umfang (vgl. #535 für das Modell).
- **Keine Vorabprüfung** der Region (Radius, Koordinate): deckt nur bekannte Gründe ab; höchstens später als Ergänzung.
- Keine Änderung an `PlaceDelivery.diff`, `PlaceReminders.plan`, `DueNotificationCenter`, Oberfläche.
- Kein Hinweis in der Oberfläche, dass ein Ort nicht angemeldet werden konnte.

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `PlaceScheduling.add` | Aufruf (wirft) | Anmeldung je Anfrage, Fehler wird je Aufruf gefangen. |
| `PlaceDelivery.diff` / `Handover` / `Entry` | Aufruf (unverändert) | liefert `add`, `updateContent`, `handover`; ein Eintrag je Aufgabe. |
| `loadHandover()` | Aufruf | vorheriger Stand für gescheiterte Aufgaben. |

## Recherche (2026-10-24)

Suche nach Fehlerbild „UNLocationNotificationTrigger add invalid region, UNErrorDomain" ergab nichts Gegenteiliges: Der
Fehler wird im Abschluss von `add` je Anfrage gemeldet, es gibt keine Sammel-Semantik. Quellen:
[Apple Forum 777251](https://developer.apple.com/forums/thread/777251),
[UNLocationNotificationTrigger-Doku](https://developer.apple.com/documentation/usernotifications/unlocationnotificationtrigger).
Die konkreten Fehlercodes für „ungültige Region" liefert die Suche nicht; das ändert den Fix nicht.

## Implementation Details

1. **Schleife je Anfrage.** `for reminder in changes.add + changes.updateContent` ruft `scheduler.add` in einem eigenen
   `do/catch`. Bei Fehler: `Logger.error` mit Kennung und Fehler (`privacy: .public`, wie bisher), `reminder.taskID` in
   `failed: Set<UUID>`, weiter mit der nächsten Anfrage. Kein `try?`.
2. **Merkliste „zurück auf den vorherigen Stand".** Neue Liste = Einträge aus `changes.handover` ohne die gescheiterten
   Aufgaben, plus für jede gescheiterte Aufgabe ihr Eintrag aus `loadHandover()` (falls vorhanden), Reihenfolge nach
   `taskID.uuidString` wie bisher. Das deckt alle Fälle:
   - `add` neu: kein alter Eintrag → keiner; nächster Lauf: kein Eintrag, nicht offen → `.add`.
   - `add` als Ersatz (anderer Fingerabdruck, alte Anfrage wurde zuvor zurückgenommen): alter Eintrag bleibt, ist aber
     nicht mehr offen → nächster Lauf `.add`.
   - `updateContent` (nur Titel): alte Anfrage ist noch offen, alter Eintrag mit altem Titel stimmt → nächster Lauf
     versucht den Titel erneut.
3. **Schreiben nur bei Änderung.** Die Liste wird nur gespeichert, wenn sie von `loadHandover()` abweicht. Scheitert
   alles (Simulator, UNErrorDomain 2003) bei leerer Merkliste, bleibt sie wie heute ungeschrieben.
4. **Ohne Freigabe unverändert.** `authorized == false`: nichts übergeben, nichts notiert.
5. Der äußere `do/catch` bleibt für Abruf der Aufgaben und `saveHandover`; ein Fehler dort wird weiter protokolliert
   und nicht geworfen.

## Acceptance Criteria

Alles Unit-Tests im Simulatorlauf (`./scripts/sim.sh sim-unit`, nie auf dem Mac) mit Recorder statt System, ausgenommen
das Gerät am Ende.

- **AC-1:** **Eine dauerhaft gescheiterte Anfrage blockiert die übrigen nicht:** Given zwei Aufgaben mit Ort, die
  Anmeldung der Aufgabe mit der kleineren Kennung scheitert jedes Mal / When `reconcile` läuft / Then wird die andere
  angemeldet (`added == [gut]`), `reconcile` wirft nicht, und die Merkliste enthält nur die übergebene Aufgabe; When
  danach `reconcile` ein zweites Mal läuft, auch nachdem der Fehler behoben ist / Then wird nur die zuvor gescheiterte
  neu versucht (`added == [gut, schlecht]`), die gute nicht erneut. Nachweis: Unit-Test
  `permanentFailureDoesNotBlockTheRest` (liegt rot vor, muss grün werden).
- **AC-2:** **Gescheiterter Titelwechsel behält den alten Eintrag:** Given eine Aufgabe ist angemeldet und notiert, ihr
  Titel ändert sich, und die Ersetzung (`updateContent`) scheitert / When `reconcile` läuft / Then bleibt der alte
  Merklisteneintrag mit altem Titel stehen (kein Eintrag mit neuem Titel, kein Wegfall); When der Fehler behoben ist und
  `reconcile` erneut läuft / Then wird der neue Titel angemeldet und notiert. Nachweis: Unit-Test.
- **AC-3:** **Scheitert alles bei leerer Merkliste, bleibt sie ungeschrieben (AC-9 aus #240 Schnitt 2 bleibt gültig):**
  Given `add` wirft für jede Anfrage, Merkliste leer / When `reconcile` läuft / Then wirft `reconcile` nicht und
  `placeHandover` ist nicht geschrieben; When danach `add` wieder klappt / Then wird die Aufgabe angemeldet und
  notiert. Nachweis: bestehender Unit-Test `failingAddKeepsTheListUnwritten` bleibt unverändert grün.
- **AC-4:** **Fehler wird je Anfrage protokolliert, nicht verschluckt:** Given Anmeldung scheitert / Then steht im
  Quelltext ein `Logger.error` mit der Kennung der Anfrage im `catch` der Schleife und kein `try?`. Nachweis: Review
  des Quelltexts (Logger-Ausgabe ist im Unit-Test nicht abfragbar).
- **AC-5:** **Fälligkeitslauf unberührt:** Given ein Ortsabgleich mit gescheiterter Anfrage / When `reschedule()` läuft /
  Then läuft der Fälligkeitslauf vollständig durch (bestehende Tests aus #240 Schnitt 2, AC-9 zweiter Teil, bleiben
  grün). Nachweis: Unit-Lauf.
- **AC-6:** **Regression:** Given `./scripts/sim.sh generate` und `./scripts/sim.sh sim-unit` / Then bleiben alle
  bestehenden Tests grün (`PlaceNotificationCenterTests`, `PlaceDelivery`, `PlaceReminders`, `DueNotificationCenter`);
  CI grün. Nachweis: Unit-Lauf.
- **AC-7:** **Simulatorlauf, ehrlich:** Given `./scripts/sim.sh build`, `launch`, `screenshot` mit einer Aufgabe mit Ort /
  Then startet die App wie zuvor, der Abgleich scheitert im Simulator mit 2003 und stürzt nicht ab. Berichtet wird
  ausdrücklich: Ein dauerhafter Einzelfehler mit gutem Nachbarn ist im Simulator nicht herstellbar (dort scheitert
  jede Anfrage); der Nachweis dafür ist AC-1. Nachweis: Simulatorlauf mit Screenshots (geöffnet und beschrieben).
- **AC-8 (Gerät, Stufe 3):** Der Pfad `LooseEnds/Notifications/` steht auf der Geräteliste: Nach dem Merge läuft die
  Gerätestufe über TestFlight, **nur nach Hennings wörtlichem „jetzt ist ein Test möglich"**; vorher läuft nichts auf
  seinen Geräten, auch nichts Lesendes. Geprüft wird nur, dass die Ortsmitteilung weiter wie in #240 ankommt (kein
  Rückschritt); ein echter dauerhafter Fehler ist auf dem Gerät nicht herstellbar. Nachweis: Gerät, TestFlight,
  nachgelagert; Hennings Rückmeldung schließt den Punkt.

## Tests

- **Unit** (Swift Testing, TDD RED zuerst; `ModelContainer` bleibt im Test am Leben):
  `LooseEndsTests/PlaceNotificationCenterTests.swift`: AC-1 (liegt rot vor), AC-2 (neu), AC-3 (bestehend). Namen nennen
  die Wirkung. Zusicherungen über `==`, nie `CONTAINS`. Aufruf nur `./scripts/sim.sh sim-unit`.
- **Kein UI-Test:** keine sichtbare Änderung; der Schnitt berührt keine Oberfläche.
- Reihenfolge: RED (AC-1, AC-2 rot) → Schleife und Merkliste → Unit grün → Simulatorlauf mit Beleg.

## Alternativen (bewusst benannt)

| | Weg | Dafür | Dagegen / welche Entscheidung kippt |
|---|---|---|---|
| **A (Empfehlung, diese Spec)** | `add` je Anfrage fangen, Merkliste auf vorherigen Stand der gescheiterten Aufgaben | klein, ohne Modell, nächster Lauf wiederholt von selbst | kippt AC-9 aus #240 Schnitt 2 teilweise („Merkliste bleibt bei Fehler ungeschrieben" → „enthält nur Übergebenes") |
| B | Nichts tun (Fall theoretisch) | kein Aufwand | der Test belegt das Blockieren; ein einziger ungültiger Ort sperrt alle dahinter |
| C | Vorab prüfen (Region gültig) statt fangen | verhindert bekannte Fehler früh | deckt nur bekannte Gründe ab, Systemfehler anderer Art blockiert weiter; höchstens Ergänzung |
| D | Wiederholungsbremse (Zähler/Sperrfrist) zusätzlich | weniger Log-Lärm, keine Dauerversuche | eigener Umfang, eigener Zustand, eigenes Schema; ausdrücklich nicht Teil von #418 |

## Risiken

- **Log-Lärm:** Ein dauerhaft gescheiterter Ort wird bei jedem Lauf erneut versucht und protokolliert (NIEDRIG, kein
  Absturz, bewusst in Kauf genommen, Bremse siehe Alternative D).
- **Merkliste und offene Anfragen laufen auseinander:** Gegen: Regel „zurück auf den vorherigen Stand" (Implementation
  Details 2) und AC-2.
- **Simulator:** `add` scheitert dort immer (2003); der Fall „Nachbar klappt" ist nur im Unit-Test belegbar.

## Abnahme-Stufen

1. **Tests:** `./scripts/sim.sh sim-unit` grün, CI grün.
2. **Simulator:** `build`, `launch`, `screenshot` des geänderten Ablaufs (AC-7), ehrlich begrenzt.
3. **Gerät (Pflicht, Pfad `LooseEnds/Notifications/`):** nach dem Merge über TestFlight, nur nach Hennings wörtlichem
   „jetzt ist ein Test möglich" (AC-8).

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — Fehlerbehandlung je Anfrage statt je Lauf; kippt keine ADR, nur AC-9 der Spec #240 Schnitt 2, die hier angepasst wird.

## Definition of Done

- [ ] Alle Unit-Tests grün (AC-1 grün, AC-2, AC-3), CI grün.
- [ ] Simulator: Änderungsablauf gespielt, Belege geöffnet und beschrieben (AC-7).
- [ ] `docs/specs/feat-240-schnitt-2-zustellung.md` AC-9 angepasst.
- [ ] Nach dem Merge: TestFlight-Bau mit „Was testen" auf Deutsch; Gerätepunkt AC-8 mit Hennings Rückmeldung; #418 erst dann
  geschlossen.

## Changelog

- 2026-10-24: Entwurf aus `docs/context/fix-418-ortanmeldung.md`.
