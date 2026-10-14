---
entity_id: feat-240-schnitt-1-bausteine
type: feature
created: 2026-10-14
updated: 2026-10-14
status: draft
workflow: feat-240-ortsmitteilung
---

# Spec: #240 Schnitt 1 — Bausteine der Ortsmitteilung (rein, ohne Systemanschluss)

## Approval

- [ ] Approved (Henning)

## Purpose

Eine Aufgabe mit Ort soll sich beim Ankommen oder Verlassen mit „Du bist bei <Ort>.“ melden, auch wenn die App
nicht läuft (#240 Teil B = #226 Schnitt 2b). Der Plan (`PlaceReminders.plan`) und die Übergabe-Entscheidung
(`PlaceDelivery.diff`) sind gemergt, aber an nichts angeschlossen. Die Vorarbeit liegt ungesichert im Worktree
`jazzy-crunching-trinket` (Stand vor 75 Commits) und ist als Ganzes rund 520 Zeilen groß — das sprengt das
250-Zeilen-Limit. Deshalb wird in **zwei Schnitte** geteilt:

- **Schnitt 1 (diese Spec): die reinen Entscheidungs-Bausteine.** Kategorienmenge, Freigabe- und
  Frage-Entscheidung, Stille-Regel, Präfix-Filter, Einlauf-Sperre und die Verteilung einer Antwort an die Marke
  `placeRemindedAt`. Alles plattformneutral, ohne `CoreLocation`, ohne Systemaufruf, ohne Anschluss an die App.
- **Schnitt 2 (eigene Spec, eigener Workflow, folgt):** `PlaceNotificationCenter` (iOS, `CLLocationManager`,
  `UNLocationNotificationTrigger`), Anschluss in `DueNotificationCenter` auf der Callback-Fassung von `main`
  (#295, `taskToOpen` #331), `project.yml` (`NSLocationWhenInUseUsageDescription`). Dort greift die Gerätestufe.

**Ehrlich zum Nutzen:** Schnitt 1 ändert für Henning nichts Sichtbares. Er ist die Voraussetzung dafür, dass
Schnitt 2 klein und prüfbar bleibt, und er legt die Entscheidungen, die Fehler kosten (Kategorien überschreiben
sich, Dauerfrage nach „Einmal erlauben“, doppelte Anfragen), als reine, getestete Regeln fest.

Ohne Modell: Es ist keines im Spiel, der Regelweg ist der einzige Weg (Regeln vor dem Modell).

**Diese Spec ersetzt Teil B von `docs/specs/feat-226-schnitt-4-zustellung.md` (#240)** zusammen mit Schnitt 2:
Dort steht „ersetzt alle offenen `place_`-Anfragen durch den Plan“; es gilt stattdessen die Merkliste aus 2a.
Teil A von #240 (Marke `placeRemindedAt`, PR #248) bleibt gültig und wird hier erstmals in einer Verteilung
benutzt. Die 2a-Festlegung „iPad und iPhone erinnern beide“ wird durch „Einmal für alle“ ersetzt (unten).

## Source

- **Neu:** `Shared/Notifications/PlaceNotifications.swift` — `NotificationCategories`, `PlaceNotifications`,
  `ReconcileGate`
- **Neu:** `LooseEndsTests/PlaceNotificationsTests.swift`
- **Unverändert, nur gelesen:** `Shared/Notifications/PlaceReminders.swift` (`identifierPrefix`,
  `markDelivered`), `Shared/Notifications/DueReminders.swift` (`Action`, `handle`, `categoryIdentifier`),
  `Shared/Models/TaskPlace.swift`, `Shared/Models/TaskItem.swift` (`placeRemindedAt`)

**Warum `Shared/Notifications/` und nicht `LooseEnds/Notifications/`:** Die Geräteliste in CLAUDE.md nennt
`LooseEnds/Notifications/` als Pfad, der die Gerätestufe auslöst. Die Bausteine sind reine Logik ohne
Systemaufruf; sie liegen neben `PlaceReminders` und `PlaceDelivery` und lösen die Gerätestufe nicht aus. Das ist
keine Umgehung: Alles, was das System berührt, bleibt in Schnitt 2 unter `LooseEnds/Notifications/`.
`Shared/` wird auch in Watch und Widgets übersetzt; es steht dort nur `UserNotifications`, `Foundation` und
`SwiftData`, nichts davon ist auf watchOS nicht verfügbar.

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `PlaceReminders.identifierPrefix` / `markDelivered(taskID:in:now:)` | Aufruf | Präfix `place_`; setzt `placeRemindedAt`. |
| `DueReminders.Action` / `handle` / `categoryIdentifier` | Wiederverwendung | Erledigt (`DUE_DONE`) und Als nächstes (`DUE_NEXT`) gelten für Ort und Fälligkeit gleich. |
| `UserNotifications` (`UNNotificationCategory`, `UNNotificationAction`) | System, nur Wertetypen | Kategorienmenge bauen; kein Aufruf an `UNUserNotificationCenter`. |

## Recherche (2026-10-14, Stand der Analyse)

| Frage | Befund | Quelle |
|---|---|---|
| `UNLocationNotificationTrigger` in iOS 27 | Nicht veraltet; iOS und watchOS, nicht macOS; braucht „Beim Verwenden“ | [Apple-Doku](https://developer.apple.com/tutorials/data/documentation/usernotifications/unlocationnotificationtrigger.md) |
| `requestWhenInUseAuthorization` | fragt nur bei `notDetermined`, nur im Vordergrund; „Einmal erlauben“ fällt auf `notDetermined` zurück | [Apple-Doku](https://developer.apple.com/tutorials/data/documentation/corelocation/cllocationmanager/requestwheninuseauthorization().md) |
| Reduzierte Genauigkeit | Bereichsüberwachung ist dabei aus | [WWDC20 Notizen](https://mackuba.eu/notes/wwdc20/whats-new-in-location) |
| Zustellmeldung für Ortsmitteilungen | fehlen in `getDeliveredNotifications` (Grund für Merkliste und Marke) | [Forum 777251](https://developer.apple.com/forums/thread/777251) |
| `CLMonitor` als Ersatz | liefert keine Mitteilung, App müsste selbst zustellen und „Immer“ verlangen | Forum 806783, 748708 |

Diese Recherche betrifft vor allem Schnitt 2; hier begründet sie die Regeln 4 bis 6.

## Festlegung: Einmal für alle (Henning, 2026-10-07)

Eine Ortserinnerung kommt **einmal je Zyklus für alle Geräte zusammen**. Die Marke `placeRemindedAt` (#248)
reist über CloudKit: Sobald ein Gerät die Mitteilung anzeigt oder sie beantwortet wird, setzt es die Marke
(Regel 7); die Aufgabe fällt damit aus `PlaceReminders.plan`, andere Geräte nehmen ihre Anfrage zurück. Die
Merkliste aus 2a bleibt als Schutz je Gerät, wenn die Mitteilung bei geschlossener App ignoriert wurde.
Grenze: Zwei Geräte können beide auslösen, bevor die Marke angekommen ist.

## Verhalten / Regeln

### Kategorien

1. **Eine Menge, zwei Kategorien:** `NotificationCategories.all()` liefert `DUE` (Aktionen `DUE_DONE`,
   `DUE_NEXT`, `DUE_TOMORROW`) und `PLACE` (nur `DUE_DONE`, `DUE_NEXT`). Jeder Aufruf von
   `setNotificationCategories` ersetzt alle früheren; Schnitt 2 ruft ihn daher genau einmal mit dieser Menge auf.
2. **Kein „Morgen“ am Ort:** Ein Ort hat keinen Tag. Die Aktions-Kennungen bleiben dieselben wie bei
   Fälligkeit, damit `DueReminders.handle` sie ohne Änderung versteht.

### Freigabe

3. **Freigabe liegt vor** (`isAuthorized`) bei `whenInUse` oder `always` **und** voller Genauigkeit. Reduzierte
   Genauigkeit gilt als nicht freigegeben. Die eigene `Permission` (`notDetermined`, `refused`, `whenInUse`,
   `always`) vermeidet `CLAuthorizationStatus` im plattformneutralen Teil.
4. **Gefragt wird** (`shouldRequestAuthorization`) nur, wenn **alle vier** gelten: Status `notDetermined`, es gibt
   mindestens einen überwachten Ort, auf diesem Gerät wurde noch nie gefragt (Merker gegen die Dauerfrage nach
   „Einmal erlauben“), und die App ist im Vordergrund (im Hintergrund zeigt das System keinen Dialog; der Merker
   bliebe sonst gesetzt, ohne dass gefragt wurde). Nicht im Onboarding, nicht ohne Ort.

### Stille und Filter

5. **Still** (`isSilent`) unter Tests, und unter `--ui-testing` außer mit dem eigenen Argument
   `--ui-testing-places` (Vorbild `CalendarBridge`).
6. **Präfix-Filter** (`pendingPlaceIdentifiers`): Aus offenen Bezeichnern bleiben nur die mit `place_`. Der
   `due_`-Abgleich und der Orts-Abgleich fassen die Bezeichner des jeweils anderen nie an.

### Antwort und Marke

7. **Zugestellt = angekommen** (`respond`): Wird eine Mitteilung mit Präfix `place_` angezeigt oder beantwortet
   (auch durch bloßes Tippen), setzt `respond` die Marke über `PlaceReminders.markDelivered`. Kommt ein Knopf
   dazu, wirkt er danach über `DueReminders.handle` (Erledigt, Als nächstes). Bezeichner mit Präfix `due_`
   setzen die Marke nie. Ungültige oder fehlende Aufgaben-ID, unbekannte Aktion: `false`, nichts geändert.
   Rückgabe `true`, wenn etwas geändert wurde und gespeichert werden muss (Speichern macht der Aufrufer).
8. **Eine Marke je Antwort, nie ohne Antwort:** `respond` ist der einzige Weg zur Marke; ein bloßes Anlegen
   einer Anfrage setzt sie nicht.

### Einlauf-Sperre

9. **Ein Lauf zugleich** (`ReconcileGate`): `begin()` ist wahr nur, wenn kein Lauf läuft. Kommen währenddessen
   ein oder mehrere Auslöser, liefert `end()` **genau einmal** wahr (ein Nachlauf), sonst falsch. Der Zustand ist
   nach `end()` wieder frei.

### Alternativen (bewusst benannt)

| | Weg | Dafür | Dagegen / welche Entscheidung kippt |
|---|---|---|---|
| **A (Empfehlung, diese Spec)** | Reine Bausteine zuerst (Schnitt 1), Systemanschluss danach (Schnitt 2) | Beide Schnitte im Limit; Fehlerträchtiges ohne Gerät testbar | Schnitt 1 allein ohne sichtbaren Nutzen |
| B | Alles in einem Workflow | Ein Ticket | rund 520 Zeilen, Limit gesprengt |
| C | `CLMonitor` + „Immer“, App stellt selbst zu | volle Kontrolle, filtert Fehlauslösungen | kippt F1 / ADR-Antwort 14 („Beim Verwenden“), Hintergrundmodus, strengere Prüfung; nur Rückfall, falls die Messung in Schnitt 2 A als unzuverlässig zeigt |
| D | Nur Marke, keine Merkliste | weniger Code | ignorierte Mitteilung → Wiederholung beim nächsten Speichern (kippt die 2a-Entscheidung) |
| E | Ort als Vorschlag in der Fällig-Mitteilung statt Geo-Trigger | kein Standortrecht | verfehlt „beim Ankommen“ |

## Acceptance Criteria

Alles Unit-Tests im Simulator-Lauf (`./scripts/sim.sh unit`), außer AC-8 und AC-9.

- **AC-1:** **Kategorien tragen beide Knopfreihen:** Given `NotificationCategories.all()` / When die Menge geprüft
  wird / Then enthält sie `DUE` mit genau `DUE_DONE`, `DUE_NEXT`, `DUE_TOMORROW` **und** `PLACE` mit genau
  `DUE_DONE`, `DUE_NEXT` (ohne `DUE_TOMORROW`), und es gibt genau zwei Kategorien. Das sichert die
  Fällig-Knöpfe gegen das stille Überschreiben ab.
- **AC-2:** **Freigabe-Entscheidung:** Given `whenInUse` mit voller Genauigkeit / Then `isAuthorized` wahr; `always`
  mit voller Genauigkeit / Then wahr; `whenInUse` oder `always` mit reduzierter Genauigkeit / Then falsch;
  `refused`, `notDetermined` (jeweils voll oder reduziert) / Then falsch.
- **AC-3:** **Gefragt wird nur mit Ort, nur einmal, nur im Vordergrund:** Given `notDetermined`, Ort überwacht,
  noch nie gefragt, Vordergrund / Then Anfrage. Given jeweils genau eine der vier Bedingungen verletzt (leerer
  Plan; schon gefragt; Hintergrund; Status erteilt oder abgelehnt) / Then keine Anfrage.
- **AC-4:** **Antwort setzt die Marke:** Given eine Aufgabe mit Ort und eine Antwort mit Bezeichner
  `place_<uuid>` und `taskID` ohne Knopf (Tippen) / When `respond` läuft / Then ist `placeRemindedAt` gesetzt,
  die Rückgabe wahr, und die Aufgabe nicht mehr in `PlaceReminders.plan`. Given dieselbe Antwort mit
  `DUE_DONE` / Then Marke gesetzt **und** Aufgabe erledigt. Given `DUE_NEXT` / Then Marke gesetzt und
  Aufgabe als nächstes. Given Bezeichner `due_<uuid>` / Then bleibt `placeRemindedAt` leer. Given ungültige
  `taskID`, fehlende `taskID` oder `taskID` einer unbekannten Aufgabe / Then Rückgabe falsch, nichts geändert. Given Bezeichner `due_<uuid>` mit
  unbekannter Aktions-Kennung / Then Rückgabe falsch, nichts geändert. Given `place_<uuid>` mit unbekannter
  Aktions-Kennung / Then ist nur die Marke gesetzt (Rückgabe wahr), die Aufgabe sonst unverändert. Given eine
  Aufgabe mit Ort, für die nur `PlaceReminders.plan` gelaufen ist / Then ist `placeRemindedAt` leer (Regel 8:
  die Marke entsteht nur durch `respond`).
- **AC-5:** **Präfixe getrennt:** Given offene Bezeichner `due_<uuid>`, `place_<uuid>` und ein fremder Bezeichner /
  When `pendingPlaceIdentifiers` filtert / Then bleibt nur `place_<uuid>`.
- **AC-6:** **Still unter Tests:** Given `runningTests` wahr / Then `isSilent` wahr (unabhängig vom Argument).
  Given nur `uiTesting` ohne `--ui-testing-places` / Then wahr; mit dem Argument / Then falsch. Given weder noch /
  Then falsch.
- **AC-7:** **Einlauf-Sperre:** Given ein laufender Lauf / When zwei weitere Auslöser kommen (`begin()` falsch) /
  Then liefert `end()` einmal wahr, und danach `begin()` wieder wahr. Given kein weiterer Auslöser / Then
  `end()` falsch.
- **AC-8:** **Regression und Übersetzbarkeit:** Given `./scripts/sim.sh generate` und `unit` / Then bleiben alle
  bestehenden Tests grün (`DueReminders`, `PlaceReminders`, `PlaceDelivery`, `DueNotificationCenter` unverändert),
  und die neue Datei übersetzt für iOS, macOS und watchOS (Build der Targets, in denen `Shared/` liegt).
- **AC-9:** **Simulator, ehrlich:** Given `./scripts/sim.sh build` / When die App gestartet wird (`launch`,
  `screenshot`) / Then startet sie wie zuvor, die Listenansicht ist da (Screenshot geöffnet und beschrieben).
  Berichtet wird ausdrücklich, dass dieser Schnitt nichts anschließt und es daher nichts Neues zu sehen gibt.

## Tests

`LooseEndsTests/PlaceNotificationsTests.swift`, Swift Testing wie `PlaceDeliveryTests`, TDD RED zuerst (Typen
fehlen, der Lauf schlägt rot fehl). Echte `TaskItem` mit Ort (der `ModelContainer` bleibt im Test am Leben, siehe
CLAUDE.md). Je AC 1 bis 7 mindestens ein Test, die Namen nennen die Wirkung („Fällig-Knöpfe bleiben nach dem
Setzen beider Kategorien erhalten“), nicht „Funktion existiert“. Zusicherungen über `==`, nie `CONTAINS`.

`ReconcileGate` ist eine Klasse, weil `#expect` keine mutierende Methode aufrufen kann.

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Notifications/PlaceNotifications.swift` | NEU | `NotificationCategories`, `PlaceNotifications` (`Permission`, `isAuthorized`, `shouldRequestAuthorization`, `isSilent`, `pendingPlaceIdentifiers`, `respond`), `ReconcileGate`. Rund 100 Zeilen. |
| `LooseEndsTests/PlaceNotificationsTests.swift` | NEU | Tests zu AC-1 bis AC-7. Rund 130 Zeilen. |

Erwartet: 2 Dateien, rund +230 Zeilen. Keine Funktion über 50 Zeilen. **Stop-Regel:** Überschreitet die
Umsetzung 250 Zeilen, wird gestoppt und gemeldet.

**Keine Änderung** an `DueNotificationCenter`, `project.yml`, `Info.plist`, Entitlements, `scripts/sim.sh`,
am Modell oder an einer anderen Bestandsdatei. Kein CloudKit-Schema-Schritt (`placeRemindedAt` existiert seit
PR #248). Die Debug-Starthilfe `-le-seed-place` der Vorarbeit **entfällt ganz**: Sie war Wegwerfcode „bis
Schnitt 3“, und Schnitt 3a (#241, `PlaceEditing`, `PlaceSection`) ist gemergt, der Simulator-Durchlauf in
Schnitt 2 geht über die echte Oberfläche. (Abweichung von Alt-AC-5, -18, -19.) Das Projekt ist generiert: nach
der neuen Datei muss `./scripts/sim.sh generate` laufen.

**Geräteliste: kein Pfad berührt.** `Shared/Notifications/` und `LooseEndsTests/` stehen nicht in der Tabelle.
Die Abnahme endet nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“ Nichts auf Hennings Geräten.

### Nicht in Schnitt 1

- Alles, was das System berührt (`CLLocationManager`, `request(for:)`, `reconcile`, Delegate, Kategorien
  tatsächlich setzen, `project.yml`): Schnitt 2.
- Anschluss an `DueNotificationCenter` und der Wechsel seiner Kategorienliste auf `NotificationCategories.all()`:
  Schnitt 2. Bis dahin sind die Aktions-Titel zweimal vorhanden; das wird in Schnitt 2 aufgelöst.
- Oberfläche, Hinweis bei fehlender Freigabe: #241 Schnitt 3b. Siri: #25. Watch und Mac übergeben nichts.

## Erwartetes Verhalten

Für Henning ändert sich nichts Bedienbares. Die App verhält sich wie vorher; es liegen nur getestete Regeln bereit.
Die Ortsmitteilung selbst (Ankommen/Verlassen, Knöpfe Erledigt und Als nächstes) kommt mit Schnitt 2.

## Known Limitations

- Schnitt 1 allein liefert kein Feature; #240 bleibt bis Schnitt 2 offen.
- Aus der Vorarbeit unverändert für Schnitt 2: Systemverzögerung beim Ankommen/Verlassen (Forum 790110);
  „ausgelöst oder ignoriert“ nicht unterscheidbar (Forum 777251); Anlegen innerhalb des Bereichs löst nicht aus
  (Gerät 2026-10-08, erst beim nächsten Betreten); zwei Geräte vor der Marke erinnern beide.

## Risiken

- **Kategorien-Fehler** entfernt die Knöpfe der Fällig-Mitteilung still. AC-1 sichert die Menge; der Anschluss
  und der Simulator-Screenshot der Fällig-Knöpfe folgen in Schnitt 2.
- **Bausteine passen nicht zum späteren Anschluss:** Schnitt 2 braucht die Callback-Fassung von `main` (#295). Die
  Bausteine sind frei von Delegate-Fassung (reine Funktionen), das Risiko liegt allein im Anschluss.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — Schnitt 1 setzt freigegebene Festlegungen um (Merkliste aus 2a, „Beim Verwenden“, „Einmal für alle“) und kippt keine ADR; eine ADR entstünde erst, wenn Alternative C („Immer“, ADR-Antwort 14) gewählt würde.

## Weiter mit …

- **Schnitt 2** (neue Spec, neuer Workflow unter #240): Systemanschluss auf `main`, Gerätestufe über TestFlight
  nach Hennings „jetzt ist ein Test möglich“, Messung „Anlegen im Bereich“ ist schon belegt (2026-10-08).
- Der alte Worktree `jazzy-crunching-trinket` bleibt unangetastet, bis Schnitt 2 gemergt ist.

## Definition of Done

- Alle Unit-Tests grün (`./scripts/sim.sh unit`), Build und CI grün.
- Simulator: App gestartet, Screenshot geöffnet und beschrieben (AC-9).
- „Kein Pfad der Geräteliste berührt.“ im Abschlussbericht.
- #240 mit dem Stand kommentiert (Schnitt 1 gemergt, Schnitt 2 offen); der Folge-Schnitt als eigener Eintrag
  unter #240 geplant.

## Changelog

- 2026-10-14: Entwurf. Schnitt 1 aus `docs/context/feat-240-ortsmitteilung.md` (Teilung wegen 250-Zeilen-Limit,
  reine Bausteine nach `Shared/Notifications/`, Debug-Starthilfe entfällt).
