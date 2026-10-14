# Context: feat-240-ortsmitteilung (#240, #226 Schnitt 2b)

## Request Summary
Eine Aufgabe mit Ort meldet sich beim Ankommen oder Verlassen mit einer Mitteilung „Du bist bei <Ort>.“
(Knöpfe Erledigt, Als nächstes), auch wenn die App nicht läuft. #240 Teil A (Marke `placeRemindedAt`) ist
gemergt (PR #248); Teil B ist laut Ticket-Kommentar vom 2026-10-07 durch Schnitt 2b ersetzt. Dieser Workflow
übernimmt die liegengebliebene Arbeit aus dem Worktree `jazzy-crunching-trinket` (Zweig `feat-226-schnitt-2b`).

## Fundort der Vorarbeit (nur gelesen, nichts verändert)
Worktree `/Users/hem/Developer/loose-ends/.claude/worktrees/jazzy-crunching-trinket`, Basis `4b6ac16`
(75 Commits hinter `origin/main`). **Gesichert ist nur ein Commit** (`6a2ab3a`: Spec und rote Tests). Die
Umsetzung liegt nur ungesichert im Arbeitsordner. Workflow-State `feat-226-schnitt-2b` steht auf
`phase6b_adversary` (letzte Änderung 2026-10-08 10:06), Verdict AMBIGUOUS. Keine laufende Sitzung hält ihn.

| Datei im alten Worktree | Inhalt |
|---|---|
| `docs/specs/feat-226-schnitt-2b-systemanschluss.md` | Spec, AC-1 bis AC-15; Status `draft`, Freigabe-Haken offen, obwohl State `spec_approved` |
| `LooseEnds/Notifications/PlaceNotificationCenter.swift` (~290 Z.) | `NotificationCategories`, `PlaceNotifications`, `ReconcileGate`, `PlaceSeed` (DEBUG), `PlaceNotificationCenter` (iOS) |
| `LooseEnds/Notifications/DueNotificationCenter.swift` | Anschluss: Kategorien zusammen, `rescheduleDue` + `place.reconcile()`, Antwort setzt Marke, `willPresent` setzt Marke bei `place_` |
| `LooseEndsTests/PlaceNotificationCenterTests.swift` | 13 macOS + 17 iOS Tests, grün auf dem alten Stand |
| `project.yml` | eine Zeile: `NSLocationWhenInUseUsageDescription` |
| `scripts/sim.sh` | Argumente an `device-launch` (nur für die Debug-Starthilfe) |
| `docs/artifacts/feat-226-schnitt-2b/` | Adversary-Protokoll, Testausgaben, Simulator-Durchlauf mit Gerätebefund 2026-10-08 |

## Stand der Belege (aus dem Protokoll)
- AC-1 bis AC-10, AC-12 bis AC-15 belegt auf dem alten Stand (Tests, Simulator, Screenshots).
- **Gerät, 2026-10-08:** Ortsmitteilung kam beim echten Heimkommen, Marke gesetzt, Merkliste geleert; zweite
  Mitteilung nur aus dem Zustand geschlossen, nicht beobachtet. Knöpfe auf dem Gerät nicht gesehen.
  Anlegen innerhalb des Bereichs löst nicht aus (Known Limitation, erst beim nächsten Betreten).
- Offen laut Verdict: (1) AC-11 zweites Ankommen nicht beobachtet, (2) Knöpfe der Ortsmitteilung auf dem Gerät.
  Beides sind Geräte-Beobachtungen, keine Codefehler. F004 (LOW): kein Abgleich bei Rückkehr in den Vordergrund.

## Related Files auf `main` (Stand heute)
| File | Relevanz |
|------|----------|
| `Shared/Notifications/PlaceReminders.swift` | `plan`, `markDelivered`, `identifierPrefix` (unverändert nutzbar) |
| `Shared/Notifications/PlaceDelivery.swift` | `diff`, Handover, Fingerprint; reine Planung |
| `Shared/Services/PlaceEditing.swift` | Ort setzen/ändern/entfernen (#241 Schnitt 3a, gemergt): **echte Bedienung existiert** |
| `LooseEnds/Notifications/DueNotificationCenter.swift` | seit der Basis stark umgebaut: Callback-Delegate (#295), `taskToOpen` (#331), `DueScheduling` (#328), Badge (#299), Erinnerungszeit/iCloud (#311) |
| `LooseEnds/App/LooseEndsApp.swift`, `ContentView.swift` | erzeugen `DueNotificationCenter`; Auslöser des Abgleichs (`didSave`, `startUp`) |
| `project.yml` | enthält **kein** `NSLocationWhenInUseUsageDescription` |
| `LooseEndsTests/DueNotificationCenterTests.swift` | neu seit der Basis, deckt den Scheduler-Ersatz ab; Berührungspunkt für Regression |

## Kollisionen: alter Stand gegen `main`
- `DueNotificationCenter.swift` ist der Hauptkonflikt. Der alte Anschluss ersetzt `didReceive`/`willPresent`
  durch die **async**-Fassung; `main` verlangt seit #295 die Completion-Handler-Fassung (async brach beim
  Tippen ab) und `taskToOpen` (#331). Der Anschluss muss auf die Callback-Fassung neu gesetzt werden.
- `reschedule()` hat auf `main` Badge und den `DueScheduling`-Ersatz; `place.reconcile()` kommt dahinter,
  `place_` und `due_` greifen sich nicht an.
- `setNotificationCategories` darf nur einmal mit beiden Kategorien aufgerufen werden (jeder Aufruf ersetzt alle).
- Unverändert gültig: `DueReminders.Action`, `PlaceReminders.markDelivered`, `PlaceDelivery.diff`.

## Existing Patterns
- Reine Entscheider in `Shared/`/Enums, dünner Systemanschluss in `LooseEnds/Notifications/`, still unter Tests
  (`isRunningTests`, `isUITesting`); Fälligkeits-Mitteilungen per `simctl push` für Banner-UI-Tests (#295).
- Ein Abgleich zugleich (`ReconcileGate`), Merkliste in `UserDefaults` je Gerät.

## Dependencies
- Upstream: `PlaceReminders`, `PlaceDelivery`, `DueReminders`, `CLLocationManager`, `UNUserNotificationCenter`.
- Downstream: `DueNotificationCenter` (Delegate für beide), `PlaceEditing`/#241 (Hinweis „Ort erinnert beim nächsten
  Betreten“), später #25 (Siri-Schema setzt Orte).

## Existing Specs
- `docs/specs/feat-226-schnitt-4-zustellung.md` (Teil B überholt), `feat-226-ortserinnerungen.md`,
  `feat-226-schnitt-2a-uebergabe.md`, `feat-226-schnitt-3a-ort-im-detail.md`; Vorlage `feat-226-schnitt-2b-systemanschluss.md` (nur im alten Worktree).

## Risks & Considerations
- **Gerätestufe Pflicht**: berührt `LooseEnds/Notifications/` und `project.yml` (Info.plist-Schlüssel). Nachweis seit #279
  über TestFlight, erst nach Hennings Wort; vorher nichts auf seinen Geräten.
- **Debug-Starthilfe `-le-seed-place` entfällt**: Sie war Wegwerfcode „bis Schnitt 3“; Schnitt 3a ist gemergt. Das spart
  `PlaceSeed`, `seedIfAsked` und die `sim.sh`-Änderung, ist aber eine Abweichung von Spec-AC-5 (Spec anpassen).
- **Modell unverändert**: `placeRemindedAt` existiert (PR #248), kein CloudKit-Schema-Schritt nötig.
- Scoping: Umsetzung ~290 + ~60 Zeilen plus Tests; Prüfen gegen das 250-Zeilen-Limit, sonst Teil-Specs.
- Das Alt-Protokoll gilt nicht mehr (anderer Stand, andere Basis): Gegenprüfung läuft neu.
- Der alte Worktree wird nicht gelöscht und nicht verändert (Quelle der Vorarbeit, bis der Schnitt gemergt ist).
- Alternative zum Übernehmen: Ortsmitteilung neu und kleiner entwerfen (z. B. ohne eigene Merkliste); würde die
  Entscheidung aus 2a (Merkliste statt Ersetzen) kippen. Nicht empfohlen, da gerätebelegt.

## Analysis

### Type
Feature (Systemanschluss der Ortserinnerung; #240 Teil B = #226 Schnitt 2b). Kein Modell im Spiel.
„Ohne Modell geht es“: Es gibt kein Sprachverstehen, nur Regeln und Systemaufrufe.

### Recherche (2026-10-14, vor allem anderen)
| Frage | Befund | Quelle |
|---|---|---|
| `UNLocationNotificationTrigger` noch richtig? | Ja, nicht veraltet; braucht `CLRegion`/`CLCircularRegion`, iOS/watchOS, nicht macOS | Apple-Doku (Recherche 2026-10-07 in Alt-Spec, heute gegengelesen) |
| `CLMonitor` (iOS 17+) als Ersatz | Ersetzt Beacon-/Region-Überwachung, liefert aber keine Mitteilung; App müsste selbst zustellen und „Immer“ verlangen | Forum 806783, 748708 |
| 20-Regionen-Grenze, Radius | Grenze bleibt; unter ~100 m unzuverlässig, 150 m ok (Plan nutzt 150 m) | Forum 790110 |
| Anlegen im Bereich | Nirgends dokumentiert → Messung (Alt-AC-12, Gerät 2026-10-08: löst nicht aus, Known Limitation) | – |

### Befund: Vorarbeit trägt, passt aber nicht ungeändert auf `main`
- Alt-Stand (Worktree `jazzy-crunching-trinket`, Basis 75 Commits alt): `PlaceNotificationCenter.swift` 294 Z., Tests 278 Z.,
  Anschluss in `DueNotificationCenter` ~40 Z., `project.yml` 1 Z. Gerätebeleg 2026-10-08: Ortsmitteilung kam beim
  Heimkommen, Marke gesetzt, Merkliste geleert.
- `main` hat `DueNotificationCenter` umgebaut (Callback-Delegate #295, `taskToOpen` #331, `DueScheduling` #328, Badge #299, `suppressed`).
  Der Anschluss ist **neu zu setzen**, nicht zu übernehmen. Zwei Kategorien nur in **einem** `setNotificationCategories`-Aufruf.
- **Echte Bedienung existiert** (`PlaceSection` im Detail, #241 3a). Damit entfallen `PlaceSeed`, `seedIfAsked`, `sim.sh`-Änderung
  und Alt-AC-5/-18/-19; der Simulator-Durchlauf geht über die echte Oberfläche („Ort setzen“ → Freigabe-Dialog).
- Abgleich bei Rückkehr in den Vordergrund (Alt-F004) ist auf `main` schon da: `ContentView` ruft bei `scenePhase == .active`
  `rescheduleSoon()`; hängt `place.reconcile()` an `reschedule()`, ist F004 erledigt.
- `PlaceEditing.Note` kennt noch keine „Freigabe fehlt“-Zeile (Schnitt 3b, #241) – bleibt draußen; der Wert `authorized` wird nur abfragbar gemacht.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Notifications/PlaceNotificationCenter.swift` | CREATE | Kategorien (`DUE`+`PLACE`), Freigabe-/Frage-Entscheidung, `ReconcileGate`, Antwort→Marke (plattformneutral); `#if os(iOS)`: `CLLocationManager`, `request(for:)`, `reconcile` |
| `LooseEnds/Notifications/DueNotificationCenter.swift` | MODIFY | besitzt Orts-Center, ein Kategorien-Aufruf, `reschedule` ruft `reconcile`, `place_`-Antworten setzen Marke (Callback-Fassung) |
| `project.yml` | MODIFY | `NSLocationWhenInUseUsageDescription` (Geräteliste!) |
| `LooseEndsTests/PlaceNotificationCenterTests.swift` | CREATE | Unit-Tests (macOS-Lauf plus iOS-Teil über `sim-unit`) |

### Scope Assessment
- Files: 4. Ungeteilt ~ +520 LoC (Produkt ~300 ohne Seed, Tests ~220) → **sprengt das 250-LoC-Limit** (CLAUDE.md: stoppen, splitten).
- **Vorschlag zwei Teil-Specs / Workflows** (Memory „Mehrere Schnitte = Teil-Specs“):
  - **Schnitt 1 – Bausteine (rein, plattformneutral, CI):** Kategorienmenge, Freigabe- und Frage-Entscheidung, `ReconcileGate`,
    Antwort→Marke-Verteilung, Präfix-Filter + Tests. ~ +230. Kein Pfad der Geräteliste außer `LooseEnds/Notifications/`-Datei (nur reine Logik).
  - **Schnitt 2 – Systemanschluss (Gerätestufe):** `PlaceNotificationCenter` (iOS), `request(for:)`, `reconcile`, Anschluss in
    `DueNotificationCenter`, `project.yml`, iOS-Tests. ~ +230. Simulator über echte Oberfläche, Gerät über TestFlight nach Hennings Wort.
- Risk Level: MEDIUM (Kategorien-Überschreiben nimmt Fällig-Knöpfe; Delegate-Abbruch #295; neue Berechtigung).

### Technical Approach (Empfehlung)
Alt-Spec 2b übernehmen, auf `main` neu anschließen, ohne Debug-Starthilfe; zuerst Schnitt 1 (rein), dann Schnitt 2.
Unverändert: Merkliste je Gerät (2a) + Marke `placeRemindedAt` „Einmal für alle“ + `UNLocationNotificationTrigger`, „Beim Verwenden“ erst beim ersten Ort.

### Befunde, die gegen den Plan sprechen
Keine neuen. Bekannt: Anlegen im Bereich löst nicht aus (gemessen 2026-10-08), Zustellung mit Systemverzögerung (Forum 790110),
Ignoriert/zugestellt unterscheidbar nur über Marke + Merkliste (Forum 777251).

### Alternativen
| | Weg | Dafür | Dagegen / was kippt |
|---|---|---|---|
| **A (Empfehlung)** | Systemtrigger + Merkliste + Marke, in 2 Schnitten | gerätebelegt, keine „Immer“-Freigabe | 2 Workflows |
| B | Alles in einem Workflow | ein Ticket | ~520 LoC, Limit gesprengt |
| C | `CLMonitor` + „Immer“, App stellt selbst zu | volle Kontrolle, filtert Fehlauslösungen | kippt F1/ADR-Antwort 14, Hintergrundmodus, strengere Prüfung; nur Rückfall |
| D | Nur Marke, keine Merkliste | weniger Code | ignorierte Mitteilung → Wiederholung beim nächsten Speichern (2a-Entscheidung) |
| E | Ort-Erinnerung als Vorschlag in der Fällig-Mitteilung statt Geo-Trigger | kein Standortrecht | verfehlt den Produktzweck „beim Ankommen“ |

### Dependencies
`PlaceReminders` (plan, markDelivered), `PlaceDelivery` (diff, Handover), `DueReminders` (Action, handle), `PlaceEditing`/`PlaceSection` (Bedienung),
`ModelContainerFactory.isRunningTests/isUITesting`, `CoreLocation`, `UserNotifications`. Downstream: #241 Schnitt 3b (Freigabe-Hinweis liest `authorized`), #25.

### Open Questions
- [ ] Teilung in 2 Schnitte bestätigen (Entscheidung steht bei Henning, weil Limit-Überschreitung).
- [ ] Gerätelauf (TestFlight) erst nach Hennings „jetzt ist ein Test möglich“; Prüfort für den Lauf klären.
- [ ] Alt-Worktree `jazzy-crunching-trinket` bleibt unangetastet, bis Schnitt 2 gemergt ist.
