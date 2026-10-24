# Context: fix-418-ortanmeldung

## Request Summary
#418 (aus Epic #226): Scheitert eine Ortsanfrage beim System dauerhaft (z. B. ungültige Region), bricht
`PlaceNotificationCenter.reconcile` ab, schreibt die Merkliste nicht, und alle Orte dahinter werden in keinem
Lauf mehr angemeldet. Fehler soll je Anfrage abgefangen werden.

## Nachgestellt (2026-10-24)
Roter Test `permanentFailureDoesNotBlockTheRest` (`LooseEndsTests/PlaceNotificationCenterTests.swift`, mit
`Recorder.failFor`): zwei Orte, der mit der kleineren Kennung scheitert für immer. Ergebnis heute: der zweite wird
nie angemeldet (`added == []`), die Merkliste bleibt ungeschrieben. Hat es bisher funktioniert? Ja, solange nichts
dauerhaft scheiterte; keine Verschlechterung, sondern eine Lücke aus der Prüfung von #240 Schnitt 2 (F002).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Notifications/PlaceNotificationCenter.swift` (`reconcileOnce`, Zeilen ~104–128) | `for reminder in changes.add + changes.updateContent { try await scheduler.add(...) }` bricht beim ersten Fehler ab; `saveHandover(changes.handover)` danach |
| `Shared/Notifications/PlaceDelivery.swift` (`diff`, `Handover`, `Entry`) | `changes.handover` enthält schon Einträge für alle geplanten `add`/`updateContent`; ein Eintrag je Aufgabe (`taskID`, `fingerprint`, `title`) |
| `LooseEndsTests/PlaceNotificationCenterTests.swift` | Recorder, Fixture; AC-9-Test `failingAddKeepsTheListUnwritten` muss angepasst werden |
| `docs/specs/feat-240-schnitt-2-zustellung.md` AC-9 | verlangt heute: Merkliste bleibt bei Fehler ungeschrieben |
| `LooseEnds/Notifications/DueNotificationCenter.swift:191-194` | `reschedule()` ruft `places?.reconcile()` nach dem Fälligkeitslauf; Fehler dort darf diesen nie brechen (bleibt) |

## Existing Patterns
- `reconcileOnce` fängt alles in einem `do/catch` und protokolliert über `Logger` (kein `try?`).
- Unterschied zwischen `add` (neu/ersetzt) und `updateContent` (nur Titel): bei fehlgeschlagenem `updateContent` ist
  die alte Anfrage noch offen, also muss der alte Merklisteneintrag stehen bleiben; bei fehlgeschlagenem `add`
  gehört kein Eintrag in die Liste (oder der alte, wenn eine ersetzte Anfrage zuvor entfernt wurde: dann keiner).

## Dependencies
- Upstream: `PlaceScheduling` (`add` wirft), `PlaceDelivery.diff`, `UserDefaults` für die Merkliste.
- Downstream: `DueNotificationCenter.reschedule()`; nächster Lauf vergleicht Merkliste mit offenen Anfragen
  und versucht Fehlendes erneut (`action(...)`: kein Eintrag und nicht offen → `.add`).

## Existing Specs
- `docs/specs/feat-240-schnitt-2-zustellung.md` (AC-9) — wird angepasst: Fehler je Anfrage, Merkliste enthält
  nur Übergebenes.
- `docs/specs/feat-226-ortserinnerungen.md` — Epic-Entwurf.

## Risks & Considerations
- Dauerhafter Fehler wird bei jedem Lauf erneut versucht und protokolliert (Lärm im Log, kein Absturz). Eine
  Wiederholungsbremse wäre eigener Umfang (vgl. #535 für das Modell) und ist nicht Teil von #418.
- Der Simulator lehnt `add` immer mit 2003 ab: alle Anfragen scheitern dort, also bleibt die Merkliste leer wie heute.
- Pfad `LooseEnds/Notifications/` steht auf der Geräteliste: Stufe 3 über TestFlight, nichts auf Hennings Geräten
  ohne sein Wort.
- Eine Quelldatei plus Test, ca. 30 LoC; innerhalb der Scoping-Limits.

## Analysis

### Type
Bug (Lücke aus der Prüfung von #240 Schnitt 2, F002). Keine Verschlechterung: hat bisher funktioniert, solange nichts dauerhaft scheiterte.

### Recherche (zuerst, 2026-10-24)
Suche nach Fehlerbild „UNLocationNotificationTrigger add invalid region, UNErrorDomain, je Anfrage“: nichts Gegenteiliges.
Apple-Foren und Dokumentation prüfen den Fehler im Abschluss von `add`, es gibt keine Sammel-Semantik; eine Anfrage
scheitert für sich. Quellen: [Apple Forum 777251](https://developer.apple.com/forums/thread/777251),
[UNLocationNotificationTrigger-Doku](https://developer.apple.com/documentation/usernotifications/unlocationnotificationtrigger).
Die konkreten Fehlercodes für „ungültige Region“ liefert die Suche nicht; das ändert den Fix nicht (jeder Fehler je Anfrage).

### Root Cause (am roten Test belegt)
`PlaceNotificationCenter.reconcileOnce`: `for reminder in changes.add + changes.updateContent { try await scheduler.add(...) }`
liegt in EINEM `do/catch`. Der erste Wurf verlässt die Schleife, `saveHandover` wird nie erreicht. Die Anfragen sind nach
Kennung sortiert, die scheiternde mit der kleineren Kennung blockiert also dauerhaft alle dahinter.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Notifications/PlaceNotificationCenter.swift` | MODIFY | `add` je Anfrage fangen und protokollieren; Merkliste aus dem Diff, aber für jede gescheiterte Aufgabe auf den vorherigen Eintrag (oder keinen) zurückgesetzt |
| `LooseEndsTests/PlaceNotificationCenterTests.swift` | MODIFY | roter Test `permanentFailureDoesNotBlockTheRest` (liegt schon), AC-9-Test bleibt gültig |
| `docs/specs/feat-240-schnitt-2-zustellung.md` | MODIFY | AC-9: „je Anfrage; Merkliste enthält nur Übergebenes“ |

### Technical Approach (Regelweg, kein Modell)
1. Schleife je Anfrage mit eigenem `do/catch`; Fehler → `Logger.error` mit Kennung, Aufgabe merken (`failed: Set<UUID>`).
2. Merkliste: Eintrag aus `changes.handover`, außer die Aufgabe ist gescheitert → alter Eintrag aus `loadHandover()` (bei
   `updateContent` bleibt die alte Anfrage offen und der alte Titel stimmt) oder gar keiner (bei `add`/`replace`).
   Eine einheitliche Regel „zurück auf den vorherigen Stand“ deckt alle drei Fälle: ohne Eintrag und nicht offen → nächster
   Lauf `.add`; alter Eintrag mit anderem Fingerabdruck und nicht offen → ebenfalls `.add`.
3. Schreiben nur, wenn die Liste sich gegenüber der gespeicherten ändert: alles scheitert (Simulator, 2003) bleibt wie heute
   ungeschrieben, AC-9-Test bleibt grün.
4. Ohne Berechtigung unverändert (nichts übergeben, nichts notiert).

### Alternativen
- **Nichts tun** (Issue nennt sie): Fall ist bisher theoretisch; verworfen, weil der Test das Blockieren belegt und der Fix klein ist.
- **Vorab prüfen** (Region gültig, Radius) statt fangen: deckt nur bekannte Gründe ab, ein Systemfehler anderer Art blockiert weiter. Als Ergänzung möglich, nicht statt.
- **Wiederholungsbremse** für dauerhaft scheiternde Anfragen (Zähler/Sperrfrist): eigener Umfang, vgl. #535; nicht Teil von #418.
- Gekippte frühere Entscheidung: AC-9 von #240 Schnitt 2 („Merkliste bleibt bei Fehler ungeschrieben“).

### Scope Assessment
- Files: 3 (davon 1 Spec, 1 Test schon begonnen)
- Estimated LoC: +30/-6 Quelltext, Test +25 (liegt vor)
- Risk Level: LOW (ein isolierter Pfad, Fälligkeitslauf unberührt)

### Dependencies
`PlaceScheduling.add`, `PlaceDelivery.diff` (unverändert), `DueNotificationCenter.reschedule()` (ruft `reconcile`, fängt nichts weiter).

### Abnahme
Pfad `LooseEnds/Notifications/` steht auf der Geräteliste: Stufe 3 über TestFlight nach dem Merge, nichts auf Hennings Geräten ohne sein Wort. Ein echter dauerhafter Fehler ist auf dem Gerät nicht herstellbar; der Nachweis ist der Unit-Test mit `failFor`.

### Open Questions
- [x] Keine. Keine Produktfrage offen.
