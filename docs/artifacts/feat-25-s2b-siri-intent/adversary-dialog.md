# Adversary-Dialog: feat-25-s2b-siri-intent (#25 Schnitt 2b-1)

Spec: `docs/specs/intents/feat-25-s2b1-siri-intent.md` · Prüfer: implementation-validator (liest Spec, Tests, Metadaten, Screenshots) · 2026-10-16

### Runde 1

Erste Einschätzung: Tests grün (xcresult 20:56, 789/0/3), Metadaten tragen `reminders`/`CreateReminderIntent` mit 11 Parametern, Quellen schlank, kein `try?`. AC-9 fehlte noch (Kurzbefehle-Beleg lief parallel). Gefunden: F001 (Container-Lebensdauer in `perform` über ein `await`), F002–F004 (LOW). Verdict der Runde: AMBIGUOUS.

### Runde 2

Nachprüfung gegen die #136-Falle: Eingaben entstehen über `ReminderTranslation.input` wie in `perform`; `allElevenFieldsInOneCall` liest aus einem frischen `ModelContext`. Alle 8 Ablehnungsfälle einzeln Passed. `perform` reicht alle 11 Parameter durch.

Parallel ergab der erste Kurzbefehle-Durchlauf: Die Aktion erscheint in Kurzbefehle NICHT (`ac9-blocker-1..3.png`), Metadaten `title = None`. Recherche: Forum 838658 belegt, dass die Schema-Aktion in Kurzbefehle grundsätzlich erscheint. Ursache gefunden: Ohne eigenen Titel listet Kurzbefehle die Aktion nicht. Korrektur: `static let title: LocalizedStringResource = "Create Reminder"` (Standardtitel aus `extension AssistantSchemaIntent` im SDK wird überschrieben); F001 behoben mit `defer { withExtendedLifetime(container) {} }`.

### Runde 3

Selbst geprüft nach beiden Änderungen: F001 behoben (defer hält den Container bis zum Verlassen von `perform`, auch nach dem `await`). Titel kein Spec-Verstoß, nötig für AC-9; Schema unverändert (extract.actionsdata 21:51: title.key „Create Reminder“, `reminders`/`CreateReminderIntent` 1.0.0, 11 Parameter). AC-9-Screenshots geöffnet und beschrieben. Frischer voller Lauf (xcresult 21:50): 792 gesamt, 789 bestanden, 0 fehlgeschlagen, 3 übersprungen (vorbestehend: Selbstkonsistenz-Messstrecke ohne selfconsistency-run.json; zwei Sprach-Latenztests #274/#419 ohne de_DE im Simulator).

## Checkliste

- [x] AC-1: Alle Angaben in genau einer Aufgabe — Beweis: `titleAndNoteLandInOneTask`, `dueDateLands`, `listLandsAsProject`, `flagTagsAndUrlLand`, `recurrenceLands`, `allElevenFieldsInOneCall` Passed; Gesamttest liest über frischen Context; Uhrzeit nur mit Stunde (ReminderTranslation.swift:25).
- [x] AC-2: Koordinate ohne Geocoder, reine Adresse genau einmal — Beweis: `coordinateBeatsAddress` (Log leer), `addressOnlyUsesGeocode` (ein Aufruf, Ereignis `.depart`) Passed.
- [x] AC-3: Ablehnungen ohne Rest — Beweis: `rejectedFieldsLeaveNoTask`, 8 Argumente Passed, 0 `TaskItem` und 0 `Project` im frischen Context; `create` fängt nichts.
- [x] AC-4: Rückgabe-Entität — Beweis: `returnedEntityMatchesTask`, `performRunsEndToEnd` Passed; `ac9-2-ergebnis.png` zeigt die Entität als Ergebnis-Karte.
- [x] AC-5: Geocoding — Beweis: `geocodingPicksFirstValidHit` Passed; `MKGeocodingRequest`, kein `CLGeocoder`, keine Standortabfrage (F002 LOW).
- [x] AC-6: Metadaten — Beweis: extract.actionsdata 21:51, `reminders`/`CreateReminderIntent` mit title, list, note, dueDate, isFlagged, images, tags, urls, recurrence, locationTrigger, section; `project.yml` unverändert.
- [x] AC-7: Unverändert — Beweis: kein Diff in Shared, cloudkit, project.yml, ReminderSchema, ReminderTranslation, CaptureTextIntent, SiriCapture; Info.plist-Drift aus project.yml:90 wird nicht committet (F003).
- [x] AC-8: Alle Unit-Tests grün — Beweis: xcresult 21:50, 789 bestanden, 0 fehlgeschlagen, 3 vorbestehende Skips; `docs/artifacts/feat-25-s2b-siri-intent/test-green-output.txt`.
- [x] AC-9: Kurzbefehle-Durchlauf im Simulator — Beweis: `ac9-1-aktion.png` (Editor „Add Siri Probe 2b1 to List“, Due Date tomorrow at 9:00 AM, alle 11 Felder), `ac9-2-ergebnis.png` (Ergebnis-Karte), `ac9-3-liste.png` (genau eine Zeile „Morgen · Siri Probe 2b1“), `ac9-4-detail.png` (Fällig „Morgen, 9:00“).
- [x] AC-10: CLAUDE.md — Beweis: Geräteliste mit `LooseEnds/Intents/`, „Where things live“ nennt `CreateReminderIntent`.
- [ ] AC-11: Gerät über TestFlight nach Merge — nachgelagert (Henning, 2026-10-10, #279); in dieser Phase nicht belegbar, kein Defekt. Nichts auf Hennings Geräten gestartet.

## Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEnds/Intents/CreateReminderIntent.swift:27
  Description: Container nur in ungenutzter lokaler Konstante über ein `await` gehalten.
  Status: BEHOBEN mit `defer { withExtendedLifetime(container) {} }`; nicht blockierend.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEnds/Places/Geocoding.swift:15
  Description: `coordinate(in:)` nimmt den ersten Treffer mit gültiger Koordinate; AC-5 sagt wörtlich „erster Treffer“, der Testplan „first valid hit“. Fall „erster ungültig, zweiter gültig“ ungetestet, praktisch selten.
  Status: nicht blockierend.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEnds/Info.plist:56
  Description: `NSCameraUsageDescription` kommt per `generate` aus project.yml:90 (schon auf main); nicht Teil des Schnitts.
  Status: wird nicht mitcommittet; nicht blockierend.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Intents/CreateReminderIntent.swift:43
  Description: Alle Ablehnungsfälle scheitern in `prepare`; ein Fehler in `commit` wird auf Kernebene nicht ausgelöst (Aufräumen durch Schnitt-1-Tests belegt).
  Status: nicht blockierend.

## Confirmations

Confirmation:
  AC: AC-1, AC-2, AC-3, AC-4
  Code reference: LooseEnds/Intents/CreateReminderIntent.swift:43
  Evidence: `create` ruft `prepare`, dann `commit`, ohne Fangen; alle Fälle Passed.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Places/Geocoding.swift:9
  Evidence: `MKGeocodingRequest`, kein `CLGeocoder`; `coordinate(in:)` getestet.
  Status: CONFIRMED

Confirmation:
  AC: AC-6, AC-9
  Code reference: LooseEnds/Intents/CreateReminderIntent.swift:11
  Evidence: Eigener Titel; Metadaten mit Schema und 11 Parametern; Kurzbefehle-Durchlauf ac9-1..4.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEndsTests/CreateReminderIntentTests.swift:237
  Evidence: xcresult 21:50: 789/0/3.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: CLAUDE.md:98
  Evidence: Geräteliste und „Where things live“ ergänzt.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert; die neuen Dateien schreiben keine Modellfelder selbst, alle Schreibzugriffe laufen über `SiriCapture.commit` (Schnitt 1).

## Verdict

AC-1 bis AC-10 belegt, F001 behoben, F002–F004 nicht blockierend; AC-11 nachgelagert (Gerät).

### Verdict: VERIFIED

## Geprüfte Dateien

- sha256:e4e478559dbcb2a810d9529a4b07f7f78d1f9d487c5036b1a4ae8bd1d22e463f  CLAUDE.md
- sha256:8cdb7b8db553276713f86670a8e5d4dcd2e83e479774f45052b98a7c09fea400  LooseEnds/Info.plist
- sha256:81b6ccfe59b7f9c53d8c854997ee4d82cc8b1433fe69807925c1a990f4c53246  LooseEnds/Intents/CreateReminderIntent.swift
- sha256:68ea6e542512e3e5edce5880b52e3349e21e2e5ee035ea1869160d27e526a82b  LooseEnds/Places/Geocoding.swift
- sha256:2c7669c651000b81764f49404e69e5ca254eab54186c095be8de0af1d6000754  LooseEndsTests/CreateReminderIntentTests.swift

## Prüfbasis

- base: 246fe4cbcfb971009ac8597d8f8bdcc545b25cf9
- blob:40652d396eec38d38579cb9fe1f0e0dd2544e067  CLAUDE.md
- blob:c96e94c679e1947414d92d9027eaadda2d290d46  LooseEnds/Info.plist
- blob:b1697520708ef0d4ff1514b659b73885aadd5156  LooseEnds/Intents/CreateReminderIntent.swift
- blob:74fbfd14dcbffd6b6cf9f6f896b657ed1ad050d2  LooseEnds/Places/Geocoding.swift
- blob:2c85fc37bf625d35096350ec331f566c55e81580  LooseEndsTests/CreateReminderIntentTests.swift
