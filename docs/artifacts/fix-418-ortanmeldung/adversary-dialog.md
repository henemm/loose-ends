# Adversary Dialog — fix-418-ortanmeldung
Spec: docs/specs/fix-418-ortanmeldung.md
Datum: 2026-10-24

## Checkliste
- [x] **AC-1:** PROVEN. Code reference: LooseEnds/Notifications/PlaceNotificationCenter.swift:133 (je Anfrage do/catch, weiter mit der nächsten), :123 (Merkliste ohne Gescheiterte). Test permanentFailureDoesNotBlockTheRest (LooseEndsTests/PlaceNotificationCenterTests.swift:185) prüft per == `added == [good]`, Merkliste == [good], danach `[good, bad]`. Rot vorher: test-red-output.txt Zeile 55/56 (added == [good] und Merkliste fehlen); grün: test-green-output.txt Zeile 732.
- [x] **AC-2:** PROVEN. Code reference: LooseEnds/Notifications/PlaceNotificationCenter.swift:149 (restored = previous-Einträge der gescheiterten Aufgaben). Test failedTitleChangeKeepsTheOldEntry (PlaceNotificationCenterTests.swift:206) prüft alten Titel in der Merkliste, danach neuer Titel angemeldet und notiert. Hinweis: dieser Test war im roten Lauf schon grün (alter Code brach vor dem Schreiben ab, Liste blieb alt) — er ist Regressionswächter, kein Fehlerbeleg; ohne `restored` würde er rot (Eintrag fehlte).
- [x] **AC-3:** PROVEN. Code reference: LooseEnds/Notifications/PlaceNotificationCenter.swift:124 (`noted != previous`: leer == leer, kein Schreiben). Test failingAddKeepsTheListUnwritten (PlaceNotificationCenterTests.swift:170) unverändert, grün (Log).
- [x] **AC-4:** PROVEN. Code reference: LooseEnds/Notifications/PlaceNotificationCenter.swift:139 (`Logger.error` mit `reminder.identifier` und Fehler im catch). `grep try?` in der Datei: keine Treffer.
- [x] **AC-5:** PROVEN. Code reference: LooseEnds/Notifications/PlaceNotificationCenter.swift:125 (reconcileOnce fängt weiter alles, `hand` wirft nie; reconcile bleibt nicht-werfend). DueNotificationCenter unverändert (git status). Bestehende Tests grün.
- [x] **AC-6:** PROVEN. Code reference: LooseEnds/Notifications/PlaceNotificationCenter.swift:97. Log test-green-output.txt: Suite PlaceNotificationCenter passed; einziger Fehler KnaeuelTests.setWords (5 issues, Zeile 468-475). Unabhängig: Datei nicht im Diff (git status zeigt nur PlaceNotificationCenter.swift und feat-240-Spec), prüft lokalisierte Strings ("since this morning") mit Calendar/Locale — Zeitzone/Spracheinstellung des Simulators, kein Bezug zu Ortsmitteilungen. Nicht neu gelaufen; CI auf main laut Auftrag grün.
- [x] **AC-7:** nachgelagert (Simulator, Folgephase), nicht blockierend.
- [x] **AC-8:** nachgelagert (Gerät, TestFlight, nur nach Hennings Wort), nicht blockierend.

## Dialog

### Runde 1
**Adversary:** (a) Früher wurde bei authorized immer gespeichert, jetzt nur bei `noted != previous`. Kann ein nötiges Schreiben ausfallen? Handover ist `Equatable` synthetisiert (PlaceDelivery.swift Handover: Codable, Equatable), Array-Vergleich also mit Reihenfolge. Beide Seiten sind nach `taskID.uuidString` sortiert (diff: `changes(...)` sortiert; `handover(...)` sortiert nach demselben Schlüssel; gespeicherte Liste stammt aus eben diesem Pfad). Ein Reihenfolgefehler könnte höchstens ein überflüssiges Schreiben erzeugen, nie ein fehlendes. Gleich == gleich heißt inhaltlich identisch, also kein Verlust. Leer == leer: `loadHandover()` liefert bei fehlendem Schlüssel ebenfalls leer, Semantik gleich. (b) add-Ersatz: diff fügt die Kennung in `remove` ein (läuft vor `hand`, remove ist nicht werfend), add scheitert, alter Eintrag bleibt (alter Fingerabdruck); nächster Lauf: Fingerabdruck verschieden, nicht offen, also `.add`. updateContent: alte Anfrage bleibt offen, alter Eintrag mit altem Titel, nächster Lauf `.updateContent` erneut. Beide korrekt. (c) `PlaceScheduling.remove` ist nicht werfend (DueNotificationCenter.swift:472), Fehler in remove ist nicht möglich; nichts zu fangen. (d) kein try?, Logger.error mit Kennung. (e) Tests prüfen mit ==; roter Lauf zeigte Fehler.
**Implementierer:** Stimmt; Befunde siehe Runde 2.

### Runde 2
**Adversary:** Nachbohren an der schwächsten Stelle: dem Weglassen des Schreibens. Fall: gespeicherte Daten sind unlesbar (Dekodierfehler). `loadHandover()` (PlaceNotificationCenter.swift:168-176) gibt dann leer zurück. Ist `noted` ebenfalls leer (z.B. alles gescheitert oder keine Orte), wird nicht geschrieben, der kaputte Blob bleibt und erzeugt bei jedem Lauf die Logzeile "Reading the place handover failed". Früher wurde bei authorized immer überschrieben und damit geheilt. Folge gering: sobald irgendetwas übergeben wird, wird überschrieben. Weiter: Aufgabe mit Fehler, die zugleich aus dem Plan fällt — nicht möglich, gescheiterte Aufgaben stammen aus plan.watched. Mehrfach-Einträge je Aufgabe in previous: `restored` würde beide übernehmen, diff liefert aber höchstens einen; Eingabe stammt nur aus eigenem Schreiben. Nebenläufigkeit: ReconcileGate serialisiert, Wiederholung nur bei angemeldetem Nachlauf, keine Endlosschleife bei Dauerfehler. Tests: keine Abdeckung für den add-Ersatz-Fehlerfall (b) und für "unverändert, kein Schreiben". Logik per Code-Lesen korrekt, daher nur LOW.
**Implementierer:** Akzeptiert als LOW; Heilung des kaputten Blobs ist außerhalb des Auftrags.

Finding F001 (LOW, edge_case):
Code reference: LooseEnds/Notifications/PlaceNotificationCenter.swift:124 Unlesbare Merkliste plus leeres Ergebnis wird nicht überschrieben (früher immer). 
Spec requirement: AC-3. Conflict: keiner im Wortlaut, nur Selbstheilung entfällt. Remediation: optional nicht nötig.
Finding F002 (LOW, edge_case):
Code reference: LooseEndsTests/PlaceNotificationCenterTests.swift:206 Kein Test für add-Ersatz mit Fehlschlag; Logik per Lesen belegt. Remediation: optionaler Test.

Confirmation:
AC: AC-1
Code reference: LooseEnds/Notifications/PlaceNotificationCenter.swift:133
Evidence: do/catch je Anfrage, Test mit == belegt. Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

## Geprüfte Dateien

- sha256:62a5d4f29c3915eb63f9489fe66dd3749da9469a5339ba7a96e84c7a0c25c921  LooseEnds/Notifications/PlaceNotificationCenter.swift
- sha256:8cb07ae8a46212a5484410fb4dcbb75bc1c3ddee3606860bddb5881a29955cad  LooseEndsTests/PlaceNotificationCenterTests.swift

## Prüfbasis

- base: 96f79e8be9c336d4bd7b17d5f82fde53582e7f4f
- blob:38b4a97089fd54fbbcb24faa199d6680722960c7  LooseEnds/Notifications/PlaceNotificationCenter.swift
- blob:5572ffb146c1083efeaa44fc6a848bc8faa7df3e  LooseEndsTests/PlaceNotificationCenterTests.swift
