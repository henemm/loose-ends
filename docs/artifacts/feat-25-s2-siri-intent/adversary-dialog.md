# Adversary-Protokoll: feat-25-s2-siri-intent (#25 Schnitt 2a), Wiederholung

Spec: docs/specs/intents/feat-25-s2a-schema-entitaeten.md. Keine Testläufe durch den Prüfer; Beleg ist
docs/artifacts/feat-25-s2-siri-intent/test-green-output.txt (Suite "Reminders-Entitäten": 7 Tests grün, Suite
"Reminders-Übersetzung": 12 Tests grün, "Test Succeeded"; übersprungen: nur Messstrecke SelfConsistencyReportTests,
nicht dieser Schnitt). Der Beleg-Lauf ist von 12:43, project.pbxproj und ReminderEntityTests.swift von 12:52 (nur
Dateizeitstempel; der Testname-Satz im Beleg entspricht den Tests im Quelltext).

## Checkliste

- [x] AC-1: Titel und Notiz als einfacher Text, leere Notiz nil
- [x] AC-2: dueHasTime genau bei vorhandener Stunde, fehlende Minute = 0
- [x] AC-3: unvollständiges Datum ergibt kein Datum, keinen Fehler, dueHasTime falsch
- [x] AC-4: Eingangsliste und keine Liste ergeben nil, sonst Name
- [x] AC-5: Koordinate vor Adresse, reine Adresse ohne Koordinate, Ereignis arrive/depart
- [x] AC-6: Werte unverändert bis SiriCapture, Abschnitt und Bilder dort unsupported
- [x] AC-7: Kette prepare/commit ergibt genau eine Aufgabe
- [x] AC-8: Entitäten, Auflösung nach Kennung, Vorschläge, Namenssuche
- [x] AC-9: Intents-Dateien nur im App-Ziel, project.yml unverändert
- [x] AC-10: CaptureService, CaptureTextIntent, SiriCapture unverändert, kein Schema-Intent

### Runde 1

- [x] AC-1: ReminderTranslation.input setzt notes = String(note.characters), leer oder nil wird nil. Test titleAndNoteTranslate prüft Text, leere AttributedString und nil. Rand: reine Leerzeichen-Notiz bleibt " " (Spec verlangt nur "leer"), unkritisch, prepare/commit kürzt später.
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:21
- [x] AC-2: Zeile 25 dueHasTime = dueDate.hour != nil; Zeile 46 Minute 0 bei fehlender Minute, ohne Stunde 00:00. Stunde 0 (Mitternacht): hour == 0 ist nicht nil, also dueHasTime true und 00:00 mit Uhrzeit, korrekt. Tests dateWithoutTimeHasNoTime, dateWithHourHasTime, calendarOfTheComponentsWins (Tokyo, Kalender der Komponenten gewinnt). Ein Test mit Stunde 0 fehlt (siehe F002).
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:40
- [x] AC-3: guard auf year/month/day liefert nil (Zeile 41); in input bleiben due = nil und dueHasTime = false, weil beides nur im if-let gesetzt wird (Zeile 23-26). Kein throws in der Signatur. Test incompleteDateIsDropped mit vier Fällen (ohne Jahr, Monat, Tag, nur Stunde).
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:41
- [x] AC-4: Zeile 27: Eingangskennung "inbox" oder nil ergibt nil, sonst Name. Test listNameFromList. Rand: ein echtes Projekt namens "Loose Ends" hat eine UUID-Kennung und wird korrekt als Projekt behandelt.
  Code reference: LooseEnds/Intents/ReminderSchema.swift:18
- [x] AC-5: place(from:) übernimmt Koordinate, Adresse und commonName getrennt; Ereignis per erschöpfendem switch. Tests coordinateBeatsAddress, addressOnlyKeepsAddress, eventMaps. Rand: PlaceDescriptor ohne Darstellung ergibt Place mit nur Ereignis, SiriCapture.prepare entscheidet (Schnitt 1).
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:51
- [x] AC-6: urls, isFlagged, tags, recurrence, section?.name, imageCount werden durchgereicht (Zeile 28-34). Tests flagTagsUrlsPassThrough, recurrencePassesThrough, sectionAndImagesReachSiriCapture (echter prepare-Aufruf wirft unsupported(.section) bzw. .images, keine Aufgabe angelegt).
  Code reference: LooseEndsTests/ReminderTranslationTests.swift:144
- [x] AC-7: translatedInputRunsThroughSiriCapture läuft prepare und commit und prüft genau eine Aufgabe mit Rohtext, Datum 9 Uhr, Projekt "Büro", Ort. Der Test baut den Ausgang nicht von Hand, sondern über die Übersetzung.
  Code reference: LooseEndsTests/ReminderTranslationTests.swift:163
- [x] AC-8: ListEntity.entities(for:) holt Projekte ohne Archivfilter, Eingang separat, Unbekanntes entfällt via compactMap (Schema:39-44). suggested: Eingang plus archivedAt == nil nach sortOrder (Schema:48-53). matching: nameKey auf beiden Seiten (Schema:57-60), leere Suche liefert alle Vorschläge. ReminderEntity(task:) mit displayTitle, Eingang als Fallback, Komponenten mit oder ohne Stunde je dueHasTime (Schema:108-119); entities(for:) ohne Statusfilter (Schema:123). Query-Typen für Ort und Abschnitt liefern [] (Schema:162-165, 182-185). Sieben Tests in ReminderEntityTests.
  Code reference: LooseEndsTests/ReminderEntityTests.swift:7
- [x] AC-9: Siehe Runde 2 (Projektdatei).
  Code reference: LooseEnds.xcodeproj/project.pbxproj:2236
- [x] AC-10: Siehe Runde 2 (Diff).
  Code reference: LooseEnds/Intents/ReminderSchema.swift:16

### Runde 2

Randfälle, gezielt gegen den Code:

- [x] AC-2/AC-3, unmögliche Daten: DateComponents(2026, Feb, 30) hat Jahr/Monat/Tag, passiert den guard, und Calendar.date(from:) rechnet nachsichtig auf 2. März (Monat 13 auf Januar des Folgejahres, Stunde 25 auf den Folgetag). Weder Spec noch Test decken das ab; Siri liefert das praktisch nicht. Befund F001 (LOW).
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:45
- [x] AC-2, Stunde 0: korrekt (hour != nil), nur ungetestet (F002, LOW).
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:25
- [x] Zeitzone: parts.calendar oder Calendar.current, dazu parts.timeZone (Zeile 42-43); Test mit Asia/Tokyo belegt, dass nicht die Gerätezeit gilt. Rand: nur timeZone ohne calendar ist abgedeckt durch Code, nicht durch Test (kein Befund). Umgekehrt ReminderEntity nutzt Calendar.current, passend zu capturedAt/dueDate in Gerätezeit.
  Code reference: LooseEndsTests/ReminderTranslationTests.swift:60
- [x] AC-8, archiviertes Projekt: erscheint in entities(for:) (kein Filter), nicht in suggested/matching (archivedAt == nil). Gemäß Spec; Konsequenz: Siri kann ein archiviertes Projekt nicht per Namen finden. Das ist Spec-konform.
  Code reference: LooseEnds/Intents/ReminderSchema.swift:50
- [x] AC-8, leere Suche und Reihenfolge: matching("") liefert alle Vorschläge (contains mit leerem Schlüssel), unkritisch. ReminderEntity.entities(for:) liefert in Speicherreihenfolge, nicht in der Reihenfolge der Kennungen (F003, LOW; die Spec verlangt nur Auflösung).
  Code reference: LooseEnds/Intents/ReminderSchema.swift:124
- [x] AC-9: Das Ziel "LooseEnds" (PBXNativeTarget 2771E45C66E4289C14D90FF8, Zeile 1427/1431) hat die Sources-Phase E674D9B06F1AEAC3AFE2738F (Zeile 2163). Nur dort stehen ReminderSchema.swift (2236) und ReminderTranslation.swift (2237). In den Phasen der übrigen Ziele (Zeilen 1770-2052, ohne das Test-Ziel) kommt keine der beiden vor (grep über den Bereich 1769-2285: Treffer nur 2236/2237 für die Quelldateien). Die Tests stehen nur in der Phase des Test-Ziels (2123/2124, ReminderEntityTests.swift ist erstmals zitiert: Zeile 2123). `git diff main -- project.yml` ist leer (0 Zeilen). CaptureTextIntent.swift steht dagegen in zwei Phasen (1829 und 2176), unverändert gegenüber main.
  Code reference: LooseEnds.xcodeproj/project.pbxproj:2237
- [x] AC-9, Testdatei im Projekt: ReminderEntityTests.swift ist in Gruppe (1158), Dateireferenz (639), Build-Datei (265) und Sources-Phase des Test-Ziels (2123) eingetragen; der Beleglauf führt ihre sieben Tests aus (Beleg Zeile 589-597).
  Code reference: LooseEndsTests/ReminderEntityTests.swift:7
- [x] AC-10: `git diff main --stat` listet CLAUDE.md, die vier neuen Swift-Dateien, Doku und Artefakte; `git diff main --name-only` mit Filter auf CaptureService, CaptureTextIntent, SiriCapture, project.yml ist leer. Schema-Deklarationen (`@AppEntity(schema:`, `@AppEnum(schema:`) stehen nur in ReminderSchema.swift; es gibt keine Datei mit `AppIntent` und Schema, das Wort "schema:" taucht sonst nur als SwiftData-Schema in ModelContainerFactory auf. Die vier Typen sind Entitäten/Aufzählungen, keine Intents.
  Code reference: LooseEnds/Intents/ReminderSchema.swift:9
- [x] Übersetzung als Ganzes (AC-1 bis AC-7 gegen die Tests): keine Abweichung zwischen Quelltext und Testnamen im Beleg.
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:19

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Eigene Prüfung der Felder: `dueHasTime` wird in
der Übersetzung nur geschrieben, wenn ein vollständiges Datum entsteht (Bedingung davor: Jahr, Monat, Tag vorhanden;
Test für diesen Weg: incompleteDateIsDropped und dateWithHourHasTime).

## Befunde

- F001 LOW (edge_case): Unmögliche, aber vollständige Daten (30. Februar, Monat 13) werden von Calendar.date(from:) still verschoben statt verworfen. Code reference: LooseEnds/Intents/ReminderTranslation.swift:45. Abhilfe: Ergebnis mit dateComponents zurückprüfen. Kein AC verletzt.
- F002 LOW (edge_case): Stunde 0 hat keinen eigenen Test (Code korrekt). Code reference: LooseEndsTests/ReminderTranslationTests.swift:53.
- F003 LOW (anti_pattern): ReminderEntity.entities(for:) behält die Reihenfolge der Kennungen nicht. Code reference: LooseEnds/Intents/ReminderSchema.swift:124.

Kein CRITICAL, HIGH oder MEDIUM. Alle 10 ACs belegt.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:d3b956e434c98a1634e6dc1f4e6afd2a677ecd047df996f9e2d4c72934deaf8c  LooseEnds.xcodeproj/project.pbxproj
- sha256:eb026f457d0e3157ff192b01da4c4af8abdc3bac11560ef88b80bc3720d92131  LooseEnds/Intents/ReminderSchema.swift
- sha256:ba0cd4379675d51fa2bcf45bf4f2f8d1399e2f40b658886156c335bdc66c9b91  LooseEnds/Intents/ReminderTranslation.swift
- sha256:dbb8a7309222ba37103bdb3d54d95beb30ac1beb62b2adc97395d53dcc5288bb  LooseEndsTests/ReminderEntityTests.swift
- sha256:3bce27ce54b2f781e9d9a5e8606baaf4850bec36ccf8195f66bd2e8e69e581e0  LooseEndsTests/ReminderTranslationTests.swift

## Prüfbasis

- base: 5f194951f9f738f115ec5a356bf014c6651315db
- blob:199219e1057eb8ef0afbfeba971758f6e8e20ec5  LooseEnds.xcodeproj/project.pbxproj
- blob:c6f89c49781e7414a06d5c190fe8688bf555c2b4  LooseEnds/Intents/ReminderSchema.swift
- blob:90b9ff75cffa1e48aba714e6c9b32f08348839b2  LooseEnds/Intents/ReminderTranslation.swift
- blob:a3740e5211f116d41dd2f5564a2b1904c667623e  LooseEndsTests/ReminderEntityTests.swift
- blob:59efec3b6026b4a5702e4666cff659cab3d3bf51  LooseEndsTests/ReminderTranslationTests.swift
