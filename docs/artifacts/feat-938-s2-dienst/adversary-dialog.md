# Adversary Dialog — feat-938-s2-dienst
Spec: docs/specs/feat-938-schnitt-2-dienst.md
Datum: 2026-11-19 20:34

## Checkliste
- [x] **AC-1:** `checkOrder` nimmt das Vertragsbeispiel `capture` mit `repeat` und `link` an; der Test liest es gezielt aus dem Vertrag, und der Auftrag wird unverändert gespeichert (Test 1).
- [x] **AC-2:** `checkOrder` nimmt `repeat` mit `frequency` allein und mit jeder Kombination aus `interval` 1…52, `weekdays` (nur `weekly`, nicht leer, je 1…7) und `basis` bei `capture` und `update` an (Test 2).
- [x] **AC-3:** `checkOrder` weist ein `repeat` mit `interval` außerhalb 1…52 oder nicht ganzzahlig, unbekannter `frequency` oder `basis`, falschen `weekdays` (leer, außerhalb 1…7, nicht ganzzahlig, nicht bei `weekly`), fehlender `frequency`, fremdem Schlüssel oder Nicht-Objekt mit `Auftrag ungültig: <pfad> …` ab, ohne dass etwas gespeichert wird (Test 3).
- [x] **AC-4:** `checkOrder` nimmt einen `link` mit Schema `http` oder `https` und Host bei `capture` an und weist andere Schemata, fehlenden Host, fehlendes Schema und Nicht-Text mit Pfad `fields.link` ab (Test 4).
- [x] **AC-5:** `checkOrder` weist `fields.link` bei `update` mit `Auftrag ungültig: fields.link …` ab; ein `update` nur mit `repeat` wird angenommen (Test 5).
- [x] **AC-6:** `capture_task` und `update_task` reichen `repeat` (und `link` bei `capture_task`) unverändert in den Auftrag; `update_task` setzt für `repeat` nur `expectedStatus` und keinen weiteren Erwartungswert (Test 6).
- [x] **AC-7:** Die Werkzeuge weisen `link` bei `update_task`, ein Tippfehler im `repeat` und Werte außerhalb der Form ab, ohne Auftrag und ohne Wecken der Geräte (Test 7).
- [x] **AC-8:** Das zod-Schema ist `.strict()`, auch für das `repeat`-Objekt; `update_task` hat genau die Schlüssel von `capture_task` ohne `notes` und `link` (Test 8).
- [x] **AC-9:** Die Beschreibungen beider Werkzeuge nennen die Abweichung „n-ter Wochentag“ (jährlich zum Datum, dem Nutzer nennen), `capture_task` nennt `link`; die Anleitung ist unverändert und ≤ 2048 Byte (Test 9, 10).
- [x] **AC-10:** Der Vertrag beschreibt die Annahme von `repeat` und `link` in der Gegenwart (kein „bis dahin weist er sie ab“ mehr), die Beispielblöcke sind unverändert; alle bestehenden Tests bleiben grün, Aufträge ohne `repeat`/`link` sind byte-gleich; `./server/scripts/test-local.sh` ist grün (Test 10, Prüfung im Review).

## Dialog

### Runde 1
**Adversary:** Testlauf selbst: `./server/scripts/test-local.sh` > adversary-test-output.txt, Ergebnis 492 pass, 0 fail, 0 skipped, Exit 0 (erster Lauf grün; migrate.test.ts:216 / #959 nicht aufgetreten, hängt ohnehin nicht an orders.ts/mcp.ts). Geänderte Dateien gelesen:
- server/src/orders.ts:61-79 (repeat-Check: shape mit Pflicht frequency, optional interval/weekdays/basis; weekdays nur bei weekly über hasOwn; link-Check mit URL.parse, Schema http/https, Host nicht leer; link nur im withNotes-Zweig, also nicht bei update).
- server/src/mcp.ts:301-327,374-379 (zod strict auch im repeat, updateFieldsSchema = omit notes+link, Beschreibungen).
- server/test/orders.test.ts:411-483 (AC-1..5), server/test/mcp-write.test.ts:289 ff. und server/test/mcp.test.ts:436 (Werkzeuge, Schlüsselmengen, Beschreibungen).
Randfälle direkt gegen checkOrder gefahren: weekdays ohne frequency → `fields.repeat.frequency: fehlt`; Duplikate [1,1,2] angenommen (laut Spec erlaubt); `__proto__` im repeat → unbekannter Schlüssel; interval NaN/"2" abgewiesen; `https://user@/` abgewiesen; `http://[::1]` angenommen (gültiger Host); `https://exa mple.org` abgewiesen; update mit link → abgewiesen (Pfad fields.link, belegt durch Test AC-5; mein Handversuch scheiterte nur an einer Fantasie-taskID).
Auffällig: `" https://example.org"`, `"https://example.org "`, `"http:example.org"`, `"https:///x"`, `"https://@x"` werden vom Dienst angenommen (WHATWG normalisiert), Swifts URL(string:) lehnt sie vermutlich ab.
**Implementierer:** Spec Zeile 63/67/152 legt URL.parse ausdrücklich fest und benennt genau diese Abweichung; Folge ist nur `invalid` der App, keine Aufgabe, kein Schaden. Kein Verstoß.

### Runde 2
**Adversary:** Regression: Aufträge ohne repeat/link laufen durch denselben Code wie zuvor (nur zusätzliche optionale Schlüssel in shape); Gesamtlauf 492 grün belegt die bestehenden Tests. update_task: expected() mcp.ts:97-110 liefert nur status/dueDate/nextRank, repeat fügt nichts hinzu (AC-6). Fehlerpfad storeOrder mcp.ts:121-127: checkOrder wirft vor putOrder und vor wake, also kein Auftrag, kein Wecken (AC-7). anleitung.ts ungeändert (nicht in der Änderungsliste), 1463 Byte ≤ 2048. Vertrag: Gegenwartsformulierung in docs/reference/claude-abschrift-vertrag.md:129-137, Beispielblöcke nicht im Diff.
**Implementierer:** Keine Einwände.

Befund außerhalb des Umfangs: #959 (migrate.test.ts:216, flaky) – in meinem Lauf nicht aufgetreten, nicht ursächlich mit dieser Änderung verbunden.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`).

Confirmation:
  AC: AC-1
  Code reference: server/test/orders.test.ts:423
  Evidence: Test liest das Vertragsbeispiel aus dem Vertrag, checkOrder nimmt es an, gespeichert unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/src/orders.ts:61
  Evidence: repeat-Check nimmt frequency allein und alle Kombinationen; Test orders.test.ts:439 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/test/orders.test.ts:457
  Evidence: Abweisungstabelle mit Pfaden, nichts gespeichert; eigene Probe NaN, proto, fehlende frequency bestätigt.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/orders.ts:68
  Evidence: URL.parse, http(s), Host nicht leer, Pfad fields.link; Test orders.test.ts:468.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/src/orders.ts:78
  Evidence: link nur im withNotes-Zweig, daher bei update unbekannter/abgewiesener Schlüssel; Test orders.test.ts:477.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/mcp.ts:97
  Evidence: expected() liefert für update nur Status (+ Titel etc.), repeat wird unverändert durchgereicht; Test mcp-write.test.ts:289 ff.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/test/mcp-write.test.ts:289
  Evidence: Werkzeugtests für link bei update_task, Tippfehler im repeat, kein Auftrag, kein Wecken. Produktcode siehe mcp.ts:121.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/src/mcp.ts:121
  Evidence: storeOrder prüft checkOrder vor putOrder und wake.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/src/mcp.ts:301
  Evidence: strict inkl. repeat-Objekt (mcp.ts:306-309), updateFieldsSchema omit notes+link (mcp.ts:313).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/src/mcp.ts:315
  Evidence: gemeinsamer Text repeating mit n-ter-Wochentag-Abweichung in beiden Beschreibungen (326, 377), link in capture_task; anleitung.ts unverändert, 1463 Byte; Test server/test/mcp.test.ts:436.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: server/test/mcp.test.ts:436
  Evidence: 492 pass, 0 fail, Vertrag in Gegenwart, Beispielblöcke nicht im Diff.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: server/src/orders.ts:68
  Description: URL.parse normalisiert Leerzeichen am Rand, "http:example.org", "https:///x" und akzeptiert sie; der Auftrag wird unverändert gespeichert.
  Spec requirement: AC-4 und Spec Z. 67 — WHATWG-Abweichung zu Swift ist ausdrücklich zugelassen.
  Conflict: Keiner im Sinn der Spec; die App lehnt mit invalid ab, es entsteht keine Aufgabe.
  Remediation: Keine nötig; optional trim/Regex vorab.

## Verdict
VERDICT: VERIFIED
Tests: 492 passed, 0 failed, 0 übersprungen (Erstlauf grün, adversary-test-output.txt)
Edge cases: geprüft, F001 nur LOW und von der Spec gedeckt
Regressions: None found
Checklist: 10/10 points proven

## Geprüfte Dateien

- sha256:68abfa1ad23cfa36fa27e057b7fe627387deeac7fa7eb1bac7dcda5440db8dd5  server/src/mcp.ts
- sha256:651d116635ce034bdd503c20f6244e82235d5de66fec6dac2e58b0bc9e585f32  server/src/orders.ts
- sha256:4e5be2e38d44c987de6c83504d463526bd2f53f21c8b2462b58046ef05c6b2cc  server/test/mcp-write.test.ts
- sha256:36ad9848ad928432c1ac8fdf5688abd648319315ad5e68e70f3cbbfea9629692  server/test/mcp.test.ts
- sha256:372a6f17f7ab13a398661573ac7aab71a21d767031f73690554045ba3fd19f03  server/test/orders.test.ts

## Prüfbasis

- base: 820199ad60aa3617de7ae566f5aa4d1cf23981fb
- blob:9c7a330e1c020da368b5a964f2b53c484e7e4714  server/src/mcp.ts
- blob:7172f380e12e4bd139b20011dcd07b918c53c15b  server/src/orders.ts
- blob:e0fa8029e579c8372047ff87d6235a8fd49a3ec3  server/test/mcp-write.test.ts
- blob:9ee0d0b4b6bcc7f9b1c74b802f4386542a45a2b5  server/test/mcp.test.ts
- blob:a7f88615bb4536464f0864e4948c076c65776ff5  server/test/orders.test.ts
