# Context: feat-240-schnitt-2-zustellung

## Request Summary

#240 Schnitt 2: Eine Aufgabe mit Ort meldet sich beim Ankommen oder Verlassen auf dem iPhone mit
„Du bist bei <Ort>.“, auch wenn die App nicht läuft. Die reinen Bausteine (Schnitt 1, PR #410) sind gemergt;
jetzt folgt der Systemanschluss. Henning hat am 2026-10-14 „alles in einem Durchgang“ gewählt — bewusste
Ausnahme vom 250-Zeilen-Limit (geschätzt rund 300–450 Zeilen samt Tests).

## Related Files

| File | Relevance |
|------|-----------|
| `LooseEnds/Notifications/DueNotificationCenter.swift` | Delegate für alle Mitteilungen (Callback-Fassung #295, `taskToOpen` #331). Registriert heute nur `[Self.category]` — muss auf `NotificationCategories.all()` umstellen, sonst überschreibt einer den anderen. `didReceive`/`willPresent` müssen `place_`-Mitteilungen über `PlaceNotifications.respond` leiten (Marke setzen). |
| `LooseEnds/Notifications/PlaceNotificationCenter.swift` | **NEU.** Vorarbeit liegt in Worktree `jazzy-crunching-trinket` (Zeilen 129–294 dort, rund 165 Zeilen): `CLLocationManager`, Freigabe einmal fragen, Abgleich mit `PlaceDelivery.diff`, Merkliste in `UserDefaults`, `UNLocationNotificationTrigger` mit `CLCircularRegion`. Alles unter `#if os(iOS)`. |
| `Shared/Notifications/PlaceNotifications.swift` | Schnitt 1, gemergt: `NotificationCategories.all()`, `Permission`, `isAuthorized`, `shouldRequestAuthorization`, `isSilent`, `pendingPlaceIdentifiers`, `respond`, `ReconcileGate`. |
| `Shared/Notifications/PlaceReminders.swift` | `plan` (≤ 20 Orte, Rang), `markDelivered`, Präfix `place_`. |
| `Shared/Notifications/PlaceDelivery.swift` | `diff` (hinzufügen / zurücknehmen / Titel ersetzen / Merkliste), `Handover` (Codable). |
| `LooseEnds/App/LooseEndsApp.swift` | Erzeugt `DueNotificationCenter` und ruft `activate()`; hier kommt `PlaceNotificationCenter` dazu (iOS). |
| `LooseEnds/App/ContentView.swift` | Löst nach jedem `ModelContext.didSave` und beim Wechsel in den Vordergrund `rescheduleSoon()` aus — derselbe Auslöser für den Ortsabgleich. |
| `project.yml` | `NSLocationWhenInUseUsageDescription` fehlt im App-Target (Vorarbeit hatte den Text). Gerätestufe. |
| `LooseEnds/Views/PlaceSection.swift`, `Shared/Services/PlaceEditing.swift` | Schnitt 3a gemergt: Ort setzen, Ereignis wechseln, Hinweise „nicht überwacht“ und „Mac“. Damit ist der Wegwerf-`PlaceSeed` der Vorarbeit überflüssig. |
| `Shared/Services/FieldCodec.swift:80`, `Shared/Services/TaskActions.swift:18` | Neuer Ort bzw. Wiederholung macht `placeRemindedAt` wieder scharf. |
| `LooseEndsUITests/DueNotificationTapTests.swift` | Vorbild für einen Mitteilungs-UI-Test mit `simctl push` und `--ui-testing-notifications`. |
| `LooseEndsUITests/PlaceSmokeTests.swift` | Bestehender Orts-Smoke-Test (3a). |

## Existing Patterns

- **System hinter Protokoll:** `DueScheduling` / `SystemDueScheduler` (#328) — Unit-Tests reichen einen Recorder
  hinein. Die Vorarbeit spricht `UNUserNotificationCenter` direkt an; für Testbarkeit wäre dasselbe Protokoll
  wiederverwendbar (`pendingIdentifiers`, `remove`, `add`).
- **Still unter Tests**, eigenes Argument für den UI-Test (`--ui-testing-notifications`, `--ui-testing-places`).
- **Entprellt** nach Speicherschüben (`rescheduleSoon`, 500 ms); dazu `ReconcileGate` gegen überlappende Läufe.
- **Callback-Delegates, nicht async** (#295), Completion auf dem Main-Thread.
- **Rein vs. System:** Entscheidungen in `Shared/`, Systemaufrufe in `LooseEnds/Notifications/`.

## Dependencies

- Upstream: `CoreLocation` (`CLLocationManager`, `CLCircularRegion`), `UserNotifications`
  (`UNLocationNotificationTrigger`), `PlaceReminders`, `PlaceDelivery`, `PlaceNotifications`, `DueReminders.handle`.
- Downstream: Fällig-Mitteilungen (gemeinsame Kategorienmenge, gemeinsamer Delegate), `OpenTaskRequest`
  (Tippen öffnet die Aufgabe), CloudKit-Abgleich der Marke `placeRemindedAt` auf andere Geräte.

## Existing Specs

- `docs/specs/feat-240-schnitt-1-bausteine.md` — Regeln 1–9, Festlegung „Einmal für alle“, Recherche, Alternativen.
- `docs/specs/feat-226-schnitt-2a-uebergabe.md` — Merkliste/`PlaceDelivery`.
- `docs/specs/feat-226-schnitt-4-zustellung.md` — Teil B, durch Schnitt 1 + 2 ersetzt.
- `docs/specs/feat-226-schnitt-3a-ort-im-detail.md` — Ort im Detail; 3b (Standort-Hinweis, „Aktueller Ort“) offen.

## Risks & Considerations

- **Kategorien überschreiben sich:** genau ein `setNotificationCategories`-Aufruf mit beiden Kategorien.
- **Delegate:** Es darf nur einen `UNUserNotificationCenter.delegate` geben — `DueNotificationCenter` bleibt es
  und leitet `place_` weiter.
- **Marke bei Anzeige:** `willPresent` (App im Vordergrund) und `didReceive` (Tippen/Knopf) setzen die Marke; bei
  geschlossener, ignorierter Mitteilung erfährt die App nichts → Merkliste schützt je Gerät.
- **Freigabe:** nur „Beim Verwenden“, nur mit Ort, einmal je Gerät, nur im Vordergrund; reduzierte Genauigkeit =
  keine Erinnerung.
- **Mac:** `UNLocationNotificationTrigger` gibt es nicht auf macOS → `#if os(iOS)`; iPad gehört dazu.
- **Simulator:** `add` aus der App scheitert im iOS-27-Simulator (UNErrorDomain 2003, Memory); ob ein Orts-Trigger
  im Simulator per `simctl location` auslöst, ist offen → Recherche in der Analyse.
- **Gerätestufe Pflicht** (`LooseEnds/Notifications/`, `project.yml`): nur nach Hennings „jetzt ist ein Test
  möglich“, über TestFlight (#279).
- **Limit:** Ausnahme von Henning; trotzdem nichts darüber hinaus (kein 3b, kein „Aktueller Ort“).

## Analysis

### Type
Feature (Systemanschluss zu den gemergten Bausteinen aus Schnitt 1)

### Recherche (2026-10-14)

| Frage | Befund | Quelle |
|---|---|---|
| Braucht die Ortsmitteilung „Immer“ oder Hintergrundmodus? | Nein. „Because the system actually monitors the regions, you don't need to request always permissions.“ Die App muss nicht laufen. Tutorials, die einen Hintergrundmodus verlangen, meinen die eigene Bereichsüberwachung per `CLLocationManager`, nicht diesen Auslöser. | [Apple-Doku](https://developer.apple.com/tutorials/data/documentation/usernotifications/unlocationnotificationtrigger.md), [Kodeco](https://www.kodeco.com/20690666-location-notifications-with-unlocationnotificationtrigger) |
| Auslöser verzögert? | Ja. Das System wendet Heuristiken an, damit nur eine absichtliche Grenzüberschreitung zählt, auf dem Gerät bis zu einige Minuten. | Apple-Doku (oben) |
| Zustellung sichtbar? | Ortsmitteilungen fehlen in `getDeliveredNotifications`. Deshalb Merkliste und Marke. | [Forum 777251](https://developer.apple.com/forums/thread/777251) |
| Simulator | Ortsmitteilungen kommen dort laut Fremdberichten nicht an. Zusätzlich lehnt der iOS-27-Simulator jedes `add` aus der App ab (UNErrorDomain 2003, eigene Messung vom 2026-10-10). Damit lässt sich die Kette vom Auslöser bis zum Banner im Simulator nicht belegen. Belegbar sind nur Antippen und Knöpfe einer von außen eingespielten Mitteilung (`simctl push`). | [MoEngage](https://moengage.com/docs/developer-guide/ios-sdk/push/optional/location-triggered), Memory `loose-ends-sim-mitteilung-add-2003` |

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Notifications/PlaceNotificationCenter.swift` | CREATE | `#if os(iOS)`. Ortslogik aus der Vorarbeit `jazzy-crunching-trinket` (Z. 129–294), ohne `PlaceSeed`. Sie bekommt schmale Prüfnähte: `PlaceScheduling` (pending, remove, add; `SystemDueScheduler` erfüllt es schon), eine Standort-Instanz (Status, Genauigkeit, Vordergrund, Freigabe erbitten) und einen Merklistenspeicher statt `UserDefaults.standard`. `reconcile` fängt eigene Fehler ab, damit der Lauf für Fälligkeiten nie bricht. |
| `LooseEnds/Notifications/DueNotificationCenter.swift` | MODIFY | `setNotificationCategories(NotificationCategories.all())` statt `[Self.category]`, private Kategorie entfällt. Es besitzt ein optionales `PlaceReconciling` (auf dem Mac nil). `reschedule()` ruft danach `reconcile`. Im Delegate werden Kennung und taskID als Strings gelesen. Bei `place_` läuft zuerst `PlaceNotifications.respond` (Marke + Knopf), dann `taskToOpen`. `willPresent` setzt die Marke in einem eigenen Main-Actor-Task, die Completion folgt sofort. **Es bleiben die Callback-Fassungen (#295).** Das Routing hängt nur am Präfix, nicht an der Stille des Ortszentrums. |
| `project.yml` | MODIFY | `NSLocationWhenInUseUsageDescription` im App-Target (Text aus der Vorarbeit, deutsch/englisch über Lokalisierung prüfen). |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | „You're at %@.“ → „Du bist bei %@.“ |
| `LooseEndsTests/PlaceNotificationCenterTests.swift` | CREATE | Recorder: Anfrage hat Kategorie PLACE, taskID, `UNLocationNotificationTrigger` mit 150 m, Ein-/Austritt passend, Kennung `place_<uuid>`; `due_` unberührt; zweiter Lauf ohne Änderung tut nichts; ohne Freigabe nur Zurücknehmen; Fehler bei `add` lässt Merkliste ungeschrieben; Freigabe nur einmal, nur mit Ort, nur im Vordergrund. |
| `LooseEndsTests/DueNotificationCenterTests.swift` | MODIFY | Routing: Tippen auf `place_` setzt Marke und öffnet die Aufgabe; „Complete“ erledigt und markiert; „Tomorrow“ auf `place_` tut nichts; `due_` unverändert; `reschedule` ruft `reconcile`. |
| `LooseEndsUITests/PlaceNotificationTapTests.swift` + `scripts/fixtures/place-reminder.apns` | CREATE | Wie `DueNotificationTapTests`: Banner einer Ortsmitteilung (Kategorie PLACE) per `test-proof` mit `LOOSEENDS_PUSH`. Langes Drücken zeigt „Complete“/„Next up“ ohne „Tomorrow“, „Complete“ erledigt die Aufgabe sichtbar, die App überlebt das Banner im Vordergrund. Dafür braucht es unter `--ui-testing-places` eine Prüfaufgabe mit fester UUID (…0240) und Ort, rund 15 Zeilen, nur unter UI-Tests. |
| `LooseEnds/App/LooseEndsApp.swift`, `ContentView.swift` | — | Keine Änderung: `didSave` und Vordergrund lösen schon `rescheduleSoon()` aus, und `reschedule` ruft den Ortsabgleich. |

### Scope Assessment
- Files: 7–8 (Ausnahme vom Limit hat Henning am 2026-10-14 freigegeben: „alles in einem Durchgang“)
- Estimated LoC: ca. +400 / −20 (Produkt ca. 210, Tests ca. 210)
- Risk Level: MEDIUM. Der Delegate ist der Weg aller Mitteilungen, und die Ortsfreigabe ist neu. Die Gerätestufe ist Pflicht (`LooseEnds/Notifications/`, `project.yml`), über TestFlight und nur nach „jetzt ist ein Test möglich“.

### Technical Approach
Empfehlung (A): `DueNotificationCenter` bleibt der einzige Delegate und besitzt den Ortsabgleich hinter einem kleinen Protokoll. Die Ortslogik der Vorarbeit wird übernommen, aber gegen den Stand nach #295/#328 neu angeschlossen. Unit-Tests mit Recorder sind der Hauptbeweis. Der UI-Test per `simctl push` belegt Antippen und Knöpfe. Der echte Ortsauslöser wird nur auf dem Gerät belegt.

Reihenfolge: RED (Unit + UI) → `PlaceNotificationCenter` → `DueNotificationCenter` → `project.yml` + generate → iOS-Build, Unit, Mac-Build als Gegenprobe für `#if` → `test-proof PlaceNotificationTapTests` + Regression `DueNotificationTapTests`, `PlaceSmokeTests` → Simulatorlauf mit Beleg → Merge → TestFlight (Ankommen und Verlassen bei geschlossener App, zweite Mitteilung bleibt aus).

### Alternatives
- **B: Ortszentrum gleichrangig in `LooseEndsApp`**, Antworten per Closure aus dem Delegate, ContentView löst zusätzlich aus. Damit bleibt `DueNotificationCenter` frei von Ortslogik. Dagegen spricht: zwei Dateien mehr und eine zweite Auslösestelle, die man vergessen kann. Für die Testbarkeit bringt es nichts.
- **C (aus Schnitt 1): `CLMonitor` + „Immer“, die App stellt selbst zu.** Damit hätte die App die volle Kontrolle und könnte Fehlauslösungen filtern. Dafür kippt F1 (ADR-Antwort 14 „Beim Verwenden“), es braucht einen Hintergrundmodus und eine strengere Prüfung. Das bleibt der Rückfall, falls der Gerätelauf den Systemauslöser als unzuverlässig zeigt.
- **D: UI-Test weglassen**, nur Unit-Tests. Das spart rund 100 Zeilen, verliert aber den Absturzschutz für den neuen Delegate-Pfad (#295). Abgewählt, weil UI-Tests Pflicht sind.

### Befunde gegen den Plan
- Die Vorarbeit nutzt async-Delegate-Methoden. Genau sie stürzten in #295 beim Antippen ab, deshalb wird sie nicht übernommen.
- `DueNotificationCenter.suppressed` und `PlaceNotifications.isSilent` sind zwei Schalter. Unter `--ui-testing-notifications` ist das Ortszentrum still. Das Routing darf deshalb nur am Präfix hängen, sonst bleibt der UI-Test blind.
- Ein Fehler bei `add` (im Simulator immer 2003) führt nicht zum Absturz. Er wird protokolliert, und der nächste Lauf versucht es erneut.

### Open Questions
- keine (Produktfragen F1–F7 und „Einmal für alle“ entschieden; Umfang freigegeben)
