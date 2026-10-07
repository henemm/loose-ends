# Context: feat-226-zustellung (#226, Zustellung der Ortserinnerung)

## Request Summary
Die geplanten Orte aus `PlaceReminders.plan` (Schnitt 1, PR #239) werden dem System übergeben, sodass
das iPhone beim Ankommen oder Verlassen eine Mitteilung zeigt, auch bei geschlossener App. Mit den
Aktionen „Erledigt“ und „Als nächstes“ und mit der Standortfreigabe „Beim Verwenden der App“, gefragt
beim ersten Ort. Anzeige und Bearbeitung (Schnitt 3) und die Siri-Abbildung (#25) sind nicht Teil davon.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Notifications/PlaceReminders.swift` | Reine Planung (`plan`, Grenze 20, `Reminder.identifier = "place_<uuid>"`). Kennt weder Radius noch Zustellmarke. |
| `Shared/Models/TaskPlace.swift` | Name, Koordinate, Ereignis `arrive`/`depart`, Radius fest 150 m. |
| `Shared/Models/TaskItem.swift:35` | Feld `place` und `placeSourceRaw`. **Es gibt kein `placeRemindedAt` und kein `markDelivered`**, anders als der Ticket-Kommentar annahm. |
| `Shared/Notifications/DueReminders.swift` | Vorbild: `Action` (done/next/tomorrow), `handle(...)` wendet Aktionen an. Wiederverwendbar für done/next. |
| `LooseEnds/Notifications/DueNotificationCenter.swift` | Systemkleber: Kategorie, `reschedule` (entfernt ALLE `due_`-Anfragen und legt neu an), Delegate, `apply`. Unter Tests still. Einzige Stelle mit `UNUserNotificationCenter`. |
| `LooseEnds/App/ContentView.swift:76,95,122` | `didSave` → `rescheduleSoon()`; Start → `requestAuthorization()` und `reschedule()`; Onboarding ruft `requestNotifications`. |
| `LooseEnds/App/LooseEndsApp.swift:8,19` | Besitzt `DueNotificationCenter(container:)`. |
| `project.yml:60-80` | `info.properties` erzeugt `LooseEnds/Info.plist`: dort kommt `NSLocationWhenInUseUsageDescription` hinein. **Geräteliste.** |
| `LooseEnds/PrivacyInfo.xcprivacy` | Keine gesammelten Datentypen. Ort bleibt auf dem Gerät. Prüfen, ob Ortszugriff einen Eintrag verlangt. |
| `Shared/Services/TaskActions.swift:13` | `complete`: Wiederholung rückt `dueDate` weiter und bleibt offen. Hier würde ein Wiederscharfmachen hängen. |
| `LooseEndsTests/PlaceRemindersTests.swift`, `DueRemindersTests.swift` | Vorbilder für die Tests. |
| `docs/specs/feat-226-ortserinnerungen.md`, `feat-226-schnitt-1-ortsfeld.md` | Master-Spec (Antworten F1–F7) und Schnitt 1. Zeile 113–114 von Schnitt 1: `repeats: false` setzt die Zustellung. |

## Existing Patterns
- Planung rein in `Shared/Notifications`, Systemzugriff in `LooseEnds/Notifications`, unter Tests und `--ui-testing` stumm (`suppressed`).
- Ein Bezeichner-Präfix je Art (`due_`, `place_`), Neuplanung ersetzt alles mit dem Präfix.
- Aktion → `DueReminders.handle` → `context.save()` → `reschedule()`.
- Berechtigungen werden mit Fehler-Logger abgefragt, nie mit `try?`.

## Dependencies
- Upstream: `PlaceReminders.plan`, `TaskPlace`, `TaskItem.isOpen`, `DueReminders.handle`, `UserNotifications`, **neu** `CoreLocation` (`CLLocationManager`, `CLLocationCoordinate2D`, `CLCircularRegion`).
- Downstream: Schnitt 3 (Ortszeile braucht den Berechtigungsstatus für den grauen Hinweis „Standort ist in den Einstellungen aus“), #25 (Siri setzt einen Ort, die Zustellung muss ohne UI funktionieren).

## Befunde, die die Analyse klären muss
1. **Doppelte Erinnerung.** `UNLocationNotificationTrigger(repeats: false)` verschwindet nach dem Auslösen aus den offenen Anfragen. `reschedule` läuft aber nach jedem Speichern und legt jede Aufgabe aus dem Plan neu an, also erinnerte dieselbe Aufgabe nach der nächsten Änderung erneut. Es braucht eine Zustellmarke („hat erinnert“). Alternativen: synchronisiertes Feld am `TaskItem` (CloudKit-Schemaänderung, additiv) oder lokale Merkliste je Gerät.
2. **Wie erfährt die App, dass es ausgelöst hat?** Läuft die App nicht, gibt es keinen Rückruf. Möglich: beim Start/Speichern „war angelegt, ist nicht mehr offen“ vergleichen, oder `getDeliveredNotifications`, oder die Aktion in der Mitteilung. Muss gemessen werden, nicht angenommen.
3. **Neuanlegen löst neu aus?** `reschedule` entfernt und legt jede Anfrage bei jedem Speichern neu an. Bei Ortsauslösern kann ein Neuanlegen innerhalb des Bereichs das Ereignis beeinflussen. Besser nur Unterschiede nachziehen. Auf dem Gerät belegen.
4. **Wiederholung (F3).** Nach `TaskActions.complete` einer wiederkehrenden Aufgabe muss die Zustellmarke fallen.
5. **Freigabe.** `CLLocationManager.requestWhenInUseAuthorization()` erst, wenn der Plan zum ersten Mal nicht leer ist; unter Tests still; abgelehnt = Ort bleibt gespeichert, nichts erinnert (Hinweistext kommt mit Schnitt 3, der Status muss dafür abfragbar sein).
6. **Plattformen.** `UNLocationNotificationTrigger` gibt es nicht auf macOS; die App ist ein Ziel für iOS, iPadOS und macOS, also `#if os(iOS)` im Systemkleber und ein sauberer Nicht-Pfad auf dem Mac. Die Watch spiegelt nur, das Watch-Ziel übersetzt `LooseEnds/Notifications` nicht.
7. **Mitteilung:** Titel = Aufgabentitel, Text „Du bist bei <Ort>“ bzw. „Du hast <Ort> verlassen“, eigene Kategorie mit „Erledigt“ und „Als nächstes“ (kein „Morgen“, F4).
8. **Mehr als 20 Orte:** `Plan.unwatched` wird bisher nirgends angezeigt oder protokolliert. Mindestens Logger; die Anzeige gehört zu Schnitt 3.
9. **Nachweis:** Der Simulator kann einen Ort vortäuschen (`simctl location`), aber keine Systemüberwachung des echten Ortswechsels belegen. Gerätestufe Pflicht (`project.yml`/`Info.plist`, `LooseEnds/Notifications/`). Ohne Schnitt 3 gibt es auf dem Gerät keine Bedienung, einen Ort zu setzen: der Gerätebeleg braucht einen Weg, einen Ort an eine Aufgabe zu bringen (Prüfbau-Starthilfe oder Schnitt 3 zuerst). Das ist ein Punkt der Analyse.

## Risks & Considerations
- Berührt `Info.plist`/`project.yml`, Berechtigung und Mitteilungen: Klasse „App-Group-Absturz“, Gerätestufe nicht verhandelbar.
- Schemaänderung für CloudKit nur, wenn die Marke als Feld am `TaskItem` gewählt wird. Produktion ist laut Master-Spec noch nicht ausgerollt (#175).
- Scoping: Ziel ≤ 4–5 Dateien, ±250 Zeilen. Wahrscheinlich: `PlaceReminders.swift` (Marke, Diff), `DueNotificationCenter.swift` oder neue Datei daneben, `project.yml`, Tests, evtl. `TaskItem.swift` und `TaskActions.swift`. Bei Überschreitung teilen.
- Recherche zuerst (Hennings Regel): vor der Analyse die Verhaltensberichte zu `UNLocationNotificationTrigger` (Auslösen beim Anlegen innerhalb des Bereichs, Verhalten nach `repeats: false`, iOS 26/27) lesen und mit Quellen berichten.
- Alternative zum Bisherigen: keine Marke, sondern die Überwachung nur bei Plan-Änderung neu anlegen und eine ausgelöste Anfrage als erledigt betrachten, solange Ort und Aufgabe unverändert sind. Das kippt keine ADR, spart aber das CloudKit-Feld.

## Analysis

### Type
Feature (Schnitt 2 von #226: Zustellung).

### Recherche (vor der Analyse, 2026-10-07)
| Frage | Befund | Quelle |
|---|---|---|
| Erfährt die App, dass eine Ortsmitteilung zugestellt wurde? | **Nein, absichtlich.** `getDeliveredNotifications()` liefert Mitteilungen mit `UNLocationNotificationTrigger` nicht; Apple DTS: „intentional behavior intended to protect user privacy“, es gebe keinen Weg zu wissen, ob sie da waren. Nur wenn der Nutzer die Mitteilung bedient (Knopf, Tippen), erfährt die App davon. | [Forum 777251](https://developer.apple.com/forums/thread/777251) |
| Berechtigung | Vor dem Anlegen muss „Beim Verwenden“ vorliegen; „Immer“ ist nicht nötig, weil das System überwacht. | [Apple: UNLocationNotificationTrigger](https://developer.apple.com/documentation/usernotifications/unlocationnotificationtrigger) |
| Auslösung | Nicht sofort an der Kante; das System wendet Heuristiken an. Überwachung läuft über WLAN-Ortung; Apple rät zu **150–200 m**, 50 m sind „too small for reliable triggers“. Unser Radius 150 m liegt im Rahmen. | Apple-Doku ebenda; [Forum 790110](https://developer.apple.com/forums/thread/790110) |
| Plattform | iOS, iPadOS, watchOS; **kein macOS**. | Apple-Doku (Availability) |
| Limit | 20 überwachte Regionen je App, vom System erzwungen. | [Sentiance](https://docs.sentiance.com/sdk/appendix/ios/ios-region-monitoring), Forum 790110 |
| Verhalten beim Anlegen *innerhalb* des Bereichs, Neuanlegen löst neu aus? | **Nicht belegt.** Die Suche liefert nur Vermutungen. Wird auf Simulator und Gerät gemessen, nicht angenommen. | offen |

### Folge für Befund 1/2 (der Kern)
Die Idee „Zustellmarke am TaskItem, gesetzt wenn das System ausgelöst hat“ **geht nicht**: Es gibt kein
Signal dafür. Ignoriert Henning die Mitteilung, erfährt die App nie, dass sie kam.
Damit entfällt auch ein CloudKit-Feld. Was die App weiß, ist nur, **was sie dem System übergeben hat**.

**Empfehlung (Regelweg, kein Modell, es ist keines im Spiel): Übergabe-Merkliste je Gerät.**
- Pro Gerät eine kleine Liste „übergeben“: Aufgaben-ID + Fingerabdruck (Ort, Ereignis; bei wiederkehrenden
  Aufgaben zusätzlich das Fälligkeitsdatum = der Zyklus). Ablage in `UserDefaults` (Privacy-Manifest
  deckt UserDefaults bereits, CA92.1). Passt zu Master-Spec Punkt 6 „Jedes iPhone plant selbst“.
- Reine Funktion `PlaceDelivery.diff(plan, übergeben, offeneAnfragen)` → welche Anfragen neu, welche
  weg, neue Merkliste. Es wird nur der Unterschied nachgezogen, nie alles neu angelegt (Befund 3).
- Ausgelöste Anfrage verschwindet aus den offenen Anfragen, bleibt aber in der Merkliste mit gleichem
  Fingerabdruck → wird **nicht** neu angelegt, also keine doppelte Erinnerung (Befund 1).
- Ort oder Ereignis geändert → neuer Fingerabdruck → wird neu übergeben und kann wieder erinnern.
- Wiederkehrend (F3): `TaskActions.complete` rückt `dueDate` weiter → Fingerabdruck ändert sich →
  scharf für den nächsten Zyklus. **Keine Änderung an `TaskActions`** nötig (Befund 4).
- Erledigt, geparkt, Ort entfernt → Anfrage und Eintrag fallen; wiederhergestellt → neu (Master-Spec 2).
- Titeländerung: Inhalt nur ersetzen, solange die Anfrage noch offen ist; nie als Anlass zum Neuauslösen.
- Ist die Freigabe noch nicht erteilt, wird **nichts** übergeben **und nichts vermerkt**, sonst käme es
  nach der Freigabe nie an.

### Alternativen (bewusst benannt)
| | Weg | Dafür | Dagegen |
|---|---|---|---|
| **A (Empfehlung)** | Merkliste je Gerät + Unterschied | Kein Schema, keine neue Berechtigung, testbar als reine Funktion | Neuinstallation = Merkliste leer: Aufgaben werden neu übergeben (harmlos, wird gemessen) |
| B | Zustellmarke als Feld am `TaskItem` (CloudKit) | Reist zwischen Geräten | **Nicht herstellbar**: kein Auslösesignal. Nur bei Bedienung der Mitteilung bekannt; Ignorieren bliebe unsichtbar. Dazu Schemaänderung |
| C | Direkt `CoreLocation` (`CLMonitor`) mit „Immer“-Berechtigung, App stellt selbst Mitteilungen zu (Apples eigener Rat im Forum 790110) | App kennt jeden Auslöser, Marke wäre möglich, volle Kontrolle | Kippt die Festlegung „Beim Verwenden der App“ (F1/ADR 14), braucht „Immer“ und Hintergrundmodus Standort, schwerere Freigabe im Store, mehr Code. Nur sinnvoll, wenn A im Gerätelauf versagt |
| D | Keine Merkliste, Überwachung nur bei Plan-Änderung neu anlegen (Alternative aus dem Kontext) | Kein Speicher | Plan-Änderung ist jede Rangänderung (Ranking hängt an `nextRank`, Fälligkeit); ohne Gedächtnis kein sicheres „schon erinnert“. Löst Befund 1 nicht |

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Notifications/PlaceDelivery.swift` | CREATE | Fingerabdruck, Merkliste, `diff`; rein, ohne System |
| `LooseEnds/Notifications/PlaceNotificationCenter.swift` | CREATE | `#if os(iOS)`: Anfragen mit `UNLocationNotificationTrigger` (150 m, Ereignis), Kategorie `PLACE`, `CLLocationManager`-Freigabe, Statusabfrage; unter Tests und `--ui-testing` still; Mac: sauberer Nicht-Pfad |
| `LooseEnds/Notifications/DueNotificationCenter.swift` | MODIFY | Beide Kategorien **zusammen** setzen (`setNotificationCategories` ersetzt alles), `reschedule` ruft Orts-Abgleich; `apply` bleibt, weil `PLACE` dieselben Aktions-IDs `DUE_DONE`/`DUE_NEXT` nutzt |
| `project.yml` | MODIFY | `NSLocationWhenInUseUsageDescription` (Text aus Master-Spec) → **Geräteliste** |
| `LooseEndsTests/PlaceDeliveryTests.swift` | CREATE | Diff, Fingerabdruck, Wiederholung, Titelwechsel, fehlende Freigabe, Grenze 20 |
| `LooseEndsUITests/…` | ggf. CREATE | Nur wenn der Simulator-Versuch die Kette trägt (siehe Nachweis) |

### Scope Assessment
- Files: 5–6, LoC geschätzt +330/−10 → **über den Grenzen** (4–5 Dateien, ±250).
- **Vorschlag: zwei Schnitte innerhalb von #226** (ein Ziel, eine DoD, zwei PRs, kein neues Ticket):
  - **2a Planung der Übergabe:** `PlaceDelivery` + Tests (rein, ~150 LoC, 2 Dateien).
  - **2b Systemanschluss:** `PlaceNotificationCenter`, Kategorien, `project.yml`, Freigabe, Nachweis (~180 LoC, 3–4 Dateien, Geräteliste greift).
- Risk Level: MEDIUM (Systemverhalten ist teils unbelegt; berührt `project.yml`/Info.plist).

### Technical Approach
Siehe „Folge für Befund 1/2“. Zusätzlich:
- **Mitteilung** (Master-Spec, bereits freigegeben): Titel = Aufgabentitel, Text „Du bist bei <Ort>.“ bzw.
  „Du hast <Ort> verlassen.“, Knöpfe Erledigt, Als nächstes (kein Morgen, F4).
- **Freigabe:** `requestWhenInUseAuthorization()` erst, wenn der Plan zum ersten Mal nicht leer ist, nicht im
  Onboarding. Statusänderung (`locationManagerDidChangeAuthorization`) löst einen Abgleich aus. Status
  ist abfragbar, damit Schnitt 3 den grauen Hinweis zeigen kann.
- **Mac:** `UNLocationNotificationTrigger` gibt es dort nicht → `#if os(iOS)`, der Mac übergibt nichts.
  Watch übersetzt `LooseEnds/Notifications` nicht und spiegelt nur.
- **Über 20:** `Plan.unwatched` wird per `Logger` benannt; Anzeige gehört zu Schnitt 3.
- **Privacy-Manifest:** Die App liest nie einen Standort, das System überwacht. Voraussichtlich kein
  Eintrag nötig; die Archivprüfung (#177) bestätigt das.

### Nachweis (Befund 9) — ehrlich
- Stufe 1: Unit-Tests der reinen Funktion (rot → grün).
- Stufe 2, Simulator: Beim Start mit gesetztem Ort erscheint die Freigabefrage; die Übergabe steht im Log
  (`pendingNotificationRequests` mit Regionsauslöser). **Erster Schritt von 2b ist ein Kurzversuch:** trägt
  `simctl location` Ein- und Austritt bis zur Mitteilung samt Knopf? Wenn ja, ist die ganze Kette im Simulator
  automatisierbar. Wenn nein, wird das im Bericht so gesagt.
- Stufe 3 (Geräteliste greift): `device-status`. **Ein echter Ortswechsel lässt sich auf dem Gerät nicht
  automatisieren.** Das bleibt offen und wird im Abschlussbericht als offen benannt (wie Watch, Widgets).
- **Es gibt noch keine Bedienung, einen Ort zu setzen** (Schnitt 3). Für den Durchlauf braucht 2b eine
  Starthilfe, die nur Debug-/Prüfbauten kennen: Startargument, das der ersten offenen Aufgabe einen Ort
  setzt (~20 LoC, nicht im Store-Bau). Alternative: Schnitt 3 zuerst. Empfehlung: Starthilfe, weil
  Schnitt 3 den Berechtigungsstatus aus 2b braucht, nicht umgekehrt.

### Dependencies
- Upstream: `PlaceReminders.plan`, `TaskPlace`, `TaskItem.isOpen`/`dueDate`/`repeatRule`, `DueReminders.Action`/`handle`, `UserNotifications`, **neu** `CoreLocation`.
- Downstream: Schnitt 3 (Statusabfrage), #25 (Siri setzt Ort; Zustellung läuft ohne UI), #237.

### Open Questions
- [ ] Löst ein Anlegen *innerhalb* des Bereichs sofort aus? (Messung in 2b, kein PO-Thema)
- [ ] Beim Wechsel einer Aufgabe über Rang 20 hinaus und zurück: erinnert sie erneut? Vorschlag: ja, weil Rang-Verlust den Merklisten-Eintrag löscht. Randfall, wird in der Spec festgehalten.
- [ ] iPad und iPhone erinnern beide (jedes plant selbst, Master-Spec 6). Gewollt? Vorschlag: ja, unverändert.
