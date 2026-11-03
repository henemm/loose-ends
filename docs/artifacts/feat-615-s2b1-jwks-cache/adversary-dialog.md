# Adversary Dialog — feat-615-s2b1-jwks-cache
Spec: docs/specs/feat-615-schnitt-2b1-jwks-cache.md
Datum: 2026-11-03 09:29

## Checkliste
- [x] **AC-1:** Laden und Cache: Der erste Aufruf `keys("k1")` ruft `fetch` genau einmal und liefert das JWK von `k1`; ein zweiter Aufruf für `k1` (und für `k2`, beide in der Antwort) liefert aus dem Cache ohne weiteren Abruf (Zähler bleibt 1). Test: `server/test/apple-jwks.test.ts`, „cache: laden und wiederverwenden“.
- [x] **AC-2:** Unbekannter `kid`, frischer Cache: `keys("fremd")` löst genau ein Neuladen aus (Zähler 2) und ergibt `unknown_kid`; der bekannte `kid` bleibt danach gültig. Test: `apple-jwks.test.ts`, „kid: unbekannt lädt einmal nach“.
- [x] **AC-3:** Sperre 60 s: Ein zweiter unbekannter `kid` 59 s nach dem Versuch löst keinen Abruf aus (`unknown_kid`, Zähler unverändert); nach 60 s löst er einen aus. Test: `apple-jwks.test.ts`, „sperre: 59 s und 60 s“.
- [x] **AC-4:** Gleichzeitige Aufrufe: Fünf gleichzeitig gestartete Aufrufe mit unbekanntem `kid` (und fünf bei leerem Cache) lösen genau einen Abruf aus und bekommen alle dasselbe Ergebnis. Test: `apple-jwks.test.ts`, „parallel: ein Abruf“.
- [x] **AC-5:** Fehlschläge ohne Cache: Für jede Zeile der Fallliste (Ausnahme, synchroner Wurf, Zeitüberschreitungsfehler, Status 500, 200 ohne JSON, `{}`, `{keys:"x"}`, `{keys:[]}`, nur ungültige Einträge) ergibt `keys` `keys_unavailable` und wirft nie. Test: `apple-jwks.test.ts`, „fehlschlag: ohne Cache“ (Fallliste).
- [x] **AC-6:** Fehlschläge mit Cache: Für dieselbe Fallliste bleibt nach einem Fehlschlag beim Nachladen der alte `kid` gültig (JWK, kein erneuter Abruf), ein unbekannter `kid` ergibt `unknown_kid`, und der Cache wird nicht geleert. Test: `apple-jwks.test.ts`, „fehlschlag: alter Cache bleibt“ (Fallliste).
- [x] **AC-7:** Fehlschlag setzt die Sperre: Nach einem misslungenen Abruf löst ein weiterer unbekannter `kid` vor Ablauf von 60 s keinen Abruf aus; ab 60 s wieder einen (bei leerem wie bei gefülltem Cache). Test: `apple-jwks.test.ts`, „sperre: auch nach Fehlschlag“.
- [x] **AC-8:** TTL, Neuladen gelingt: Nach 1 h (`3 600 000` ms) wird beim nächsten Aufruf neu geladen und der neue Stand geliefert (ein vorher unbekannter `kid` wird jetzt gefunden); bei 59 min 59 s wird nicht neu geladen. Test: `apple-jwks.test.ts`, „ttl: nach einer Stunde neuer Stand“.
- [x] **AC-9:** TTL, Neuladen misslingt, Sperre gilt auch hier: Nach 1 h mit misslungenem Neuladen ergibt `keys` für jeden `kid`, auch den vorher bekannten, `keys_unavailable` (fail-closed); ein weiterer Aufruf innerhalb von 60 s ruft nicht erneut ab, nach 60 s wird erneut abgerufen, und gelingt das, ist die Suche wieder gesund. Test: `apple-jwks.test.ts`, „ttl: abgelaufen und Abruf misslingt“.
- [x] **AC-10:** Neuladen ersetzt: Enthält die zweite Antwort einen vorher bekannten `kid` nicht mehr, ergibt dieser nach dem Neuladen `unknown_kid`. Test: `apple-jwks.test.ts`, „rotation: entfernter kid“.
- [x] **AC-11:** Einträge: Einträge ohne `kid`, mit Zahl, `null`, Array, leerem oder nicht-Text-`kid` werden übersprungen und die gültigen daneben gefunden; bei doppeltem `kid` gewinnt der erste. Test: `apple-jwks.test.ts`, „einträge: ungültige übersprungen“.
- [x] **AC-12:** Aufruf von `fetch`: Standard-URL `https://appleid.apple.com/auth/keys`, mit `url` die übergebene URL; das zweite Argument trägt ein `AbortSignal`. Test: `apple-jwks.test.ts`, „fetch: url und signal“.
- [x] **AC-13:** Stille und Nie-werfen: Während aller Aufrufe der Tests AC-1 bis AC-12 (Erfolg und jeder Fehlschlag) wird nichts nach `console` oder `process.stdout`/`process.stderr` geschrieben (der Test ersetzt sie vorübergehend), das Ergebnis ist immer ein JWK-Objekt oder einer der beiden festen Texte, und kein Ergebnis enthält Teile der Antwort oder des Fehlertextes (Testtext `GEHEIM-123` in der geworfenen Ausnahme). Test: `apple-jwks.test.ts`, „silence und feste Werte“.
- [x] **AC-14:** Zusammenspiel: `verifyIdentityToken` aus `apple.ts` mit `createJwks(...).keys` und Stub-`fetch`, der das JWK eines selbst erzeugten RSA-Paars liefert, ergibt für ein gültig signiertes Token `{ ok: true }`; mit einem Token, dessen `kid` nicht in der Antwort steht, `unknown_kid`; bei misslingendem Abruf `keys_unavailable`. Test: `apple-jwks.test.ts`, „zusammenspiel: verifyIdentityToken“.
- [x] **AC-15:** Regression, CI und Funktionslänge: Test: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, `server.yml` ist auf dem PR grün, `server/test/apple.test.ts` und die übrigen bestehenden Testdateien bleiben unverändert; jede Funktion in `server/src/apple-jwks.ts` hat höchstens 50 Zeilen (Prüfung in der Validierung: `grep -nE "function" server/src/apple-jwks.ts`, Abstand zweier Funktionsanfänge und Dateiende ≤ 50).
- [x] **AC-16:** Dateigrenze: Test: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/apple-jwks.ts`, `server/test/apple-jwks.test.ts` und `CLAUDE.md`; `server/src/apple.ts`, `server/test/apple.test.ts`, `server/package.json`, `server/package-lock.json`, `server/src/main.ts`, `server/migrations/`, `.github/workflows/`, `project.yml` und jede Swift-Datei bleiben unberührt.

## Dialog

### Runde 1
**Adversary:** Je AC Beweis gegen Test und Code verlangt. Testlauf ./server/scripts/test-local.sh: Exit 0, 151 Tests, 151 bestanden, 0 fehlgeschlagen, 0 uebersprungen (voller Lauf in adversary-test-output.txt), Typecheck gruen.
- AC-1: Test cache: laden und wiederverwenden (apple-jwks.test.ts:46) zaehlt calls==1 nach drei Aufrufen; Code: Treffer in apple-jwks.ts:55 ohne refresh. PROVEN.
- AC-2: Test :55; der Test schiebt die Uhr um 60 s, weil die Sperre auch den ersten Nachladeversuch direkt nach dem Laden sperrt (apple-jwks.ts:44). Das ist spec-konform (Sperre gilt fuer jeden Abruf, Start -Infinity). PROVEN.
- AC-3: Test :65 prueft 59 s kein Abruf, 60 s Abruf; Code t - lastTry < LOCK (apple-jwks.ts:44), Grenze exakt. PROVEN.
- AC-4: Test :79, kalt und warm je fuenf parallel, calls 1 bzw. 2; Code: running wird vor der Sperre geprueft (apple-jwks.ts:43). PROVEN.
- AC-5/AC-6: Fallliste mit neun Zeilen (:34) in Tests :92 und :100; Code: download faengt alles in try/catch (apple-jwks.ts:25-31), toMap gibt bei leerer Karte undefined (:20), Karte wird nur bei Erfolg ersetzt (:47). PROVEN.
- AC-7: Test :114 leer und gefuellt. PROVEN. AC-8: Test :137, 59:59 kein Abruf, 60:00 Abruf (apple-jwks.ts:54, < TTL). PROVEN. AC-9: Test :151, fail-closed (:57), Sperre, Erholung. PROVEN.
- AC-10: Test :168, Karte wird ersetzt statt gemischt (:47). PROVEN. AC-11: Test :179, Code :16-18. PROVEN. AC-12: Test :187, Code :26. PROVEN.
- AC-13: Test :226 ersetzt console und stdout/stderr, prueft feste Werte und fehlenden Text GEHEIM; Code enthaelt kein console und gibt nie Fehlertexte weiter (catch ohne Bindung, :29). Der Test fuehrt die Szenarien erneut aus und prueft die results aller Tests, nicht die Ausgabe waehrend AC-1 bis AC-12 selbst; inhaltlich gleichwertig, da der Code keine Ausgabe enthaelt (F003). PROVEN.
- AC-14: Test :198 mit echtem RSA-Paar, ok/unknown_kid/keys_unavailable. PROVEN.
- AC-15 lokal: Suite gruen; Funktionslaengen: toMap 11, download 9, createJwks 27 Zeilen (Datei 61 Zeilen), alle <= 50; apple.ts und apple.test.ts unveraendert. Teil server.yml gruen auf dem PR: nach PR in /60-validate zu bestaetigen.
- AC-16 lokal: der Diff-Befehl der Spec gegen origin/main nennt CLAUDE.md und server/test/apple-jwks.test.ts; dazu die noch nicht versionierte Datei server/src/apple-jwks.ts laut Statusliste = genau die drei Dateien; nichts in package.json, main.ts, migrations, workflows, project.yml, Swift. Endgueltig nach Commit und PR: nach PR in /60-validate zu bestaetigen.
**Implementierer:** Keine Gegenargumente; alle Punkte stuetzen sich auf Test und Code. Hinweis zu AC-13 zugestanden.

### Runde 2
**Adversary:** Eigene Sonden, Wegwerf-Skript gegen server/src/apple-jwks.ts mit node (Type-Stripping), nichts im Repo geaendert.
- S1 Sperre bei leerem Cache, 5 fehlschlagende Aufrufe im Abstand von 100 ms: 1 Abruf, alle keys_unavailable. OK.
- S2 Fuenf parallel bei abgelaufenem Cache, langsamer Abruf (50 ms): 1 Abruf, alle bekommen JWK. OK.
- S3 Aufrufer mit spaeterer Uhr (+70 s) waehrend ein Abruf laeuft: kein zweiter Abruf, beide bekommen dasselbe. OK.
- S4 Fehlschlag nach TTL, dann 59,999 s: keys_unavailable ohne Abruf; bei 60 s Abruf und gesund. OK.
- S5 Sonderantworten: json() wirft, fetch liefert undefined, Koerper null, Koerper Zahl: alle keys_unavailable, kein Wurf. kid __proto__ wird als normaler Schluessel gefuehrt (Map). OK.
- S6 Uhr rueckwaerts um 10 h: Cache gilt weiter als frisch, unbekannter kid ohne Abruf unknown_kid; nach Sprung vorwaerts heilt es. Siehe F001 (LOW).
- S7 fetch-Stub, der das Signal ignoriert und nie antwortet: Aufruf haengt (running bleibt gesetzt). Das echte fetch bricht per AbortSignal.timeout ab (apple-jwks.ts:26). Siehe F002 (LOW, informativ).
- S8 Fehlertext: GEHEIM-123 taucht in keinem Ergebnis auf (Test :226 und Sonden).
**Implementierer:** F001: Spec verlangt keine monotone Uhr, die Verlaengerung ist auf die Dauer des Sprungs begrenzt. F002: Zeitlimit liegt beim fetch, wie in der Spec festgelegt. Beides kein Spec-Verstoss.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

| Feld | Produktions-Schreibstellen | Bedingung davor | Test fuer diesen Weg |
|---|---|---|---|
| cache | apple-jwks.ts:47 (einzige) | download lieferte eine nicht leere gueltige Karte (Status 200, JSON, keys Liste, mindestens ein gueltiger Eintrag) | fehlschlag: alter Cache bleibt (apple-jwks.test.ts:100), rotation: entfernter kid (:168) |
| loadedAt | apple-jwks.ts:47 (einzige, gemeinsam mit cache) | wie cache, gesetzt auf die Uhr des Aufrufs, der den Abruf startete | ttl: nach einer Stunde neuer Stand (:137), ttl: abgelaufen und Abruf misslingt (:151) |
| lastTry | apple-jwks.ts:45 (einzige) | kein Abruf laeuft und now - lastTry >= 60000; gesetzt beim Start, auch fuer Fehlschlaege | sperre: 59 s und 60 s (:65), sperre: auch nach Fehlschlag (:114) |
| running | apple-jwks.ts:46 setzen, :48 freigeben (finally) | gesetzt nur nach bestandener Sperre; freigegeben nach Erfolg und Fehler | parallel: ein Abruf (:79), fehlschlag: ohne Cache (:92) |

## Verdict

VERDICT: VERIFIED

Tests: 151 bestanden, 0 fehlgeschlagen, 0 uebersprungen (Typecheck gruen).
Checkliste: 16/16; AC-15 (server.yml gruen) und AC-16 (Diff nach Commit) nach PR in /60-validate zu bestaetigen.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: server/src/apple-jwks.ts:54
  Description: Bei rueckwaerts springender Uhr bleibt t - loadedAt negativ, der Cache gilt bis zur Aufholung als frisch, Neuladen ist ueber die Sperre ebenfalls verzoegert.
  Evidence: Sonde S6, Uhr -10 h, bekannter kid liefert JWK ohne Abruf.
  Remediation: Optional in S3 eine monotone Uhr reichen; kein Handlungsbedarf in diesem Schnitt.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/apple-jwks.ts:26
  Description: Das Zeitlimit haengt allein am AbortSignal von fetch; ein fetch, das das Signal ignoriert, laesst running dauerhaft gesetzt.
  Evidence: Sonde S7 (Stub ohne Antwort).
  Remediation: Optional Promise.race mit eigenem Timer; mit dem echten fetch nicht erreichbar.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: server/test/apple-jwks.test.ts:226
  Description: AC-13 laesst die Szenarien in einem eigenen Test erneut laufen statt die Stille waehrend der Tests AC-1 bis AC-12 zu messen; Wirkung gleich, da der Code keine Ausgabe enthaelt.
  Evidence: Testtext :225-251.
  Remediation: keine noetig.

## Code-Referenzen
- Code reference: server/src/apple-jwks.ts:42
- Code reference: server/test/apple-jwks.test.ts:46
- Code reference: CLAUDE.md:465

## Geprüfte Dateien

- sha256:f3717c800a963da0d3f6487686874128ab17a546af145ea094b08d678c0e5cd9  server/src/apple-jwks.ts
- sha256:a7fa19b21db8febbbacfdeb4c6106e86a88c8e6c4a2a64e7000220008d4c78ed  server/test/apple-jwks.test.ts

## Prüfbasis

- base: 22b5681bda0fc3804729b2ec409f4f3829216830
- blob:462218b12bd1da4a7d0f26d02498611e5e8c5311  server/src/apple-jwks.ts
- blob:287f24c3ecffac72cfaa6eb1a51fbca81e56f54b  server/test/apple-jwks.test.ts
