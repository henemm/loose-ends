# Adversary Dialog — spike-613-c3-dienstkern
Spec: docs/specs/spike-613-schnitt-c3a-abschrift-annehmen.md
Datum: 2026-11-01 12:09

## Checkliste
- [x] **AC-1:** `checkTranscript` nimmt das Abschrift-Beispiel aus den ```json-Blöcken von `docs/reference/claude-abschrift-vertrag.md` an (gelesen zur Laufzeit, nicht abgeschrieben, erster von drei Blöcken wie in `schema.test.ts`) und wirft nicht; ebenso ein Beispiel mit kleingeschriebenen UUIDs und ohne `now.knaeuel`/`dueDate`/`project`/`nextRank`.
- [x] **AC-2:** (Z1) Fehlt `version` oder ist sie `"1"` oder `2`, wirft `checkTranscript` eine Meldung, die `version` nennt; `putTranscript` schreibt nichts (`SELECT count(*) FROM transcripts` = 0).
- [x] **AC-3:** (Z2) Fehlt `generatedAt` oder hat es keine Zeitzone (`2026-03-12T09:00:00`), wirft `checkTranscript` eine Meldung mit `generatedAt`; nichts in `transcripts`.
- [x] **AC-4:** (Z3) Ist `now` kein Objekt (Liste `[]` oder String `"x"`), wirft `checkTranscript` eine Meldung mit `now`; nichts in `transcripts`.
- [x] **AC-5:** (Z4) Ein fremder Schlüssel in `now` (`extra`) bzw. ein fehlendes `waiting` wird mit Meldung `now.extra` bzw. `now.waiting` abgewiesen; nichts in `transcripts`.
- [x] **AC-6:** (Z5) Ist `now.knaeuel` vorhanden, aber keine UUID (`"abc"` oder die Zahl `5`), nennt die Meldung `now.knaeuel`; fehlt der Schlüssel ganz, wird die Abschrift angenommen.
- [x] **AC-7:** (Z6) Ist `now.today`, `now.lined` oder `now.waiting` keine Liste oder enthält ein Element, das keine UUID ist, nennt die Meldung den Pfad (zum Beispiel `now.today[0]`); je Liste ein Fall im Test; nichts in `transcripts`.
- [x] **AC-8:** (Z7) Ist `contexts` einer Aufgabe keine Liste von Strings (`"Computer"` oder `[1]`), nennt die Meldung `tasks[1].contexts`; nichts in `transcripts`.
- [x] **AC-9:** (Z8) Ist `title` einer Aufgabe kein String (`5`) bzw. `project` kein String (`false`), nennt die Meldung `tasks[0].title` bzw. `tasks[1].project`; nichts in `transcripts`.
- [x] **AC-10:** (Z9, F005) `rawText` oder `note` an einer Aufgabe, verschachtelt in `now` (`{"now": {…, "rawText": "…"}}`) oder tief in einer Struktur (Objekt als `contexts`-Element) wird abgewiesen; die Meldung enthält den vollen Pfad des Schlüssels; nichts in `transcripts`.
- [x] **AC-11:** (Z10) Ein fremder Schlüssel an der Wurzel (`revisions`) bzw. ein `nowCount` von `"3"`, `-1` oder `1.5` wird mit Meldung `revisions` bzw. `nowCount` abgewiesen; nichts in `transcripts`.
- [x] **AC-12:** `putTranscript(pool, "henning", doc)` für ein Konto ohne Zeile liefert `"stored"`; die Zeile hat `account_id = 'henning'`, `doc` gleich dem Dokument und `generated_at` gleich `doc.generatedAt`.
- [x] **AC-13:** Eine Abschrift mit neuerem `generatedAt` für dasselbe Konto liefert `"stored"` und ersetzt `doc` und `generated_at`; es bleibt genau eine Zeile (`count(*)` = 1) und `received_at` ist nicht älter als vorher.
- [x] **AC-14:** Eine Abschrift mit älterem `generatedAt` liefert `"older"`; eine mit gleichem `generatedAt` (anderer Inhalt, etwa anderer `nowCount`) ebenfalls; in beiden Fällen sind `doc`, `generated_at` und `received_at` der Zeile unverändert.
- [x] **AC-15:** Zwei gleichzeitige Uploads über zwei Verbindungen (`Promise.all` mit zwei Pools desselben Schemas; je eine Abschrift mit älterem und neuerem `generatedAt`, im Test in beiden Aufrufreihenfolgen) enden immer mit der neueren Abschrift in der Zeile, dazu genau ein Ergebnis `"stored"` oder zwei, nie die ältere gespeichert nach der neueren.
- [x] **AC-16:** Zwei verschiedene Konten (`henning`, `anna`) halten je eine Abschrift unabhängig voneinander; ein Upload für `anna` berührt die Zeile von `henning` nicht.
- [x] **AC-17:** Der Dienst rechnet nichts nach: eine formgültige Abschrift, deren `nowCount` (7) nicht zur Größe von `now` und deren `now`-Kennungen nicht in `tasks` stehen, wird angenommen (`"stored"`).
- [x] **AC-18:** `server/migrations/001_claude_schema.sql` bleibt unverändert (die Dateiliste des PR enthält keine Datei unter `server/migrations/`), und `server/test/schema.test.ts` bleibt ohne Änderung grün (die DB-CHECKs sind weiterhin die zweite Wand).
- [x] **AC-19:** `OrderExecutor.setDue` an einer erledigten Aufgabe (`status = .done`) liefert `rejected/stale` mit `taskID`; `dueDate`, `dueHasTime` der Aufgabe sind unverändert und es gibt keine neue `Revision`. Belegt durch `LooseEndsTests/OrderExecutorTests.swift`, ein Fall (Fälligkeit gleich dem erwarteten Stand).
- [x] **AC-20:** `OrderExecutor.setDue` an einer gelöschten Aufgabe (`status = .removed`) liefert `rejected/stale` mit `taskID`; Fälligkeit unverändert, keine neue `Revision`. Belegt durch einen eigenen Fall im selben Testbestand.
- [x] **AC-21:** `OrderExecutor.setDue` an einer offenen Aufgabe (`active`, ebenso `parked`) mit passendem erwarteten Stand setzt die Fälligkeit wie bisher (`done`, Revision mit Grund „Claude“); die bestehenden `setDue`-Tests bleiben unverändert grün.
- [x] **AC-22:** `docs/reference/claude-abschrift-vertrag.md` ist angepasst: Der Punkt „`setDue` prüft den Status nicht …“ unter „Ebenso offen in Version 1“ ist gestrichen und als Regel formuliert (ein erledigter oder gelöschter Stand ist `stale`, der Status zählt zum erwarteten Stand); ein Satz sagt, dass der Dienst die Abschrift nur annimmt, wenn ihre Form stimmt, und eine vorhandene nur durch eine mit neuerem `generatedAt` ersetzt. Die drei ```json-Blöcke bleiben unverändert (Anzahl und Inhalt), `schema.test.ts` bleibt grün.
- [x] **AC-23:** `./server/scripts/test-local.sh` ist grün (Typprüfung `npm run typecheck` ohne Fehler, alle Tests gegen das Wegwerf-Postgres) und räumt auf; `./scripts/sim.sh sim-unit OrderExecutorTests` ist grün; der Workflow `server.yml` ist auf dem PR grün. Die Dateiliste des PR enthält außer den unter Scope genannten fünf nichts: kein `project.yml`, kein CloudKit-Schema, keine `CLAUDE.md`-Änderung.

## Dialog

### Runde 1
**Adversary:** Alle 33 Server-Tests laufen gruen (test-local.sh, Typpruefung gruen, Exit 0, Ausgabe: adversary-test-output.txt) und `sim-unit OrderExecutorTests` ist gruen. Das ist erst der halbe Weg. Eigene Probe gegen ein Wegwerf-Postgres (Schema `probe`, Migration 001 angewendet), 33 Abweichungen ueber die Tests hinaus:
- Abgewiesen mit Pfad-Meldung wie gefordert: Array/null als Wurzel, `tasks: null`, `tasks[0]: null`, UUID ohne Bindestriche, UUID mit Zeilenumbruch am Ende, `nextRank` -1 und 1.5, `dueDate` ohne Zeitzone, unbekannter Status, `generatedAt` `2026-13-40T00:00:00Z`, `+25:00`, Kleinbuchstabe `z`, Zeilenumbruch am Ende, `version` 2.
- Atomaritaet: eine Anweisung, `WHERE transcripts.generated_at < excluded.generated_at` (transcripts.ts:97-99). 40 gleichzeitige Uploads ueber 8 Pools in zufaelliger Reihenfolge: Endstand `nowCount` 39 (die neueste), 9 mal "stored". Gleicher Zeitpunkt anderer Schreibweise (`10:00:00+01:00`, `09:00:00.000000Z`) -> "older", Zeile unveraendert. Ungueltige Abschrift mit neuerem Datum auf bestehender Zeile: wirft vor jedem Schreiben, Zeile byte-gleich.
- BRUCH 1: Fremde Schluessel mit Namen aus der Object-Prototype-Kette (`toString`, `constructor`, `valueOf`, `hasOwnProperty`, `__proto__`) werden von `shape` NICHT als unbekannt erkannt, weil `key in required` (transcripts.ts:58) die Prototype-Kette mitliest. `now.toString = "x"` -> `"stored"`, der Schluessel steht danach in der Zeile (die DB-CHECKs pruefen `now` nicht). An der Wurzel und an Aufgaben faengt erst der DB-CHECK (SQLSTATE 23514, nackte Postgres-Meldung statt Pfad-Meldung). Heisst: die Behauptung "genau diese Schluessel, kein anderer" (AC-5, AC-11) ist falsch, und `now` ist ein Kanal fuer beliebige Zusatzdaten (Privacy-Linie #625 nur fuer `rawText`/`note` namentlich, nicht fuer Fremdschluessel).
- BRUCH 2: `time` (transcripts.ts:42-44) prueft nur Regex plus `Date.parse`. Was JS annimmt, lehnt Postgres ab -> nackter SQLSTATE statt Meldung: `2026-02-30T00:00:00Z` (22008), `0000-01-01T00:00:00Z` (22008), `+275760-09-13T00:00:00Z` (22009). Umgekehrt nimmt es Nicht-ISO-Text an, der mit Zeitzone endet: `March 12 2026 09:00 UTC+01:00`, `2026-03-12Z`, `2026-03-12T24:00:00Z` (alle "stored", der Text steht so in `doc`).
- BRUCH 3: Zeichenketten mit NUL (`\u0000`) oder einzelnem Surrogat in `title`/`contexts` passieren die JS-Pruefung, `JSON.stringify` -> jsonb wirft 22P05 / 22P02 (nackt).
- Sonst nichts: leeres Konto `""` wird gespeichert (nicht in der Spec). AC-18: `git diff --stat HEAD` zeigt nur OrderExecutor.swift (+1) und claude-abschrift-vertrag.md (+7/-2); nichts unter server/migrations, kein project.yml, keine CLAUDE.md.
**Implementierer:** (nicht beteiligt, Kontextisolierung)

### Runde 2
**Adversary:** Zweiter Blick gezielt auf die uebrigen ACs, nicht auf den ersten Eindruck.
- AC-19/AC-20: Der Test (OrderExecutorTests.swift:201-216) ist parametrisiert ueber `.done` und `.removed`, Fälligkeit gleich dem erwarteten Stand, prueft `.stale` mit `taskID` und `Snapshot` vorher/nachher (keine Revision). Die Zeile `guard completable.contains(task.status)` (OrderExecutor.swift:78) steht VOR dem Faelligkeitsvergleich, nach `missing`: Reihenfolge invalid > missing > stale bleibt. Die Einzelergebnisse stehen nur im xcresult; `Test Succeeded`.
- AC-21: `.parked` hat eigenen Test (Zeile 218); `.active` ueber die bestehenden setDue-Tests, unveraendert gruen.
- AC-22: Vertrag: Satz zur Annahme (Zeilen 29-30) und Regel "Status zaehlt zum erwarteten Stand" (Zeilen 101-102) vorhanden, der Punkt unter "Ebenso offen" gestrichen, drei json-Bloecke unveraendert (diff zeigt keine Aenderung in ihnen; `schema.test.ts` gruen).
- AC-17: nowCount 7 vs. Groesse, fremde now-IDs: "stored" (Test + Code, keine Abgleichszeile).
- AC-1/6/12-16: Code und Tests gelesen und selbst ausgefuehrt; Mehrverbindungs-Race durch eigene 40er-Probe bestaetigt.
- AC-5/AC-11 bleiben DISPROVEN wegen Bruch 1: der Test benutzt nur `extra`/`revisions`, nie einen Prototype-Namen; Beleg `now.toString` -> stored. Remediation: `Object.hasOwn(required, key)` statt `in` (und `Object.hasOwn(value, key)` bei `key in value`), oder `Object.create(null)`/`Map`; plus Test.
- Zu AC-23: `server.yml` auf dem PR ist erst in Phase 7 pruefbar (PR existiert noch nicht), kein Defekt.
- Funktionen: alle <= 50 Zeilen, keine neue Abhaengigkeit (package.json unveraendert).
**Implementierer:** (nicht beteiligt)


### Runde 3
**Adversary:** Fix-Runde 1 nachgeprüft (36 von 36 Servertests grün, `sim-unit OrderExecutorTests` grün, Ausgabe in adversary-test-output.txt). Alle Proben aus Runde 1 erneut gegen Wegwerf-Postgres:
- F001 behoben: `toString`, `constructor`, `valueOf`, `hasOwnProperty`, `__proto__` (per JSON.parse als eigener Schlüssel) an Wurzel, `now` und Aufgabe werden jetzt mit Pfad-Meldung ("... unbekannter Schlüssel") abgewiesen, nichts steht in der DB (`Object.hasOwn`, transcripts.ts:69, 72, 76).
- F002 behoben: `2026-02-30`, Jahr 0000, `+275760-...`, Klartextdatum, `2026-03-12Z`, `T24:00:00Z`, `T09:00:60Z`, `2025-02-29`, `2026-04-31`, Monat 00, Tag 00, Kleinbuchstaben-`t`, Leerzeichen statt T, ohne Sekunden, `+0100`, `+01`, `.Z`, Leerzeichen am Ende: alle mit Meldung abgewiesen. Angenommen und von Postgres geschluckt: `Z`, `.5Z`, `.123456789Z`, `-00:00`, `+14:00`, `-12:00`, `+15:59`, `2024-02-29`, `0001-01-01T00:00:00Z` und `+01:00`, `9999-12-31T23:59:59Z` und `-01:00`. Reihenfolge: gleiche Zeitpunkte in anderer Schreibweise (`+01:00`, `-00:00`) -> "older"; `.5Z` danach -> "stored".
- Regression durch das Muster ausgeschlossen: `TranscriptCodec` kodiert mit `dateEncodingStrategy = .iso8601` (TranscriptCodec.swift:74), das ergibt immer `yyyy-MM-ddTHH:mm:ssZ` ohne Bruchteil und mit `Z`; das Muster nimmt das an (Beispiel aus dem Vertrag und Tests grün). Bruchteile und `-00:00` werden zusätzlich angenommen.
- F003 behoben: NUL und einzelnes Surrogat in `title`, `contexts`, `project` -> Meldung "ungültiges Zeichen" mit Pfad; Emoji (gültiges Paar) wird weiter gespeichert.
- NEUE LUECKE (F005, LOW): Der Zeitzonenversatz wird nur als `[+-]\d{2}:\d{2}` geprüft, nicht auf den Bereich. `+99:99`, `+24:00`, `+00:60` in `generatedAt` -> nackter SQLSTATE 22009 aus Postgres (kein Schreiben, kein Datenverlust, Wurf bleibt atomar). In `dueDate` wird `+99:99` angenommen und unverändert gespeichert (Postgres prüft `dueDate` nicht). Der Codec erzeugt nur `Z`, das Risiko betrifft nur fremde Aufrufer; kein AC fordert es (AC-3 verlangt Zeitzone vorhanden).
- F004 (leeres Konto) vom Koordinator als akzeptiertes LOW-Restrisiko geführt: Konten kommen mit C6, Spec schweigt.
- Funktionen weiter höchstens 50 Zeilen, keine neue Abhängigkeit; geändert sind nur transcripts.ts und transcripts.test.ts gegenüber Runde 1, nichts unter server/migrations.
**Implementierer:** (nicht beteiligt)

### Runde 4
**Adversary:** Nachprüfung der Korrektur von F005 aus der Validierung (Versatz auf ±15:59 begrenzt).
- `./server/scripts/test-local.sh`: 37 Tests, 37 bestanden, 0 fehlgeschlagen, 0 übersprungen, Exit 0 (adversary-test-output.txt), darunter `F002 times Postgres refuses or that are no ISO` und `F002: offsets up to ±15:59 are stored, as Postgres takes them`.
- Grenzwerte in `generatedAt` gegen echtes Postgres 18: `+15:59`, `-15:59`, `+00:00`, `-00:00`, `Z`, `.123456+15:59`, `.5-15:59`, `.123456789Z` gespeichert; `+16:00`, `-16:00`, `+15:60`, `+01:60`, `+99:00` und ohne Zone: „Abschrift ungültig: generatedAt: kein Zeitpunkt mit Zeitzone“, kein SQLSTATE, nichts gespeichert.
- Erschöpfender Abgleich aller 20.000 Versätze (± × 00–99 × 00–99) gegen `$1::timestamptz`: Prüfer nimmt 1920 an (2 × 16 × 60), davon lehnt Postgres 0 ab; Postgres nähme keinen an, den der Prüfer ablehnt. Grenze deckt sich exakt.
- `Z` ohne Versatzgruppen: `x ?? 0` ergibt 0, kein NaN (transcripts.ts:48-52), `Z` wird gespeichert.
- `dueDate` `+99:00` abgelehnt mit „tasks[0].dueDate: kein Zeitpunkt mit Zeitzone“; `+15:59` und `Z` angenommen.
- Reihenfolge unverändert: gleiche Zeit anderer Schreibweise (`+02:00`, `-15:59`, `+15:59`) → "older", eine Minute später → "stored".
- Diff gegenüber Runde 3: nur transcripts.ts (Muster Zeile 26, `time` Zeilen 46–55) und transcripts.test.ts; alle Funktionen ≤ 50 Zeilen.
**Implementierer:** (nicht beteiligt)

Bestätigungen:

Confirmation: AC-1 bis AC-11 (Form, Pfad-Meldungen, Fremdschlüssel inkl. Prototype-Namen, Zeitwerte, Zeichen)
Code reference: server/src/transcripts.ts:69
Evidence: Object.hasOwn in shape, striktes ISO-Muster in time (Zeile 47), clean in text/names (Zeile 37); Probe und 36 Tests grün
Status: CONFIRMED

Confirmation: AC-12 bis AC-17 (Speichern, ersetzen, älter/gleich, Race, Konten, nichts nachrechnen)
Code reference: server/src/transcripts.ts:112
Evidence: eine Anweisung mit WHERE transcripts.generated_at < excluded.generated_at; 40er-Race in Runde 1 und gleiche Zeitpunkte in anderer Schreibweise -> older
Status: CONFIRMED

Confirmation: AC-19 bis AC-21 (setDue-Status)
Code reference: Shared/Services/OrderExecutor.swift:78
Evidence: Statusprüfung vor Fälligkeitsvergleich; sim-unit grün
Status: CONFIRMED

Confirmation: AC-22 (Vertrag)
Code reference: docs/reference/claude-abschrift-vertrag.md:29
Evidence: Annahmesatz und Statusregel vorhanden, Punkt gestrichen, drei json-Blöcke unverändert
Status: CONFIRMED

Confirmation: Tests
Code reference: server/test/transcripts.test.ts:70
Evidence: Tabelle deckt Prototype-Namen, Zeitwerte und NUL/Surrogat ab (Zeilen 70-81)
Status: CONFIRMED

Confirmation: Tests Swift
Code reference: LooseEndsTests/OrderExecutorTests.swift:201
Evidence: parametrisierter done/removed-Fall, Snapshot vorher/nachher gleich
Status: CONFIRMED

Confirmation: AC-18, AC-23
Code reference: server/src/transcripts.ts:26
Evidence: nichts unter server/migrations, kein project.yml/CLAUDE.md; server.yml auf dem PR nachgelagert in Phase 7, kein Defekt
Status: CONFIRMED

Finding:
ID: F001
Severity: HIGH
Category: spec_violation
Code reference: server/src/transcripts.ts:69
Description: Prototype-Namen als fremde Schlüssel (Runde 1: behoben, Object.hasOwn)
Evidence: Runde 3 Probe: alle abgewiesen mit Pfad
Remediation: erledigt
Status: FIXED

Finding:
ID: F002
Severity: MEDIUM
Category: edge_case
Code reference: server/src/transcripts.ts:47
Description: Zeitwerte, die JS annahm und Postgres ablehnte (Runde 1: behoben, striktes Muster)
Evidence: Runde 3 Probe: alle sechs abgewiesen mit Meldung
Remediation: erledigt
Status: FIXED

Finding:
ID: F003
Severity: LOW
Category: edge_case
Code reference: server/src/transcripts.ts:37
Description: NUL und einzelnes Surrogat (behoben, clean)
Evidence: Runde 3 Probe: Meldung mit Pfad
Remediation: erledigt
Status: FIXED

Finding:
ID: F004
Severity: LOW
Category: edge_case
Code reference: server/src/transcripts.ts:105
Description: Leeres Konto wird gespeichert, Konten kommen mit C6, Spec schweigt (akzeptiertes Restrisiko)
Evidence: Probe Runde 1
Remediation: mit C6

Finding:
ID: F005
Severity: LOW
Category: edge_case
Code reference: server/src/transcripts.ts:51
Description: Der Zeitzonenversatz wurde nicht auf den Bereich geprüft (+99:99 gab SQLSTATE 22009, in dueDate gespeichert); jetzt prüft `time` zusätzlich `oh <= 15 && om <= 59`, das Muster in Zeile 26 fängt den Versatz in eigenen Gruppen
Evidence: Runde 4: Abgleich aller 20.000 Versätze gegen Postgres deckungsgleich, 37/37 Tests grün
Remediation: erledigt
Status: FIXED

Confirmation: AC-19 bis AC-21 (setDue-Status)
Code reference: Shared/Services/OrderExecutor.swift:78
Evidence: OrderExecutorTests 14/14 grün in der Validierung, Statusprüfung vor dem Fälligkeitsvergleich
Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

## Geprüfte Dateien

- sha256:e0dde6093b14146df1347040365cd7d3875e14cef8f367d2b5f6905598cf3c04  LooseEndsTests/OrderExecutorTests.swift
- sha256:1c9d521adeead90aa481a5f11af1e3de324dbb85283aad2c08085f1a0e3f689f  Shared/Services/OrderExecutor.swift
- sha256:4ffa4c4d734e9a2002db5631f43c60626d094c60d228dff052bac5c30fd5f04d  docs/reference/claude-abschrift-vertrag.md
- sha256:40f11563474ef15f194be2dc0defb89cfac8131e9b641060c889dd1b543fa67f  server/src/transcripts.ts
- sha256:fc05f2ccee0cad1713e21e0a2b20f187fd0a412e8350923d44844503da85fc1b  server/test/transcripts.test.ts

## Prüfbasis

- base: 6bb98b225f3d418f6cf52fc602ece09cda6f1816
- blob:0af95f999b27e84ff0f7eaf7e4496aa9ab7f7432  LooseEndsTests/OrderExecutorTests.swift
- blob:5761990382a429a672edd8bcb05f4b75382ea1a6  Shared/Services/OrderExecutor.swift
- blob:14532c9cbf3f5681909c74864dd6bdff7ca42629  docs/reference/claude-abschrift-vertrag.md
- blob:f3c314d24f952c47b8d85ddf5002182ec2fa6bac  server/src/transcripts.ts
- blob:248f14d3bbae91bb7b0eaf9c828fc95cd6680116  server/test/transcripts.test.ts
