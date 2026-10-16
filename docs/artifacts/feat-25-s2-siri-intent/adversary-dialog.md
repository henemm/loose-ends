# Adversary-Dialog: feat-25-s2-siri-intent (#25 Schnitt 2a)

Prüfer: implementation-validator (liest Spec, Tests, Quellen, Testausgabe; startet keine Testläufe).
Beleg zu den Tests: `docs/artifacts/feat-25-s2-siri-intent/test-green-output.txt` (731 von 734 bestanden, 0 fehlgeschlagen, 3 übersprungen: SelfConsistencyReportTests und zwei Sprach-Latenztests #274, alle ohne Bezug zu diesem Schnitt).

### Runde 1

- [x] AC-1: Die Notiz wird über `String($0.characters)` zu einfachem Text, ein leerer String wird zu nil. Der Test deckt Text, leeren AttributedString und nil ab.
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:21
- [x] AC-2: `dueHasTime = dueDate.hour != nil`, die fehlende Minute wird 0. Die Tests prüfen `due` gegen konkrete Datumswerte (Tag um 00:00, 09:00).
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:25
- [x] AC-3: Das `guard` auf Jahr, Monat und Tag gibt nil zurück, `due` und `dueHasTime` bleiben auf dem Vorgabewert, nichts wird geworfen. Vier parametrisierte Fälle prüfen `due == nil` und `dueHasTime == false`.
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:23
- [x] AC-4: Nur die Kennung `ListEntity.inboxID` ergibt nil, sonst der Name. Die Entscheidung hängt an der Kennung, nicht am Namen.
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:27
- [x] AC-5: Koordinate nur aus `place.coordinate`, die Adresse bleibt getrennt, das Ereignis wird per `switch` gemappt. Tests: Koordinate mit Adresse, reine Adresse (`coordinate == nil`), beide Ereignisse.
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:51
- [x] AC-6: Link, Markierung, Tags, Wiederholung, Abschnitt und Bilder werden unverändert durchgereicht. Der Test ruft das echte `SiriCapture.prepare` und erwartet `unsupported(.section)` und `unsupported(.images)`, danach ist keine Aufgabe angelegt.
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:28
- [x] AC-7: Der Test läuft die Kette Übersetzung, `prepare`, `commit` und prüft genau eine Aufgabe mit `rawText`, Datum samt `dueHasTime`, Projekt und `TaskPlace`.
  Code reference: LooseEndsTests/ReminderTranslationTests.swift:163
- [x] AC-8: Auflösen nach Kennung nimmt archivierte Projekte mit und lässt unbekannte aus; Vorschläge: Eingang zuerst, dann aktive Projekte nach `sortOrder` (Test mit vertauschter Einfügereihenfolge); Namenssuche über `nameKey` ("buro" findet "Büro"); Erinnerung trägt Titel, Liste, Fälligkeit mit und ohne Uhrzeit.
  Code reference: LooseEnds/Intents/ReminderSchema.swift:39
- [x] AC-9: `project.yml` unverändert. `ReminderSchema.swift` und `ReminderTranslation.swift` stehen in der erzeugten Projektdatei nur in der Sources-Phase des App-Ziels, nicht in Watch, Widgets oder Share. Der Bau lief grün (Entwickler-Lauf mit `generate` und `build`, danach voller Unit-Lauf).
  Code reference: LooseEnds.xcodeproj/project.pbxproj:2028
- [x] AC-10: `git diff HEAD --name-only` nennt nur `CLAUDE.md` und `docs/project/02-datenmodell-und-ansichten.md` (laut Spec erlaubt); `CaptureService.swift`, `CaptureTextIntent.swift`, `SiriCapture.swift` unverändert; in `LooseEnds/Intents` nur `import AppIntents`, kein Intent.
  Code reference: LooseEnds/Intents/ReminderSchema.swift:4

### Runde 2

Nachprüfung der Rückfragen aus Runde 1.

- [x] AC-1: Kein Pfad nimmt einen Nicht-Text-Anteil mit, Attribute fallen weg.
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:21
- [x] AC-2: Nur Minute ohne Stunde ergibt Mitternacht und `dueHasTime == false` (spec-konform); Stunde 0 ergibt `dueHasTime == true` (richtig, ohne Test, Befund F-A).
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:44
- [x] AC-3: Unmögliche Werte (Tag 31 im Februar) ergeben nil ohne Fehler, spec-konform, ungetestet.
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:41
- [x] AC-4: Name des Eingangs fest "Loose Ends", Prüfung über `inboxID`.
  Code reference: LooseEnds/Intents/ReminderSchema.swift:18
- [x] AC-5: Koordinate ohne Namen wird mit `commonName == nil` durchgereicht.
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:59
- [x] AC-6: Leere oder doppelte Tags filtert die Übersetzung nicht ("unverändert", Prüfung gehört zu `SiriCapture`).
  Code reference: LooseEnds/Intents/ReminderTranslation.swift:32
- [x] AC-7: Der Ausgangszustand der Kette entsteht aus `ReminderTranslation.input`, nicht aus von Hand gesetzten Vermerken.
  Code reference: LooseEndsTests/ReminderTranslationTests.swift:166
- [x] AC-8: Archiviertes Projekt fehlt in `suggested` und `matching`, ist aber über `entities(for:)` auflösbar (entspricht der Spec).
  Code reference: LooseEnds/Intents/ReminderSchema.swift:39
- [x] AC-9: Volle Unit-Läufe setzen den Bau voraus (Test Succeeded); Zuordnung zum App-Ziel in der Projektdatei.
  Code reference: LooseEnds.xcodeproj/project.pbxproj:2028
- [x] AC-10: Bestätigt durch Diff-Liste und grep.
  Code reference: LooseEnds/Intents/ReminderSchema.swift:4

Befunde niedriger Schwere, kein Blocker (je ein Wunsch für Schnitt 2b oder Ticket, nicht Teil der ACs):

- F-A (LOW): kein Test für Stunde 0 ("00:00 mit Uhrzeit").
- F-B (LOW): Der Zeitzonentest ist nicht trennscharf, wenn das Gerät in Asia/Tokyo steht; der Fall "Kalender nil, Rückfall auf aktuellen Kalender" ist ungetestet.
- F-C (LOW): `ReminderEntity.dueDate` entsteht mit `Calendar.current` ohne `calendar`/`timeZone`-Vermerk; nur lesend, für 2a unkritisch.
- F-D (LOW): `matching("")` liefert alle vorgeschlagenen Listen, nicht getestet.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:48665bcf24ce74ff6d0f300f4b78390d4d621abb9b380cfb1a6a48d4a13df43b  LooseEnds.xcodeproj/project.pbxproj
- sha256:eb026f457d0e3157ff192b01da4c4af8abdc3bac11560ef88b80bc3720d92131  LooseEnds/Intents/ReminderSchema.swift
- sha256:ba0cd4379675d51fa2bcf45bf4f2f8d1399e2f40b658886156c335bdc66c9b91  LooseEnds/Intents/ReminderTranslation.swift
- sha256:3bce27ce54b2f781e9d9a5e8606baaf4850bec36ccf8195f66bd2e8e69e581e0  LooseEndsTests/ReminderTranslationTests.swift

## Prüfbasis

- base: e6d078d2135e47a5cbd0a16f09c494a4acb6d0e5
- blob:904cc1ec4dc31ce695d1ca79c0a4970962f38759  LooseEnds.xcodeproj/project.pbxproj
- blob:c6f89c49781e7414a06d5c190fe8688bf555c2b4  LooseEnds/Intents/ReminderSchema.swift
- blob:90b9ff75cffa1e48aba714e6c9b32f08348839b2  LooseEnds/Intents/ReminderTranslation.swift
- blob:59efec3b6026b4a5702e4666cff659cab3d3bf51  LooseEndsTests/ReminderTranslationTests.swift
