# Adversary Dialog — feat-25-s1-siri-capture
Spec: docs/specs/intents/feat-25-s1-siri-capture.md
Datum: 2026-10-15 07:38

## Checkliste
- [x] **AC-1:** Given nur ein Titel / When `prepare` und `commit` laufen / Then entsteht genau eine Aufgabe mit Kanal `.siri`, Rohtext gleich Titel, ohne Revision und ohne Projekt.
- [x] **AC-2:** Given alle Felder (Titel, Notiz, Datum mit Uhrzeit, Liste, Wiederholung, Ort, Link, Markierung, Tag) / When `commit` läuft und die Aufgabe neu geladen wird / Then trägt sie jeden Wert, der Pfad ist persistiert.
- [x] **AC-3:** Given eine Eingabe mit leerem Titel, zwei verschiedenen Links, unbekanntem Tag, nicht abbildbarer Wiederholung, nicht gefundenem Ort, ungültiger Koordinate, Abschnitt mit Inhalt oder Bildern mit Inhalt / When `prepare` läuft / Then wirft es den passenden Fehler, es entsteht keine Aufgabe und kein Projekt, und der `ModelContext` hat `hasChanges == false`.
- [x] **AC-4:** Given ein Ort mit Koordinate / When `prepare` läuft / Then wird die Geocoding-Funktion nicht aufgerufen; Given ein Ort nur mit Adresse / Then genau einmal, und ohne Treffer wirft `prepare` `placeNotFound`.
- [x] **AC-5:** Given Datum, Wiederholung, Ort und Liste / When `commit` läuft / Then hat jedes dieser Felder genau eine Revision mit Autor `.user` und Grund „Siri“, und die Herkunft des Orts ist `user`.
- [x] **AC-6:** Given eine Wiederholung ohne Datum / When `commit` läuft / Then trägt die Aufgabe die Regel, aber keine Fälligkeit.
- [x] **AC-7:** Given Siri-Werte in allen Feldern / When der erste Veredelungsdurchlauf des `EnrichmentCoordinator` mit einem Test-Enricher läuft, der andere Werte liefert / Then bleiben alle Siri-Werte erhalten.
- [x] **AC-8:** Given der Stand nach diesem Schnitt / When der Diff geprüft wird / Then sind Signatur und Rumpf von `CaptureService.save` unverändert.
- [x] **AC-9:** Given eine Liste, die als Projekt schon existiert (gleicher `nameKey`) / When `commit` läuft / Then bleibt die Zahl der Projekte gleich und die Aufgabe liegt im vorhandenen; Given mehrere gleichnamige Projekte / Then gilt das mit der kleinsten `sortOrder`; Given eine unbekannte Liste / Then entsteht genau ein Projekt.
- [x] **AC-10:** Given Titel „Steuer“ und Notiz „Belege holen“ / When `commit` läuft / Then ist der Rohtext „Steuer“, Zeilenumbruch, „Belege holen“, und der Titel lautet „Steuer“.
- [x] **AC-11:** Given die Links `https://a.de` und `https://a.de/` / When `prepare` läuft / Then zählen sie als ein Link und es gibt keinen Fehler; Given leere Tags / Then gibt es keinen Fehler, keine Kontexte und keine Revision.
- [x] **AC-12:** Given `prepare` mit beliebiger Eingabe, auch mit Fehler / When es läuft / Then schreibt es nichts in den `ModelContext`.

## Dialog

### Runde 1
**Adversary:** Urteil BROKEN (leicht). Befunde: Fehlerpfad von `commit` räumte nicht vollständig auf (Aufgabe, neues Projekt, Revisionen blieben nach einem Fehler nach dem ersten Speichern zurück); `rollback()` ist keine Lösung; Link-Vergleich `https://a.de` gegen `https://a.de/` und leere Tags wurden nicht gleich behandelt (AC-11); gelöschter Tag zwischen `prepare` und `commit` stürzte ab (`model(for:)` auf gelöschtes Objekt); Geocoding-Fehler (Netz) war nicht auf `placeNotFound` abgebildet; Titel aus Siris Titel allein fehlte als Test.
**Implementierer:** Alle Befunde behoben und mit Tests belegt: `commit` löscht im Fehlerfall die eingefügten Modelle und die gespeicherte Aufgabe (kein `rollback()`); `SiriFields` ignoriert den leeren Pfad `/` und leere Tags; gelöschte Tags werden über `persistentModelID` per Fetch aufgelöst und liefern `tagRemoved`; Geocoding-Fehler werden zu `placeNotFound`. Neue Tests: `errorInCommitLeavesNothingBehind`, `geocodingFailureIsPlaceNotFound`, `tagDeletedBeforeCommitThrows`, `siriTitleMayBeRefinedLikeAnyTitle`. Code reference: Shared/Services/SiriCapture.swift:143

### Runde 2
**Adversary:** Urteil AMBIGUOUS, kein CRITICAL/HIGH. N1 (MEDIUM): Der Fehlerpfad von `commit` löschte pauschal `insertedModelsArray`, also auch fremde, ungespeicherte Inserts des Aufrufers, wenn `CaptureService.save` selbst wirft. N2 (LOW): `try context.save()` im Aufräumen konnte den Originalfehler überdecken. N3 (Hinweis): Umfang über der Schätzung der Analyse (≈+13 Zeilen Code gegenüber ~160 geschätzt, Tests zählen nicht).
**Implementierer:** N1 behoben: `commit` merkt sich vor `CaptureService.save` die `persistentModelID` aller schon eingefügten Objekte, `discard` löscht nur die Differenz; nur wenn eine Aufgabe schon gespeichert war, wird nach dem Aufräumen gespeichert. N1 vorher nachgestellt: der neue Test `failedCommitKeepsCallersUnsavedInsert` war rot (Zeilen 343/344), mit dem Fix grün. Zweiter Test `failedCommitAfterSaveKeepsCallersObject` belegt das Verhalten nach dem ersten Speichern. N2 behoben: Fehler des Aufräum-Speicherns wird mit `Logger` gemeldet, geworfen wird der Originalfehler. N3: Umfang bleibt innerhalb von Funktionen ≤ 50 Zeilen; die Abweichung ist kleiner als die Grenze von ±250 Zeilen und wird im Abschlussbericht genannt. Code reference: Shared/Services/SiriCapture.swift:164

### Runde 3
**Adversary:** Nur lesend (keine Läufe). Urteil VERIFIED. N1 vollständig behoben (drei Fälle: `save` wirft vor dem Insert, `save` wirft beim eigenen Speichern, Fehler nach dem ersten Speichern); N2 behoben (eigener do/catch, `logger.error`, kein `try?`); Funktionen ≤ 50 Zeilen, `@MainActor` für alles Mutierende; beide neuen Tests sind nicht tautologisch. Befunde nur LOW: F-LOW-1 Pfad „`CaptureService.save` wirft beim eigenen `context.save()`“ ohne eigenen Test; F-LOW-2 scheitert das Aufräum-Speichern, bleibt die Aufgabe im Store, der Aufrufer sieht den Originalfehler (im Doc-Kommentar vermerkt).
**Implementierer:** F-LOW-1 und F-LOW-2 sind Randlagen ohne künstliche Fehlerstelle nicht auslösbar und widersprechen keinem AC; sie bleiben als bekannte Grenze dokumentiert.

### Bestätigungen
- AC-1, AC-2, AC-5, AC-6, AC-10: `commit` setzt Titel (aus Siris Titel, `TitleRule`), Datum, Projekt, Wiederholung und Ort über die vorhandenen Feldwege mit Autor `.user` und Grund „Siri“.
Code reference: Shared/Services/SiriCapture.swift:180
- AC-3, AC-4, AC-11, AC-12: `prepare` löst alles auf und wirft vor dem ersten Schreiben; Geocoding nur bei Adresse ohne Koordinate.
Code reference: Shared/Services/SiriCapture.swift:77
- AC-9: Projektsuche über `nameKey`, kleinste `sortOrder` gewinnt, sonst genau ein neues Projekt.
Code reference: Shared/Services/CatalogService.swift:22
- AC-11: Link-Schlüssel ignoriert den leeren Pfad `/`, leere Tags werden verworfen.
Code reference: Shared/Services/SiriFields.swift:42
- AC-7: Das Veredelungs-Gate für das Projekt zählt einen von Siri gesetzten Wert als Nutzerwert. Diese Datei steht NICHT in der Dateiliste der eingefrorenen Spec (Abweichung F004, +3/−1 Zeilen); sie war für AC-7 nötig, weil sonst `EnrichmentWriter` das Siri-Projekt im ersten Durchlauf überschrieb. Die Änderung gehört nicht zur Geräteliste (die nennt nur `FoundationModelsEnricher` und `EnrichmentCoordinator`).
Code reference: Shared/Enrichment/EnrichmentWriter.swift:91
- AC-8: `git diff` zeigt keine Änderung an `Shared/Services/CaptureService.swift`.

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`).

## Verdict
**VERIFIED**

## Geprüfte Dateien

- sha256:fca0eda441e9f9b40a2c26c5aa1f54cacf0780bee90dc162aba917e5c8cf0c03  Shared/Enrichment/EnrichmentWriter.swift
- sha256:b10ff02e9265510c6014e342c2d0f1489bcc4b4eaf2e2bba77d9f913fda4c06c  Shared/Services/CatalogService.swift
- sha256:0df5d700bb21193aa6362d7f537feaa346798291b20b0dd3436bf6a976d5dc5f  Shared/Services/SiriCapture.swift
- sha256:c9f6a9a9f6d8892eb4054a7eb3b8a8446659a8dd0e56f78eb2d52f4094e5094d  Shared/Services/SiriFields.swift

## Prüfbasis

- base: b63e6d27b10e6598ac9e916e973918200eebc48c
- blob:6ae94404ce84a697e5731e71c2a99d85844241bd  Shared/Enrichment/EnrichmentWriter.swift
- blob:f63254dd4f6280f7946cd398d18ad3f2596445a7  Shared/Services/CatalogService.swift
- blob:187f00430e7e3ee261e64b861de48f527df670b0  Shared/Services/SiriCapture.swift
- blob:05c8ac62f650d953369d91e7d210704e7da8d8ed  Shared/Services/SiriFields.swift

## Geprüfte Dateien

- sha256:fca0eda441e9f9b40a2c26c5aa1f54cacf0780bee90dc162aba917e5c8cf0c03  Shared/Enrichment/EnrichmentWriter.swift
- sha256:b10ff02e9265510c6014e342c2d0f1489bcc4b4eaf2e2bba77d9f913fda4c06c  Shared/Services/CatalogService.swift
- sha256:0df5d700bb21193aa6362d7f537feaa346798291b20b0dd3436bf6a976d5dc5f  Shared/Services/SiriCapture.swift
- sha256:c9f6a9a9f6d8892eb4054a7eb3b8a8446659a8dd0e56f78eb2d52f4094e5094d  Shared/Services/SiriFields.swift

## Prüfbasis

- base: b63e6d27b10e6598ac9e916e973918200eebc48c
- blob:6ae94404ce84a697e5731e71c2a99d85844241bd  Shared/Enrichment/EnrichmentWriter.swift
- blob:f63254dd4f6280f7946cd398d18ad3f2596445a7  Shared/Services/CatalogService.swift
- blob:187f00430e7e3ee261e64b861de48f527df670b0  Shared/Services/SiriCapture.swift
- blob:05c8ac62f650d953369d91e7d210704e7da8d8ed  Shared/Services/SiriFields.swift
