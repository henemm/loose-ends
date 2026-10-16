---
entity_id: feat-25-s2b1-siri-intent
type: feature
created: 2026-10-16
updated: 2026-10-16
status: draft
workflow: feat-25-s2b-siri-intent
---

# Spec: #25 Schnitt 2b-1 — Der Siri-Intent „Erinnerung erstellen“ mit allen Feldern

## Approval

- [ ] Approved

## Purpose

Wer Siri sagt „Erinnere mich morgen um 9 an die Steuererklärung in Loose Ends, Liste Büro“, soll danach in Loose
Ends genau eine Aufgabe mit diesen Angaben finden. Schnitt 2b-1 baut dafür den fehlenden Schlussstein: den Intent
`CreateReminderIntent` (Apples Reminders-Schema `.reminders.createReminder`), der die Entitäten und die
Übersetzung aus Schnitt 2a mit `SiriCapture.prepare` und `commit` aus Schnitt 1 verbindet, dazu den echten
Geocoder für Adressen ohne Koordinate. Alle elf Felder des Schemas werden gespeichert oder sichtbar abgelehnt
(Henning, 2026-10-06: „erst alles bauen“). Lehnt `SiriCapture` etwas ab, wird der Fehler ohne eigenen Text
geworfen; Siri liest den allgemeinen Fehlersatz. Die vorgelesenen Fehlertexte de/en sind Schnitt 2b-2, ein eigener
Workflow.

Reihenfolge „Siri zuerst“ (Henning, 2026-10-16): Das größte Risiko ist, ob Siri den Schema-Weg auf Deutsch
überhaupt nimmt. Das zeigt nur das Gerät. Deshalb kommt der Intent vor den Fehlertexten; nimmt Siri den Weg nicht,
fallen die Fehlertexte weg oder wandern zum Rückfall (#446).

**Ohne Modell:** Siri liefert fertig strukturierte Werte; Übersetzung, Prüfung und Schreiben sind Regeln. Das
Sprachmodell setzt hier nichts. Nach dem Speichern läuft die Veredelung wie bei jeder Erfassung (ADR-4) und füllt nur
Felder, die Siri leer ließ.

## Source

- **Datei:** `LooseEnds/Intents/CreateReminderIntent.swift` (neu): `struct CreateReminderIntent: AppIntent`,
  `perform()`, testbarer Kern `static func create(_:in:geocode:) async throws -> TaskItem`
- **Datei:** `LooseEnds/Places/Geocoding.swift` (neu): `enum Geocoding` mit `static let live: SiriCapture.Geocode`
  und reiner Hilfsfunktion `coordinate(in:)`
- **Genutzt, unverändert:** `ReminderTranslation.input(title:note:dueDate:list:recurrence:locationTrigger:urls:isFlagged:tags:section:imageCount:)`,
  `SiriCapture.prepare(_:in:geocode:)` (`@MainActor`, `async throws`), `SiriCapture.commit(_:in:now:)` (`@MainActor`,
  `throws`, `@discardableResult`), `SiriCapture.Geocode = @Sendable (String) async throws -> Coordinate?`,
  `ReminderEntity(task:)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `SiriCapture`, `SiriCaptureError` (Schnitt 1) | module | Prüfen und Schreiben; Fehler und Aufräumen bleiben dort (kein Rest bei Fehler) |
| `ReminderTranslation`, `ReminderEntity`, `ListEntity`, `LocationTriggerEntity`, `SectionEntity` (Schnitt 2a) | module | SDK-Typen auf `Input`; Rückgabewert des Intents |
| `ModelContainerFactory.make()` | module | Container im `perform`, wie `CaptureTextIntent` |
| `AppIntents` (`@AppIntent(schema: .reminders.createReminder)`) | SDK | ab iOS/macOS 27, nicht watchOS; das Makro verlangt alle Schema-Parameter |
| `MapKit` (`MKGeocodingRequest(addressString:)`) | SDK | Adresse zu Koordinate, ohne Standortrecht; `CLGeocoder` ist seit iOS 26 veraltet |
| `TestStore` (`LooseEndsTests/EnrichmentTests.swift`) | test | hält den Container als Feld (sonst Absturz im nächsten Speichern) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Intents/CreateReminderIntent.swift` | CREATE | Schema-Intent mit 11 Parametern, `perform` als Kleber, Kern `create` (ca. 75 LoC) |
| `LooseEnds/Places/Geocoding.swift` | CREATE | `Geocode` über `MKGeocodingRequest`, erster Treffer (ca. 30 LoC) |
| `LooseEndsTests/CreateReminderIntentTests.swift` | CREATE | Kern, Fehlerfälle, Geocoder-Hilfsfunktion (Tests zählen nicht zur Grenze) |
| `CLAUDE.md` | MODIFY | Geräteliste um `LooseEnds/Intents/`; „Where things live“ um den Intent (ca. +6 LoC) |

### Estimated Changes

- Files: 4 (davon 2 Quelldateien, 1 Testdatei, 1 Dokument)
- LoC: ca. +110 Code ohne Tests, innerhalb der Grenzen (4 bis 5 Dateien, 250 LoC); mit Tests ca. +250
- **Nicht geändert:** `CaptureTextIntent`, `LooseEndsShortcuts` (`AppShortcutsProvider`), `SiriCapture`, `ReminderSchema`,
  `ReminderTranslation`, `project.yml`, Entitlements, Info.plist. Kein CloudKit-Schema, keine Modelländerung. Dass
  `project.yml` unberührt bleibt, ist per Probebau belegt: voller Bau mit Metadaten-Schritt, Build Succeeded.

### Out of Scope

- **Schnitt 2b-2:** vorgelesene Fehlertexte de/en (`CustomLocalizedStringResourceConvertible`, String Catalog).
- **Schnitt 3:** Ändern, Löschen, Liste oder Abschnitt anlegen als Siri-Handlung (`updateReminder`, `deleteReminders`,
  `createList`, `createSection`); der Probebau meldet sie nicht als Pflicht.
- **Rückfall ohne Apple Intelligence:** `INAddTasksIntent`, Ticket #446.
- Ändern von `CaptureTextIntent` oder `AppShortcutsProvider`.
- Bilder und Abschnitte speichern: Loose Ends hat dafür keinen Platz; `SiriCapture` lehnt sie ab (F5), der Intent ändert das nicht.
- Ausliefern von #25 insgesamt erst nach #240 (erledigt) und der Schnitte 2b-2/3.

## Implementation Details

**Intent.** `@AppIntent(schema: .reminders.createReminder)` mit genau den elf Parametern, die der Probebau im
Metadaten-Schritt bestätigt hat:

| Parameter | Typ |
|---|---|
| `title` | `String` |
| `list` | `ListEntity?` |
| `note` | `AttributedString?` |
| `dueDate` | `DateComponents?` |
| `isFlagged` | `Bool?` |
| `images` | `[IntentFile]` |
| `tags` | `Set<String>` |
| `urls` | `[URL]` |
| `recurrence` | `Calendar.RecurrenceRule?` |
| `locationTrigger` | `LocationTriggerEntity?` |
| `section` | `SectionEntity?` |

Rückgabe: `some IntentResult & ReturnsValue<ReminderEntity>`. Es gibt keinen eigenen Dialog und keine
`openAppWhenRun`-Vorgabe (Siri spricht selbst; Ausführung im App-Prozess, Entscheidung 3 aus Schnitt 1).

**`perform` ist nur Kleber** (`@MainActor`, wie `CaptureTextIntent`): `ModelContainerFactory.make()`, `ModelContext`,
Aufruf von `create` mit `Geocoding.live`, Rückgabe `.result(value: ReminderEntity(task:))`. Der Container bleibt für
die Dauer von `perform` in einer lokalen Konstante gehalten (ein `ModelContext` hält ihn nicht am Leben).

**Kern `create(_:in:geocode:)`** (`@MainActor`, `async throws -> TaskItem`): nimmt die elf Werte als
`SiriCapture.Input` (aus `ReminderTranslation.input`, `images.count` wird zu `imageCount`), ruft
`SiriCapture.prepare`, dann `SiriCapture.commit`, gibt die Aufgabe zurück. Kein eigenes Fangen oder Umdeuten von
Fehlern: jeder `SiriCaptureError` und jeder Fehler aus `CaptureService.save` geht unverändert nach oben. Das
Aufräumen bei einem Fehler in `commit` leistet Schnitt 1; der Kern-Test belegt es am Ende der Kette. Bilder werden
abgelehnt (`unsupported(.images)`), wie in Schnitt 1 vorgesehen: `prepare` prüft `imageCount` vor allem anderen.

**Fehlerverhalten ohne eigene Texte.** `SiriCaptureError` bleibt ein einfacher `Error`; Siri liest den allgemeinen
Fehlersatz des Systems. Wichtig ist nur: Bei jedem Fehler bleibt keine Aufgabe zurück (S1-Garantie, hier belegt).

**Geocoder `Geocoding.live`.** `MKGeocodingRequest(addressString:)` (liefert `nil` bei unbrauchbarer Adresse →
Rückgabe `nil`), `try await request.mapItems`, erster Treffer (MapKit sortiert nach Relevanz), Koordinate aus
`item.location.coordinate`; ungültige Koordinate oder kein Treffer → `nil`, was `SiriCapture` zu `placeNotFound` macht.
Ein Netzfehler wird nicht gefangen: `SiriCapture.resolvePlace` macht daraus ebenfalls `placeNotFound`. Keine
Standortberechtigung. Die Auswahl des ersten Treffers steckt in der reinen Funktion `coordinate(in: [MKMapItem])`,
damit sie ohne Netz prüfbar ist.

**Festlegung mehrdeutiger Treffer.** Erster Treffer, keine Ablehnung. Siri liefert meist selbst eine Koordinate mit;
der Geocoder greift nur bei reiner Adresse. Ablehnen hieße Scheitern bei jeder unscharfen Adresse.

**Geräteliste.** `LooseEnds/Intents/` kommt als neue Zeile in die Geräteliste von `CLAUDE.md`
(„Siri: Erfassung von außerhalb der App, nur das Gerät zeigt, ob Siri den Weg nimmt“). Das macht Stufe 3 für diesen
und die folgenden Schnitte zur Pflicht.

**Alternativen.**

- **Fehlertexte zuerst, Intent zuletzt:** Siri sähe erst Fertiges. Verworfen (Henning, 2026-10-16: „Siri zuerst“):
  Der Gerätebefund käme einen Schnitt später, und Arbeit an Texten wäre womöglich umsonst, wenn Siri den Weg nie nimmt.
- **`MapKitPlaceSearch` statt `MKGeocodingRequest`:** vorhanden, aber eine Geschäftssuche, die Treffer ohne Namen
  verwirft; für eine reine Adresse falsch. Verworfen.
- **Ablehnung bei mehrdeutigem Treffer:** siehe Festlegung; verworfen.
- **Fehler mit `CustomAppIntentErrorConvertible` (neu in 27) für Rückfragen von Siri:** gehört zu 2b-2, kippt hier nichts.
- **SiriKit `INAddTasksIntent` statt Schema:** greift auch ohne Apple Intelligence, hat aber schmalere Felder und ein
  zweites Ziel mit Signierung; kippte ADR-9 („Siri über Schema“). Bleibt der **Rückfall** (#446), nicht der Ersatz;
  wird zur Hauptlinie, falls das Gerät zeigt, dass Siri den Schema-Weg auf Deutsch nicht nimmt.
- **Eigenes Test-Werkzeug des Systems (`AppIntentsTesting`):** unbrauchbar (siehe Test Plan).

## Test Plan

### Automated Tests (TDD RED)

Swift Testing, Container jeweils lokal über `TestStore` gehalten, Fake-`Geocode` als Closure. Ausführung nur über
`./scripts/sim.sh sim-unit`, nie über den Mac-Host.

`LooseEndsTests/CreateReminderIntentTests.swift` (Kern `CreateReminderIntent.create`):

- [ ] `titleAndNoteLandInOneTask`: GIVEN Titel „Steuer“ und Notiz „Belege holen“ WHEN `create` THEN genau eine Aufgabe, Rohtext enthält beide, Titel „Steuer“.
- [ ] `dueDateLands`: GIVEN 2026-10-20 9 Uhr WHEN `create` THEN `dueDate` gesetzt, `dueHasTime == true`.
- [ ] `listLandsAsProject`: GIVEN Liste „Büro“ WHEN `create` THEN Aufgabe hat ein Projekt „Büro“.
- [ ] `flagTagsAndUrlLand`: GIVEN Markierung, vorhandene Tags, ein Link WHEN `create` THEN markiert, Kontexte gesetzt, Link gesetzt.
- [ ] `recurrenceLands`: GIVEN wöchentliche Wiederholung WHEN `create` THEN `RepeatRule` gesetzt.
- [ ] `coordinateBeatsAddress`: GIVEN Ort mit Koordinate und Adresse WHEN `create` THEN Ort trägt die Koordinate, der Fake-Geocode wurde nicht gerufen.
- [ ] `addressOnlyUsesGeocode`: GIVEN Ort nur mit Adresse, Fake liefert Koordinate WHEN `create` THEN Ort mit dieser Koordinate, Fake einmal gerufen.
- [ ] `returnedEntityMatchesTask`: GIVEN eine angelegte Aufgabe WHEN `ReminderEntity(task:)` aus dem Rückgabewert THEN Kennung, Titel, Liste, Fälligkeit stimmen.
- [ ] `rejectedFieldsLeaveNoTask` (parametrisiert: Bilder, Abschnitt mit Inhalt, leerer Titel, zwei Links, unbekanntes Tag, nicht abbildbare Wiederholung, Adresse ohne Treffer, Geocode wirft): GIVEN der Fall WHEN `create` THEN wirft den erwarteten `SiriCaptureError`, und `TaskItem` zählt 0 (und kein neues Projekt bei Fehler nach Listenangabe).
- [ ] `allElevenFieldsInOneCall`: GIVEN alle Felder außer Bildern und Abschnitt gesetzt WHEN `create` THEN eine Aufgabe trägt alle Werte (die Kette schließt, nicht nur der halbe Weg, #136).
- [ ] `performRunsEndToEnd`: GIVEN `CreateReminderIntent` mit Titel WHEN `perform` THEN wirft nicht und liefert eine Entität mit diesem Titel (der Speicher ist unter Tests frisch, die Aufgabe selbst ist nur über den Kern prüfbar; vgl. `IntentExecutionTests`).
- [ ] `geocodingPicksFirstValidHit`: GIVEN `[MKMapItem]` mit gültigen Treffern WHEN `Geocoding.coordinate(in:)` THEN Koordinate des ersten; leere Liste ergibt `nil`; ungültige Koordinate ergibt `nil`.

**Kein `AppIntentsTesting`:** `IntentDefinitions(...).makeIntent(...).run()` scheitert im iOS-27-Simulator mit
`AppIntentsServicesSecurityErrorDomain 803` („Unable to run internal tests on a Customer build“); Apple sperrt es
auf Nicht-Apple-internen Systemen, es gibt keinen Schalter. **Kein automatisierter UI-Test der Kurzbefehle-App:** Das
ist Apples UI, ändert sich je Beta und belegt nur, dass ein Fremdprogramm sich bedienen lässt. Siri-Sprache lässt
sich weder im Simulator noch per Test auslösen. Der Nachweis besteht aus Kern-Tests, dem Metadaten-Schritt des Baus,
einem von mir bedienten Durchlauf über die Kurzbefehle-App und dem Gerät.

## Acceptance Criteria

- **AC-1:** Given Siris Angaben Titel, Notiz, Fälligkeit, Liste, Markierung, Tags, Link und Wiederholung / When der Kern `create` läuft / Then entsteht genau eine Aufgabe, die jede dieser Angaben trägt (Fälligkeit mit Uhrzeit nur, wenn eine Stunde geliefert wurde).
- **AC-2:** Given ein Ort mit Koordinate, mit Adresse oder mit beidem / When `create` läuft / Then wird die Koordinate ohne Geocoder-Aufruf übernommen, bei reiner Adresse genau einmal der Geocoder gerufen, und der Ort liegt mit dem Ereignis `arrive` oder `depart` an der Aufgabe.
- **AC-3:** Given eine Eingabe mit Bildern, einem Abschnitt mit Inhalt, leerem Titel, zwei Links, unbekanntem Tag, nicht abbildbarer Wiederholung, nicht auffindbarer Adresse oder einem werfenden Geocoder / When `create` läuft / Then wirft es den passenden `SiriCaptureError` ohne eigenen Text, und danach steht keine Aufgabe (und kein neues Projekt) im Speicher.
- **AC-4:** Given eine angelegte Aufgabe / When die Rückgabe-Entität gebaut wird / Then entsprechen Kennung, Titel, Liste und Fälligkeit dieser Aufgabe.
- **AC-5:** Given `Geocoding.live` / When eine Adresse aufgelöst wird / Then gilt der erste Treffer, kein Treffer oder eine ungültige Koordinate ergibt `nil` (führt zu `placeNotFound`), und es wird keine Standortberechtigung angefragt; `CLGeocoder` kommt nicht vor.
- **AC-6:** Given der Stand nach diesem Schnitt / When `./scripts/sim.sh generate` und `build` laufen (voller Bau mit Metadaten-Schritt) / Then baut die iOS-App im Simulator ohne Änderung an `project.yml`, und `extract.actionsdata` enthält unter `assistantDefinedSchemas` den Eintrag `reminders` / `CreateReminderIntent` mit den elf Parametern aus der Tabelle.
- **AC-7:** Given der Diff / When er geprüft wird / Then sind `CaptureTextIntent.swift`, `LooseEndsShortcuts`, `SiriCapture.swift`, `ReminderSchema.swift` und `ReminderTranslation.swift` unverändert, es gibt keine Modelländerung und keine Änderung an `cloudkit/schema.ckdb`.
- **AC-8:** Given alle Unit-Tests / When `./scripts/sim.sh sim-unit` läuft / Then sind alle grün, einschließlich der neuen Tests (nie auf dem Mac-Host).
- **AC-9:** Given der Simulator mit iOS 27 und die gebaute App / When in der Kurzbefehle-App die Aktion „Erinnerung erstellen“ von Loose Ends mit einem Titel und einem Datum ausgeführt wird / Then steht danach genau eine Aufgabe mit diesem Titel und Datum in der Liste der App; Screenshots von Aktion, Ergebnis und App-Liste sind als Beleg geöffnet und beschrieben (Stufe 2, von mir bedient).
- **AC-10:** Given `CLAUDE.md` / When der Diff geprüft wird / Then steht `LooseEnds/Intents/` in der Geräteliste (Siri = Erfassung von außerhalb der App), und der Eintrag zu `LooseEnds/Intents` unter „Where things live“ nennt den Intent.
- **AC-11:** Given ein TestFlight-Bau nach dem Merge und Hennings ausdrückliches „jetzt ist ein Test möglich“ (nachgelagert, Gerät) / When Henning am iPhone 16 Pro mit Apple Intelligence einen deutschen Siri-Satz sagt, der eine Erinnerung in Loose Ends anlegt / Then steht entweder die Aufgabe in Loose Ends, oder der Befund „Siri nimmt den Weg nicht“ ist dokumentiert; beides entscheidet über 2b-2 und #446. Vorher nichts auf seinen Geräten.

## Abnahme

Stufe 1 (Tests: AC-1 bis AC-5, AC-8) und Stufe 2 (voller Bau AC-6, Durchlauf über Kurzbefehle im Simulator AC-9) laufen
vor dem Merge. **Stufe 3 greift:** `LooseEnds/Intents/` wird mit diesem Schnitt in die Geräteliste aufgenommen, und
Siri lässt sich nur am Gerät belegen. AC-11 läuft nach dem Merge über TestFlight (Henning, 2026-10-10, #279), mit
Buildnummer und einem Prüfsatz, nicht als Befehlszeile. Weil das Gerät erst nach dem Merge verfügbar ist, ist AC-11
ein nachgelagertes Geräte-AC: Das Ticket #25 bleibt offen, bis Hennings Rückmeldung vorliegt. Nichts läuft auf Hennings
Geräten, bevor er wörtlich „jetzt ist ein Test möglich“ schreibt.

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt, belegt durch Tests, Bau und Simulator-Screenshots; AC-11 nachgelagert und im Ticket vermerkt
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh sim-unit`, nie `unit`)
- [ ] Build erfolgreich (`generate`, dann `build`), jeder Commit kompiliert
- [ ] Durchlauf über die Kurzbefehle-App im Simulator als Beleg registriert (`test-proof` bzw. Screenshots, angesehen und beschrieben)
- [ ] CLAUDE.md aktualisiert (Geräteliste, Where things live)
- [ ] Folgearbeit: Schnitt 2b-2 (Fehlertexte) als eigener Workflow im Ticket #25 vermerkt; Gerätebefund entscheidet über 2b-2 und #446
- [ ] CI grün, Ticket-Board aktuell

## Risiken

1. **Siri nimmt das Schema womöglich nie.** Ein Beta-4-Bericht (Apple-Forum) meldet, `CreateReminderIntent` werde nicht
   gerufen; der Fall ist erklärt durch fehlende Apple Intelligence (Forum 838792), ob die deutsche Siri das Schema
   annimmt, ist unbelegt. Gegenmaßnahme: Gerätebefund AC-11 direkt nach diesem Schnitt, vor den Fehlertexten.
2. **Ohne Apple Intelligence greift das Schema nie.** Rückfall `INAddTasksIntent` (#446); nicht Teil dieses Schnitts.
3. **Kurzbefehle zeigt alle elf Felder** der Aktion „Erinnerung erstellen“, verstecken geht nicht (Forum 838658). Dazu
   steht die Aktion neben „Capture a task“. Hingenommen, kein Eingriff.
4. **Der Geocoder braucht Netz.** Ohne Netz oder Treffer: `placeNotFound`, die Aufgabe wird nicht angelegt, Siri sagt den
   allgemeinen Fehlersatz. Der echte Geocoder ist nur am Gerät mit Netz zu belegen; der Simulator-Durchlauf (AC-9) nimmt
   keine Adresse. Die Treffer-Auswahl ist über `coordinate(in:)` ohne Netz getestet.
5. **Container im Intent:** `make()` je Aufruf wie `CaptureTextIntent`; läuft die App, gibt es zwei Container auf
   demselben Speicher (heute schon so, funktioniert).
6. **Mehrere Sitzungen.** Vor dem Merge `origin/main` und offene PRs prüfen (Lehre #368; PR #500 betrifft Views).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — der Schnitt setzt ADR-9 („Siri über Schema“) und ADR-3 (abgeleitete Felder mit Herkunft) um, ohne
  eine neue Entscheidung zu fällen.
- **Rationale:** Die Ausführung im App-Prozess statt in einer App-Intents-Extension (Abweichung von ADR-9, Zeile in
  `docs/project/00-entscheidungen.md`) war Entscheidung 3 in Schnitt 1; der Intent folgt ihr und ändert sie nicht.

## Changelog

- 2026-10-16: Initial spec created (Schnitt 2b-1 von 4 zu #25; die Analyse teilte Schnitt 2b wegen ca. 265 LoC plus Katalog
  in 2b-1 Intent und 2b-2 Fehlertexte, Reihenfolge „Siri zuerst“ nach Hennings Entscheidung).
