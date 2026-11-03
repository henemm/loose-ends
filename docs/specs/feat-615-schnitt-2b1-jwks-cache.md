---
entity_id: feat-615-schnitt-2b1-jwks-cache
type: feature
created: 2026-11-03
updated: 2026-11-03
status: draft
workflow: feat-615-s2b1-jwks-cache
---

# Spec: Apples Schlüssel abrufen und zwischenspeichern, Schnitt 2b-1 (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt 2b-1; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s2b1-jwks-cache.md`, Abschnitt „Analysis“. Vorgänger: Schnitt 2a (`docs/specs/feat-615-schnitt-2a-apple-token-pruefen.md`, PR #815), dessen Abschnitt „Festgelegt für S2b und S2c“ dieser Schnitt umsetzt. Der Tresor (`apple-vault.ts`) ist S2b-2, ein eigener Workflow.

## Purpose

`verifyIdentityToken` (S2a) bekommt die Schlüsselsuche `keys` hereingereicht. Dieser Schnitt baut sie: `createJwks` holt Apples öffentliche Schlüssel von `https://appleid.apple.com/auth/keys`, hält sie eine Stunde im Speicher und lädt bei einem unbekannten `kid` nach, aber nie öfter als einmal in 60 Sekunden. Ohne Cache träfe jede Anmeldung und jedes gefälschte Token Apples Endpunkt; ohne die Sperre wäre das Nachladen ein Hebel, Apple (und den eigenen Dienst) mit erfundenen `kid`s zu beschießen.

Es entsteht nur Dienstcode ohne Port und ohne Datenbank; `fetch` und die Uhr werden hereingereicht. Nichts ruft den Code auf (ADR-21: die App ruft den Dienst nirgends auf); S3 baut `createJwks` einmal beim Start. Ein echter Apple-Aufruf ist im Test nicht vorgesehen; die Tests belegen das Verhalten mit Stub-`fetch` und steuerbarer Uhr. Der Live-Abruf vom 2026-11-03 (200, drei RSA-Schlüssel, `alg` RS256, Antwortkopf `Cache-Control: no-store`) steht in der Analyse und begründet die feste TTL: Apples Cache-Köpfe taugen nicht als Quelle.

**Regeln vor Modell:** Zeitvergleich, Zähler, Karte. Es gibt keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 und die Festlegungen der S2a-Spec um, keine neue Architekturentscheidung, keine neue Abhängigkeit.
- **Rationale:** Cache, Sperre und Zeitlimit sind in der S2a-Spec vorgegeben. Neu festgeschrieben wird nur die Lücke dort: die 60-s-Sperre gilt für jeden Abruf, auch bei leerem oder abgelaufenem Cache (siehe „Festlegungen“).

## Source

**Files:** `server/src/apple-jwks.ts`, `server/test/apple-jwks.test.ts`, `CLAUDE.md`
**Identifier:** `createJwks`

Eigene Datei statt `apple.ts`: `apple.ts` bleibt wie gemergt (S2a-AC-18/19), und Cache-Zustand ist ein anderes Thema als die Token-Prüfung. Die neue Datei importiert aus `apple.ts` nur den Typ `KeyLookup`.

### Schnittstelle

`createJwks({ fetch, now, url? })` liefert `{ keys: KeyLookup }`. `fetch` ist das globale `fetch` oder ein Stub, `now` die Uhr in Millisekunden, `url` hat den Standard `https://appleid.apple.com/auth/keys`. `keys(kid)` ergibt das JWK des `kid` oder `"unknown_kid"` oder `"keys_unavailable"` und **wirft nie**.

### Festlegungen

- **Zustand:** Karte `kid` → JWK (oder leer), Zeitpunkt des letzten erfolgreichen Ladens, Zeitpunkt des letzten Abrufversuchs (Start `-Infinity`), laufender Abruf. Ein erfolgreicher Abruf **ersetzt** die Karte vollständig (Rotation und Widerruf: ein entfernter `kid` ist danach `unknown_kid`).
- **Suche `keys(kid)`:** `now` wird einmal gelesen. Ist der Cache frisch (`now − geladen < 3 600 000`) und der `kid` darin, kommt das JWK ohne Abruf. Sonst (Cache leer, abgelaufen oder `kid` unbekannt) wird ein Abruf angefordert; danach: `kid` gefunden → JWK, sonst `keys_unavailable`, wenn kein Cache da ist oder er abgelaufen ist, sonst `unknown_kid`.
- **Eine gemeinsame 60-s-Sperre für jeden Abruf, auch bei leerem und abgelaufenem Cache** (die Lücke der S2a-Vorgabe): ein Abruf nur, wenn `now − letzterVersuch ≥ 60 000`. Der Zeitpunkt wird **beim Start** des Abrufs gesetzt, also zählt auch ein Fehlschlag; sonst könnte ein Angreifer mit erfundenen `kid`s einen gestörten Abruf in Dauerschleife treiben. Innerhalb der Sperre antwortet die Suche aus dem Cache (Regel oben), ohne Netz.
- **Geteilter Abruf:** Läuft ein Abruf, warten alle gleichzeitigen Aufrufer auf denselben; der laufende Abruf wird am Ende (auch bei Fehler) freigegeben.
- **Abruf:** `fetch(url, { signal: AbortSignal.timeout(5000) })`. **Fehlschlag** (der alte Cache bleibt unverändert): Ausnahme, auch synchron geworfen, Zeitüberschreitung, Status ≠ 200, Körper kein JSON, `keys` keine Liste, kein einziger gültiger Eintrag (auch eine leere Liste, sonst löschte eine leere Antwort den guten Cache).
- **Einträge:** gültig ist ein Objekt (kein Array, nicht `null`) mit nicht leerem Text-`kid`. Ungültige werden übersprungen, bei doppeltem `kid` gewinnt der erste. `kty` und `alg` prüft weiter `verifyIdentityToken`.
- **Abgelaufener Cache und misslungenes Neuladen → `keys_unavailable`** (fail-closed, wie in S2a festgelegt). Apple kann einen kompromittierten Schlüssel zurückziehen; weiter benutzen, solange der Abruf gestört ist, würde ihn akzeptieren, und einen Abruf zu stören ist leichter als ein Token zu fälschen. Der Preis ist klein: Anmeldungen sind selten, der Zustand heilt sich nach höchstens 60 s.
- **Kein Größenlimit** für die Antwort: ein manipulierter Körper setzt gebrochenes TLS voraus, das Zeitlimit begrenzt den Abruf.
- **Stille und Länge:** kein `console`, kein `process.stdout`/`stderr`, keine Apple-Texte in Ergebnissen; jede Funktion höchstens 50 Zeilen (Abruf samt Parsen und Suche getrennt).

## Dependencies

| Abhängigkeit | Art |
|---|---|
| globales `fetch`, `AbortSignal.timeout` (Node 26) | Plattform, **keine neuen Pakete** |
| Typ `KeyLookup` aus `server/src/apple.ts` | bestehend, nur Typ-Import, `apple.ts` **unverändert** |
| `server/test/apple.test.ts`, `accounts.ts`, `main.ts`, `migrations/`, `.github/workflows/` | bestehend, **unverändert** |
| Apple JWKS | im Test durch Stub-`fetch` ersetzt |
| Downstream | S3 (HTTP-Rand baut `createJwks({ fetch, now: Date.now })` einmal beim Start), #621 (Connector-Anmeldung nutzt dieselbe Suche) |

## Acceptance Criteria

Alle Tests laufen im Prozess, ohne Port, ohne Netz und ohne Datenbank, mit `node:test` und `node:assert/strict`. Sie setzen einen Stub-`fetch` (mit Aufrufzähler und steuerbarer Antwort) und eine steuerbare Uhr ein. Fehlerfälle stehen tabellengetrieben in einer Fallliste, ein Fall je Zeile.

- **AC-1:** Laden und Cache: Der erste Aufruf `keys("k1")` ruft `fetch` genau einmal und liefert das JWK von `k1`; ein zweiter Aufruf für `k1` (und für `k2`, beide in der Antwort) liefert aus dem Cache ohne weiteren Abruf (Zähler bleibt 1). Test: `server/test/apple-jwks.test.ts`, „cache: laden und wiederverwenden“.
- **AC-2:** Unbekannter `kid`, frischer Cache: `keys("fremd")` löst genau ein Neuladen aus (Zähler 2) und ergibt `unknown_kid`; der bekannte `kid` bleibt danach gültig. Test: `apple-jwks.test.ts`, „kid: unbekannt lädt einmal nach“.
- **AC-3:** Sperre 60 s: Ein zweiter unbekannter `kid` 59 s nach dem Versuch löst keinen Abruf aus (`unknown_kid`, Zähler unverändert); nach 60 s löst er einen aus. Test: `apple-jwks.test.ts`, „sperre: 59 s und 60 s“.
- **AC-4:** Gleichzeitige Aufrufe: Fünf gleichzeitig gestartete Aufrufe mit unbekanntem `kid` (und fünf bei leerem Cache) lösen genau einen Abruf aus und bekommen alle dasselbe Ergebnis. Test: `apple-jwks.test.ts`, „parallel: ein Abruf“.
- **AC-5:** Fehlschläge ohne Cache: Für jede Zeile der Fallliste (Ausnahme, synchroner Wurf, Zeitüberschreitungsfehler, Status 500, 200 ohne JSON, `{}`, `{keys:"x"}`, `{keys:[]}`, nur ungültige Einträge) ergibt `keys` `keys_unavailable` und wirft nie. Test: `apple-jwks.test.ts`, „fehlschlag: ohne Cache“ (Fallliste).
- **AC-6:** Fehlschläge mit Cache: Für dieselbe Fallliste bleibt nach einem Fehlschlag beim Nachladen der alte `kid` gültig (JWK, kein erneuter Abruf), ein unbekannter `kid` ergibt `unknown_kid`, und der Cache wird nicht geleert. Test: `apple-jwks.test.ts`, „fehlschlag: alter Cache bleibt“ (Fallliste).
- **AC-7:** Fehlschlag setzt die Sperre: Nach einem misslungenen Abruf löst ein weiterer unbekannter `kid` vor Ablauf von 60 s keinen Abruf aus; ab 60 s wieder einen (bei leerem wie bei gefülltem Cache). Test: `apple-jwks.test.ts`, „sperre: auch nach Fehlschlag“.
- **AC-8:** TTL, Neuladen gelingt: Nach 1 h (`3 600 000` ms) wird beim nächsten Aufruf neu geladen und der neue Stand geliefert (ein vorher unbekannter `kid` wird jetzt gefunden); bei 59 min 59 s wird nicht neu geladen. Test: `apple-jwks.test.ts`, „ttl: nach einer Stunde neuer Stand“.
- **AC-9:** TTL, Neuladen misslingt, Sperre gilt auch hier: Nach 1 h mit misslungenem Neuladen ergibt `keys` für jeden `kid`, auch den vorher bekannten, `keys_unavailable` (fail-closed); ein weiterer Aufruf innerhalb von 60 s ruft nicht erneut ab, nach 60 s wird erneut abgerufen, und gelingt das, ist die Suche wieder gesund. Test: `apple-jwks.test.ts`, „ttl: abgelaufen und Abruf misslingt“.
- **AC-10:** Neuladen ersetzt: Enthält die zweite Antwort einen vorher bekannten `kid` nicht mehr, ergibt dieser nach dem Neuladen `unknown_kid`. Test: `apple-jwks.test.ts`, „rotation: entfernter kid“.
- **AC-11:** Einträge: Einträge ohne `kid`, mit Zahl, `null`, Array, leerem oder nicht-Text-`kid` werden übersprungen und die gültigen daneben gefunden; bei doppeltem `kid` gewinnt der erste. Test: `apple-jwks.test.ts`, „einträge: ungültige übersprungen“.
- **AC-12:** Aufruf von `fetch`: Standard-URL `https://appleid.apple.com/auth/keys`, mit `url` die übergebene URL; das zweite Argument trägt ein `AbortSignal`. Test: `apple-jwks.test.ts`, „fetch: url und signal“.
- **AC-13:** Stille und Nie-werfen: Während aller Aufrufe der Tests AC-1 bis AC-12 (Erfolg und jeder Fehlschlag) wird nichts nach `console` oder `process.stdout`/`process.stderr` geschrieben (der Test ersetzt sie vorübergehend), das Ergebnis ist immer ein JWK-Objekt oder einer der beiden festen Texte, und kein Ergebnis enthält Teile der Antwort oder des Fehlertextes (Testtext `GEHEIM-123` in der geworfenen Ausnahme). Test: `apple-jwks.test.ts`, „silence und feste Werte“.
- **AC-14:** Zusammenspiel: `verifyIdentityToken` aus `apple.ts` mit `createJwks(...).keys` und Stub-`fetch`, der das JWK eines selbst erzeugten RSA-Paars liefert, ergibt für ein gültig signiertes Token `{ ok: true }`; mit einem Token, dessen `kid` nicht in der Antwort steht, `unknown_kid`; bei misslingendem Abruf `keys_unavailable`. Test: `apple-jwks.test.ts`, „zusammenspiel: verifyIdentityToken“.
- **AC-15:** Regression, CI und Funktionslänge: Test: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, `server.yml` ist auf dem PR grün, `server/test/apple.test.ts` und die übrigen bestehenden Testdateien bleiben unverändert; jede Funktion in `server/src/apple-jwks.ts` hat höchstens 50 Zeilen (Prüfung in der Validierung: `grep -nE "function" server/src/apple-jwks.ts`, Abstand zweier Funktionsanfänge und Dateiende ≤ 50).
- **AC-16:** Dateigrenze: Test: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/apple-jwks.ts`, `server/test/apple-jwks.test.ts` und `CLAUDE.md`; `server/src/apple.ts`, `server/test/apple.test.ts`, `server/package.json`, `server/package-lock.json`, `server/src/main.ts`, `server/migrations/`, `.github/workflows/`, `project.yml` und jede Swift-Datei bleiben unberührt.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apple-jwks.ts` | CREATE | `createJwks`, Abruf mit Parsen und Suche als getrennte Funktionen, ~+55 |
| `server/test/apple-jwks.test.ts` | CREATE | AC-1 bis AC-14, tabellengetrieben, ~+130 bis 150 |
| `CLAUDE.md` | MODIFY | eine Zeile im Abschnitt `server/`: `src/apple-jwks.ts`, ~+1 bis 2 |

### Estimated Changes

- Files: 3 (2 neu, 1 geändert).
- LoC: ≈ 190 bis 210 gesamt, gezählt wie in S1 und S2a (Code, Tests und Doku zusammen): Code ≈ 55, Tests ≈ 130 bis 150, Doku ≈ 1 bis 2. Limit ±250. Zeichnet sich eine Überschreitung ab, wird gestoppt und nachgefragt. Funktionen ≤ 50 Zeilen.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, kein `generate`, keine Migration, kein Eingriff in `apple.ts`. Seiteneffekt außerhalb des Tickets: keiner; nichts ruft den Code auf.

## Risiken

- **Verstärkung gegen Apple:** Jeder Abruf zählt für die Sperre, auch ein Fehlschlag und auch bei leerem oder abgelaufenem Cache (AC-3, AC-7, AC-9). Das ist die Lücke der S2a-Vorgabe, hier festgeschrieben.
- **Rennen:** Gleichzeitige Prüfungen teilen einen Abruf (AC-4); sonst würde die Sperre im Rennen umgangen.
- **Leere Antwort:** Ein 200 mit leerer oder nur ungültiger Liste gilt als Fehlschlag, damit er den guten Cache nicht löscht (AC-5, AC-6).
- **Apple-Störung:** Nach Ablauf der TTL sind Anmeldungen bis zum nächsten gelungenen Abruf abgelehnt (`keys_unavailable`), höchstens 60 s pro Versuch; bewusst fail-closed.
- **Echtes Apple-Verhalten** (Rotation, Ratenbegrenzung des Endpunkts, keine veröffentlicht) ist offline nicht belegbar; der echte Lauf folgt mit S3/S4.
- **Kein Größenlimit** der Antwort (siehe Festlegungen).

## Test Plan

### Automated Tests (TDD RED)

RED: Zuerst `apple-jwks.test.ts`; `apple-jwks.ts` fehlt, die Tests schlagen fehl.

- [ ] Test 1 (AC-1, AC-2, AC-12): GIVEN Stub-`fetch` mit drei Schlüsseln WHEN erster, zweiter und unbekannter `kid` abgefragt werden THEN ein Abruf, Cache-Treffer, ein Nachladen und `unknown_kid`; URL und `AbortSignal` kommen bei `fetch` an.
- [ ] Test 2 (AC-3, AC-4, AC-7): GIVEN steuerbare Uhr WHEN unbekannte `kid`s bei 59 s und 60 s, fünf gleichzeitig und nach einem Fehlschlag abgefragt werden THEN Abruf nur nach 60 s, nie mehr als einer gleichzeitig.
- [ ] Test 3 (AC-5, AC-6): GIVEN die Fallliste der Fehlschläge WHEN ohne und mit Cache abgefragt wird THEN `keys_unavailable` bzw. alter Cache bleibt und `unknown_kid` für Fremde.
- [ ] Test 4 (AC-8, AC-9, AC-10): GIVEN Uhr bei 1 h WHEN Neuladen gelingt, misslingt, einen `kid` entfernt THEN neuer Stand, `keys_unavailable` samt Sperre, `unknown_kid`.
- [ ] Test 5 (AC-11): GIVEN Antwort mit gültigen und ungültigen Einträgen und Doppelten WHEN abgefragt THEN gültige gefunden, erster Doppelter gewinnt.
- [ ] Test 6 (AC-13): GIVEN `console.*` und `process.stdout/stderr` vorübergehend ersetzt WHEN alle Aufrufe laufen THEN keine Ausgabe, nur feste Werte, kein Fehlertext im Ergebnis.
- [ ] Test 7 (AC-14): GIVEN ein selbst signiertes Token und `createJwks` mit Stub-`fetch` WHEN `verifyIdentityToken` prüft THEN `ok`, `unknown_kid` bzw. `keys_unavailable`.
- [ ] Test 8 (AC-15, AC-16): GIVEN der fertige Zweig WHEN `./server/scripts/test-local.sh`, `server.yml` und `git diff --name-only origin/main -- . ':!docs' ':!.claude'` THEN grün, grün, genau die drei Dateien.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): eigener Cache mit `fetch`, TTL 1 h, 60-s-Sperre, fail-closed.** Klein genug (≈ 55 Zeilen), jede Zeile testbar, keine neue Abhängigkeit.
- **B: Kein Cache, Abruf je Anmeldung** (≈ 25 Zeilen). Kippt die Vorgabe „TTL 1 h + 60-s-Sperre“ der S2a-Spec; jede Apple-Störung blockiert jede Anmeldung, jedes gefälschte Token erzeugt einen Netzabruf.
- **C: `jose` mit `createRemoteJWKSet`** (Cache, Sperre, Zeitlimit fertig). Kippt die S2a-Entscheidung A (keine neuen Pakete, eigene Prüfung mit `node:crypto`) und bräuchte Hennings Freigabe; die eigene Lösung ist klein genug.
- **D: weiter mit dem alten Cache, wenn das Neuladen misslingt (stale-if-error).** Hielte Anmeldungen bei einer Apple-Störung am Leben, kippt aber die S2a-Vorgabe „`keys_unavailable`, wenn der Cache abgelaufen ist und das Neuladen misslang“: Ein von Apple zurückgezogener Schlüssel bliebe gültig, solange sich der Abruf stören lässt. Abgelehnt.
- **E: TTL aus Apples Antwortkopf.** Apple sendet `Cache-Control: no-store`; es gäbe keine TTL. Abgelehnt.

## Nicht in diesem Schnitt / Folgeschnitte

- S2b-2: Tresor (`apple-vault.ts`, Upsert in `apple_tokens`), eigener Workflow.
- S2c: `clientSecret`, `redeemCode`, `revokeToken`.
- S3 HTTP-Rand: Routen, `createJwks` einmal beim Start, Konfiguration. S4 App (nach #625).

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulator nötig. Nachweis: `./server/scripts/test-local.sh` (typecheck + `node --test`) grün und der CI-Job `server.yml` auf dem PR grün.
- Stufe 3 entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-16 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt `src/apple-jwks.ts`
- [ ] #615 kommentiert (Stand Schnitt 2b-1, Folge S2b-2/S2c), Board-Karte aktuell

## Changelog

- 2026-11-03: Initial spec created (Schnitt 2b-1)
