# Context: feat-615-s2b1-jwks-cache

## Request Summary
#615 Schnitt 2b-1 (Epic #612, Weg B, ADR-21): Der Dienst holt Apples öffentliche Schlüssel (`https://appleid.apple.com/auth/keys`)
und liefert daraus die Schlüsselsuche `keys`, die `verifyIdentityToken` (S2a) hereingereicht bekommt. Cache mit TTL, Neuladen bei
unbekanntem `kid`, Fehler beim Abruf ohne Verlust des alten Caches. Der Tresor (`apple-vault.ts`) ist S2b-2, eigener Workflow.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/apple.ts` | Enthält `KeyLookup` (`(kid) => Promise<JsonWebKey \| "unknown_kid" \| "keys_unavailable">`) und `verifyIdentityToken`; hier kommt `createJwks` dazu (oder in eine eigene Datei, Entscheidung in der Analyse) |
| `server/test/apple.test.ts` | Bestehende Tests S2a (Stub-Suche, feste Uhr `NOW`, eigenes RSA-Paar `rsa`/`JWK`); neue Tests für den Cache mit injiziertem `fetch` und `now` |
| `docs/specs/feat-615-schnitt-2a-apple-token-pruefen.md` | Abschnitt „Festgelegt für S2b und S2c“: verbindliche Vorgaben für `createJwks` |
| `docs/artifacts/feat-615-s2-apple-anbindung/` | Adversary-Dialog S2a (Format, Angriffsdenken) |
| `server/src/main.ts` | Einstieg (#796); ruft `apple.ts` noch nicht auf, S3 hängt die Routen ein. Unverändert |
| `CLAUDE.md` | Zeile `src/apple.ts` im Abschnitt `server/` um den Cache ergänzen |

## Existing Patterns
- **Abhängigkeiten hereinreichen:** `verifyIdentityToken` bekommt `keys` und `now` als Parameter; Tests ersetzen Netz und Uhr. Dasselbe für `createJwks({ fetch, now, url? })`.
- **Nie werfen, feste Gründe:** Ergebnisse sind Werte (`"unknown_kid"`, `"keys_unavailable"`), keine Ausnahmen; keine Apple-Texte in Gründen.
- **Stille:** kein `console`, kein `process.stdout/stderr` (AC-17 aus S2a).
- **Nur Standardbibliothek:** Node 26, globales `fetch`, `AbortSignal.timeout`; keine neuen Pakete (S2a-Entscheidung A gegen `jose`).
- **Tests:** `node:test` + `node:assert/strict`, tabellengetriebene Falllisten, ohne Port/Netz/Datenbank.
- **Funktionen ≤ 50 Zeilen.**

## Dependencies
- Upstream: globales `fetch` (Node 26), `AbortSignal.timeout(5000)`, Typ `KeyLookup` aus `apple.ts`.
- Downstream: S3 (HTTP-Rand) baut einmal beim Start `createJwks({ fetch, now: Date.now })` und reicht `keys` an `verifyIdentityToken`; #621 (Connector-Anmeldung) nutzt dieselbe Suche.

## Existing Specs
- `docs/specs/feat-615-schnitt-2a-apple-token-pruefen.md`: TTL 1 h; unbekannter `kid` → einmaliges Neuladen, höchstens alle 60 s; Abruf mit `AbortSignal.timeout(5000)`; misslungener Abruf (Ausnahme, Status ≠ 200, kein JSON, keine `keys`-Liste) behält den alten Cache; `keys_unavailable` nur, wenn kein Cache da ist oder er abgelaufen ist und das Neuladen misslang, sonst `unknown_kid`; Tests mit injiziertem `fetch` und `now`.
- `docs/specs/feat-615-schnitt-1-konten-sitzungen.md`: Kontoschlüssel `apple_sub`.

## Recherche (2026-11-03)
- Live-Abruf `https://appleid.apple.com/auth/keys`: 200, drei Schlüssel, alle `kty` RSA, `alg` RS256 (`nP41CGTvOz`, `GNCf4J83Oh`, `8nTlO3M2Bk`).
  Antwortkopf `Cache-Control: no-store`, `Pragma: no-cache` → HTTP-Cache-Köpfe taugen nicht als TTL-Quelle; eine feste TTL ist nötig.
- Apple rotiert Schlüssel jederzeit; der `kid` im Token wählt den Schlüssel (Apple-Forum, https://developer.apple.com/forums/thread/133699).
- Übliches Muster: Cache mit mäßiger TTL, bei unbekanntem `kid` einmal neu laden, erst danach ablehnen (z. B. `cheers-providers` Apple-JWKS-Cache, https://docs.rs/crate/cheers-providers/latest/source/src/providers/apple/jwks_cache.rs; JWKS-Leitfaden https://mojoauth.com/glossary/oidc-json-web-key-endpoint.md). Eine von Apple veröffentlichte Ratenbegrenzung für den Endpunkt wurde nicht gefunden.

## Risks & Considerations
- **Gleichzeitige Anfragen:** Mehrere Prüfungen mit unbekanntem `kid` zur selben Zeit dürfen nicht mehrere Abrufe auslösen → laufenden Abruf teilen (eine Promise), sonst wird die 60-s-Sperre im Rennen umgangen.
- **Sperre auch bei Fehlschlag:** Ein misslungener Abruf muss die 60-s-Sperre ebenfalls setzen, sonst hämmert ein Angreifer mit erfundenen `kid`s Apple (Verstärkung). Jeder Abruf zählt.
- **Erfundene kids:** Ohne Sperre löst jedes gefälschte Token einen Netzabruf aus (DoS auf Apple-Endpunkt bzw. eigenen Dienst).
- **Abgelaufener Cache + Abruf misslingt:** Vorgabe ist `keys_unavailable` (fail-closed). Alternative: alten Cache weiter benutzen (stale-if-error). Abwägung in der Analyse.
- **Fehlerhafte Einträge:** Antwort mit Einträgen ohne `kid`, Nicht-Objekten oder `keys` als Nicht-Liste; ungültige Einträge überspringen statt den ganzen Abruf verwerfen? Festlegen in der Analyse. Die `kty`/`alg`-Prüfung bleibt in `verifyIdentityToken`.
- **Antwortgröße:** Ein manipulierter Antwortkörper ist nur bei kompromittiertem TLS denkbar; Größenbegrenzung abwägen.
- **Zeitüberschreitung:** `AbortSignal.timeout(5000)` wirft bei Ablauf; muss als misslungener Abruf zählen.
- **LoC:** Ziel ≤ 250 inkl. Tests (Schätzung ≈ 50 Code, ≈ 125–150 Tests, 1 Doku).
- Kein Pfad der Geräteliste berührt (nur `server/`).

## Analysis

### Type
Feature (Dienstbaustein ohne sichtbare Änderung in der App; nichts ruft ihn bis S3 auf).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apple-jwks.ts` | CREATE | `createJwks({ fetch, now, url? })` → `{ keys: KeyLookup }`; importiert nur den Typ `KeyLookup` aus `apple.ts` |
| `server/test/apple-jwks.test.ts` | CREATE | Cache-Tests mit Stub-`fetch` (Zähler, steuerbare Antworten) und steuerbarer Uhr |
| `CLAUDE.md` | MODIFY | Abschnitt `server/`: Zeile zu `src/apple-jwks.ts` |
| `server/src/apple.ts`, `server/test/apple.test.ts` | unverändert | S2a bleibt wie gemergt |

Eigene Datei statt `apple.ts`: `apple.ts` hat 99 Zeilen, die S2a-Spec (AC-18/19) legt deren Dateigrenze fest, und Cache-Zustand ist ein anderes Thema als die Token-Prüfung.

### Scope Assessment
- Files: 3 (2 neu, 1 Doku)
- Estimated LoC: ≈ +55 Code, ≈ +130–150 Tests, +1–2 Doku → ≈ 190–210, unter 250
- Risk Level: LOW — neuer, isolierter Baustein ohne Aufrufer; Fehler zeigen sich erst ab S3. Kein Pfad der Geräteliste berührt.

### Technical Approach (Empfehlung)
- **Zustand:** `map: Map<kid, JWK> | null`, `loadedAt`, `lastAttempt` (Start `-Infinity`), `inflight: Promise<boolean> | null`. Ein erfolgreicher Abruf **ersetzt** die Map vollständig (Rotation und Widerruf: ein entfernter `kid` ist danach `unknown_kid`).
- **`keys(kid)`:** `now` einmal lesen. Cache frisch (`now − loadedAt < 3 600 000`) und `kid` vorhanden → JWK. Sonst (leer, abgelaufen, `kid` unbekannt) Neuladen anfordern; danach `kid` gefunden → JWK, sonst `keys_unavailable` wenn kein oder abgelaufener Cache, sonst `unknown_kid`.
- **Eine gemeinsame 60-s-Sperre für jeden Abruf**, auch bei leerem und abgelaufenem Cache (Lücke der S2a-Vorgabe, wird in der S2b-1-Spec festgeschrieben): Abruf nur, wenn `now − lastAttempt ≥ 60 000`; `lastAttempt` wird **beim Start** gesetzt, also zählt auch ein Fehlschlag (Schutz gegen erfundene `kid`s, keine Verstärkung gegen Apple).
- **Geteilter Abruf:** läuft einer, warten alle gleichzeitigen Aufrufer auf dieselbe Promise; `inflight` wird in `finally` zurückgesetzt.
- **Abruf:** `fetch(url, { signal: AbortSignal.timeout(5000) })`, Standard-URL `https://appleid.apple.com/auth/keys`. Fehlschlag (alter Cache bleibt): Ausnahme (auch synchron), Zeitüberschreitung, Status ≠ 200, kein JSON, `keys` keine Liste, **kein einziger gültiger Eintrag** (auch leere Liste — sonst löschte eine leere Antwort den guten Cache). Die Suche wirft nie, keine Ausgabe auf Konsole/stdout/stderr.
- **Einträge:** gültig = Objekt (kein Array, nicht `null`) mit nicht leerem Text-`kid`; ungültige werden übersprungen; doppelter `kid` → der erste gewinnt. `kty`/`alg` prüft weiter `verifyIdentityToken`.
- **Abgelaufener Cache + misslungenes Neuladen → `keys_unavailable` (fail-closed, wie in S2a festgelegt).** Grund: Apple kann einen kompromittierten Schlüssel zurückziehen; stale-if-error würde ihn weiter akzeptieren, solange der Abruf gestört ist — und den Abruf stören ist leichter als ein Token fälschen. Der Preis ist klein: Anmeldungen sind selten, der Zustand heilt sich nach ≤ 60 s.
- **Kein Größenlimit** für die Antwort: ein manipulierter Körper setzt gebrochenes TLS voraus; das Zeitlimit begrenzt den Abruf.
- Funktionen ≤ 50 Zeilen (Abruf/Parsen und Suche getrennt).

### Testliste (für die Spec)
1. Erster Aufruf lädt und findet den `kid`; zweiter Aufruf im Cache ohne Abruf.
2. Unbekannter `kid` bei frischem Cache: ein Neuladen, danach `unknown_kid`.
3. Zweiter unbekannter `kid` nach 59 s: kein Abruf; nach 60 s: Abruf.
4. Fünf gleichzeitige Aufrufe: genau ein Abruf.
5. Fehlschläge (Tabelle: Ausnahme, synchroner Wurf, Timeout-Fehler, 500, 200 ohne JSON, `{}`, `{keys:"x"}`, `{keys:[]}`, nur ungültige Einträge): ohne Cache `keys_unavailable`; mit Cache bleibt der alte `kid` gültig, ein unbekannter ist `unknown_kid`; der Fehlschlag setzt die Sperre.
6. Nach 1 h + erfolgreichem Neuladen: neuer Stand.
7. Nach 1 h + misslungenem Neuladen: `keys_unavailable`; nächster Versuch erst nach 60 s.
8. Neuladen ersetzt den Cache: entfernter `kid` → `unknown_kid`.
9. Ungültige Einträge übersprungen (ohne `kid`, Zahl, `null`, Array); doppelter `kid`: erster gewinnt.
10. URL (Standard und `url`) und ein `AbortSignal` werden an `fetch` übergeben.
11. Stille: kein `console`/`stdout`/`stderr`.
12. Zusammenspiel: `verifyIdentityToken` mit `createJwks(...).keys` und Stub-`fetch` liefert `{ ok: true }` für ein gültiges Token.

### Alternativen (geprüft, nicht empfohlen)
- **Kein Cache, Abruf je Anmeldung** (≈ 25 LoC): kippt „TTL 1 h + 60-s-Sperre“ aus der S2a-Spec; jede Apple-Störung blockiert jede Anmeldung, jedes gefälschte Token erzeugt einen Netzabruf.
- **`jose` mit `createRemoteJWKSet`** (Cache, Sperre, Zeitlimit fertig): kippt S2a-Entscheidung A (keine neuen Pakete, eigene Prüfung mit `node:crypto`). Die eigene Lösung ist klein genug.
- **stale-if-error** statt fail-closed: siehe oben, aus Sicherheitsgründen abgelehnt.

### Dependencies
Upstream: globales `fetch`, `AbortSignal.timeout` (Node 26), Typ `KeyLookup` aus `apple.ts`. Downstream: S3 baut `createJwks({ fetch, now: Date.now })` einmal beim Start; #621 nutzt dieselbe Suche.

### Open Questions
- keine (alle Punkte technisch; die Sperre bei abgelaufenem Cache wird in der S2b-1-Spec festgeschrieben, die S2a-Spec bleibt unverändert)
