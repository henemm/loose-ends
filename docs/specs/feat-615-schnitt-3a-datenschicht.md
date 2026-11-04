---
entity_id: feat-615-schnitt-3a-datenschicht
type: feature
created: 2026-11-04
updated: 2026-11-04
status: draft
workflow: feat-615-s3-http-rand
---

# Spec: Datenschicht für Anmelden und Löschen, Schnitt 3a (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt 3a; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s3-http-rand.md`, Abschnitt „Analysis“ (dort ist Schnitt 3 in S3a, S3b und S3c geschnitten; diese Spec ist nur S3a). Vorgänger: Schnitt 2c-2 (`docs/specs/feat-615-schnitt-2c2-apple-widerruf.md`), dessen Abschnitt „Für S3 festgehalten“ die `client_id`-Ablage offen ließ.

## Für den PO

Löscht jemand sein Konto, verlangt Apple, dass wir den Schlüssel, den wir bei der Anmeldung bekommen haben, mit derselben Kennung zurückgeben, mit der sich die Person angemeldet hat. Wir haben bisher nur den Schlüssel selbst abgelegt, nicht die Kennung. Dieser Schnitt sorgt dafür, dass wir uns die Kennung künftig mit merken: Beim Prüfen der Apple-Anmeldung lesen wir sie mit aus, legen sie neben dem Schlüssel ab, und beim Löschen geben wir sie zusammen mit dem Schlüssel zurück. In der App ändert sich nichts Sichtbares, und nichts ruft diese Bausteine auf. Es gibt in Produktion auch noch keine abgelegten Schlüssel, die nachgetragen werden müssten. Als Nächstes folgt S3b (Anmelden und Abmelden), danach S3c (Konto löschen, Verdrahtung und Schutz am Rand).

## Purpose

Datenschicht für den Widerruf beim Löschen (ADR-21), ohne HTTP, ohne Routen, ohne `main.ts`:

1. `verifyIdentityToken` liefert im Erfolgsfall zusätzlich die geprüfte `aud` (die Client-ID, für die Apple den Token ausgestellt hat).
2. Migration 003 ergänzt `apple_tokens.client_id` (additiv, nullable).
3. `storeRefreshToken` legt die Client-ID mit ab.
4. `deleteAccount` gibt die Client-ID zusammen mit dem verschlüsselten Token zurück.

Nichts ruft die geänderten Funktionen im Produktpfad auf (S3b und S3c tun es). **Regeln vor Modell:** reine Daten- und Protokollarbeit, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Quellen (Recherche 2026-11-04, aus der Analyse): Apple TN3194 (`client_id` beim Widerruf muss der bei der Anmeldung entsprechen; fehlt der Token, muss die Löschung trotzdem erfolgen); Entwicklerforum Thread 844628 (offene Frage zur Reichweite über Client-IDs).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 und die in S2a bis 2c-2 festgelegte Reihenfolge um; keine neue Architekturentscheidung, keine neue Abhängigkeit.
- **Rationale:** Festgelegt werden hier nur drei Dinge. (1) Eigene Spalte statt `clientIds[0]`: `clientIds` kann mehrere Einträge haben, und ein geratener erster Eintrag wäre bei einem zweiten Client still falsch (Apple würde mit `invalid_client` ablehnen, und der Widerruf ginge unbemerkt verloren). (2) Zeilen ohne Wert (vor 003 abgelegt): der Widerruf entfällt später mit einer Logzeile; das Löschen blockiert nie (TN3194). Es gibt in Produktion keine solchen Zeilen, weil S3 noch niemand aufruft. (3) `client_id` ist keine Geheimnis-Klasse wie Token oder Secret, kommt aber trotzdem nie in Logzeilen oder Fehlertexte.

## Source

**Files:** `server/src/apple.ts`, `server/migrations/003_apple_client_id.sql`, `server/src/apple-vault.ts`, `server/src/accounts.ts`, `server/test/apple.test.ts`, `server/test/apple-jwks.test.ts`, `server/test/apple-vault.test.ts`, `server/test/accounts.test.ts`, `server/test/schema.test.ts`, `CLAUDE.md`
**Identifier:** `Verdict`, `verifyIdentityToken`, `storeRefreshToken`, `Deletion`, `deleteAccount`, Migration `003_apple_client_id.sql`

### Schnittstelle

- `Verdict = { ok: true; sub: string; aud: string } | { ok: false; reason: string }`. `verifyIdentityToken` setzt `aud` auf den geprüften Wert `payload.aud`, der nach der bestehenden Prüfung (`typeof string` und in `config.clientIds` enthalten) feststeht. Fehlerformen bleiben exakt `{ ok: false, reason }`.
- Migration `003_apple_client_id.sql`: `ALTER TABLE apple_tokens ADD COLUMN client_id text;` — nullable, ohne Vorgabewert, kein `BEGIN`/`COMMIT` (der Runner wickelt ein), Kommentar im Stil von 002 (Zweck, additiv, Zeilen ohne Wert bedeuten „kein Widerruf möglich“).
- `storeRefreshToken(pool, accountId, blob, clientId): Promise<boolean>`. Der Upsert setzt `client_id` ein und ersetzt sie bei Konflikt zusammen mit `refresh_token_enc` und `created_at`. `clientId` muss ein nicht-leerer Text sein, sonst **wirft** die Funktion (Fehlbedienung) vor jedem Datenbankzugriff; die Meldung enthält den Wert nicht. Unbekanntes Konto (23503) bleibt `false`.
- `Deletion = { deleted: boolean; appleToken: Buffer | null; clientId: string | null }`. `deleteAccount` liest `t.client_id` in derselben Abfrage mit. Unbekanntes Konto oder Konto ohne Token ergibt `clientId: null`; ein Konto mit Token aus der Zeit vor 003 ergibt `appleToken: Buffer`, `clientId: null`.

### Bestehende Tests, die mitgehen müssen

- `server/test/apple.test.ts` Zeilen 99, 100, 102, 175, 184, 192 (`{ ok: true, sub: SUB }`) bekommen `aud` (Zeile 100: `IDS[1]`, die übrigen die Standard-Client-ID des Testaufbaus). Das ist die **einzige erlaubte Änderung bestehender Testfälle** dieser Datei; alle Fehlerfälle bleiben byte-gleich.
- `server/test/apple-jwks.test.ts` Zeile 217 (`{ ok: true, sub: "001.abc.002" }`) bekommt `aud: "com.henning.looseends"`; die Fehlerfälle in Zeile 219 und 221 bleiben unverändert. (Beim Lesen der Dateien gefunden; in der Analyse nicht genannt.)
- `server/test/apple-vault.test.ts` Zeilen 121 bis 176: jeder Aufruf von `storeRefreshToken` bekommt das vierte Argument; am Inhalt der Prüfungen ändert sich nichts.
- `server/test/accounts.test.ts` Zeilen 136, 148, 154: `deepEqual` auf `Deletion` um `clientId` ergänzt (Zeile 136 mit dem Wert, den der Test ablegt, Zeilen 148 und 154 mit `null`).
- `server/test/accounts.test.ts` Zeile 60 und `server/test/schema.test.ts` Zeilen 59 und 64 haben die Migrationsliste fest verdrahtet (`["001_claude_schema.sql", "002_accounts.sql"]`, Anzahl 2). Sie laufen gegen den echten Ordner `server/migrations/` und müssen um `003_apple_client_id.sql` bzw. Anzahl 3 ergänzt werden. `server/test/migrate.test.ts` nutzt eigene temporäre Ordner und bleibt unberührt; `transcripts`, `orders`, `mcp` und `main` rufen `migrate` nur auf, ohne die Liste zu prüfen.

### Festlegungen

- **Stille:** kein `console`, kein `process.stdout`/`stderr` in den geänderten Funktionen; `client_id` und `aud` erscheinen nie in Fehlertexten oder Logzeilen.
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; keine neuen Pakete.
- **Unberührt:** `main.ts`, `mcp.ts`, `apple-client.ts`, `apple-jwks.ts`, `.github/`, `project.yml`, jede Swift-Datei.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `AppleConfig.clientIds`, `verifyIdentityToken` | bestehend (`apple.ts`), nur um `aud` erweitert |
| Tabelle `apple_tokens` (Migration 002) | bestehend, additive Spalte |
| `pg`, `node:crypto` | bestehend, **keine neuen Pakete** |
| Downstream | S3b (Anmelden: `aud` → `redeemCode`, `storeRefreshToken`), S3c (Löschen: `deleteAccount` → `decryptToken` → `revokeToken(token, clientId)`), #621 |

## Acceptance Criteria

Alle Tests laufen mit `node:test` und `node:assert/strict`; die Datenbanktests gegen das Wegwerf-Postgres aus `server/test/db.ts`, die Prüftests von `apple.ts` im Prozess ohne Netz und Datenbank. Fehlerfälle tabellengetrieben, ein Fall je Zeile.

- **AC-1:** `aud` im Erfolg: Bei gültigem Identity-Token, dessen `aud` die erste, und bei einem, dessen `aud` die zweite der beiden konfigurierten Client-IDs ist, ergibt `verifyIdentityToken` genau `{ ok: true, sub, aud }` mit der jeweils richtigen Client-ID (nicht immer der ersten). Test: „verify: aud im erfolg“ in `apple.test.ts`, dazu die angepassten Erfolgszeilen in `apple.test.ts` und der bestehende Zusammenspiel-Test in `apple-jwks.test.ts` (Zeile 217, nur um `aud` ergänzt, kein neuer Test).
- **AC-2:** Fehlerformen unverändert: Jeder bisherige Fehlerfall von `verifyIdentityToken` ergibt weiterhin ein Objekt, dessen `Object.keys` genau `["ok", "reason"]` sind (kein `aud`, kein `sub`), mit unveränderten Gründen. Test: „verify: fehlerformen“ (bestehende Fehlerfälle unverändert, dazu eine Schleife über deren Ergebnisse mit `Object.keys`).
- **AC-3:** Migration 003 läuft einmal und additiv: Auf einer bis 002 migrierten Datenbank mit einer abgelegten Token-Zeile (aus 002-Zeit, ohne Spalte) wendet `migrate` mit dem echten Ordner genau `003_apple_client_id.sql` an; die Zeile bleibt mit unverändertem `refresh_token_enc` und `created_at` erhalten, `client_id` ist `NULL`; ein zweiter Lauf wendet nichts an. Die Spalte hat den Typ `text` und ist nullable. Test: „migration 003: additiv auf bestandsdaten“ in `server/test/schema.test.ts` (legt die Datenbank mit 001 und 002 aus einem temporären Ordner an, kopiert 003 aus dem echten Ordner dazu); dazu die angepassten Listen in `schema.test.ts` und `accounts.test.ts`.
- **AC-4:** Upsert ersetzt `client_id`: `storeRefreshToken(pool, id, blob, clientId)` legt Blob und `client_id` ab und liefert `true`; ein zweiter Aufruf mit anderem Blob und anderer `client_id` ersetzt beide und setzt `created_at` neu; es bleibt eine Zeile je Konto. Ein unbekanntes Konto ergibt weiterhin `false` und legt nichts ab. Test: „vault: client_id wird abgelegt und ersetzt“.
- **AC-5:** Fehlbedienung wirft: `storeRefreshToken` mit `clientId` = `""`, `undefined`, `null`, einer Zahl, einem Objekt und einem Array wirft, **ohne dass die Datenbank berührt wird** (kein Zeilenzuwachs, kein Aufruf auf einem toten Pool nötig), und kein Fehlertext enthält den übergebenen Wert (Testwert `GEHEIM-CLIENT` als Text im Objekt/Array). Test: „vault fehlbedienung: client_id“ (Fallliste).
- **AC-6:** Rundweg und Grenzfälle: Nach `storeRefreshToken(pool, id, blob, clientId)` liefert `deleteAccount(pool, id)` genau `{ deleted: true, appleToken: blob, clientId }`; ein Konto ohne Token ergibt `{ deleted: true, appleToken: null, clientId: null }`; ein unbekanntes Konto `{ deleted: false, appleToken: null, clientId: null }`; ein Konto mit einer Zeile aus 002-Zeit (`client_id` NULL) ergibt `{ deleted: true, appleToken: blob, clientId: null }`. Die Löschung bleibt vollständig (die bestehenden Zählungen aller Tabellen auf 0 bleiben grün). Test: „delete: rundweg mit client_id“ (Fallliste), dazu die angepassten bestehenden `deepEqual`-Zeilen.
- **AC-7:** Regression und Funktionslänge: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, `server.yml` ist auf dem PR grün, **kein bestehender Testfall wird gelöscht**, und geändert werden nur die in „Bestehende Tests, die mitgehen müssen“ genannten Zeilen; jede Funktion in `server/src/apple.ts`, `apple-vault.ts` und `accounts.ts` hat höchstens 50 Zeilen. Test: `./server/scripts/test-local.sh`, dazu `git diff origin/main -- server/test` (nur die genannten Zeilen verändert, sonst Ergänzungen) und `grep -nE "function" ` je Datei (Abstand zweier Funktionsanfänge und Dateiende ≤ 50).
- **AC-8:** Dateigrenze und Doku: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/apple.ts`, `server/migrations/003_apple_client_id.sql`, `server/src/apple-vault.ts`, `server/src/accounts.ts`, `server/test/apple.test.ts`, `server/test/apple-jwks.test.ts`, `server/test/apple-vault.test.ts`, `server/test/accounts.test.ts`, `server/test/schema.test.ts` und `CLAUDE.md` (Test: dieser Befehl, in der Validierung ausgeführt); die Zeilen zu `src/accounts.ts`, `src/apple.ts` und `src/apple-vault.ts` im Abschnitt `server/` von `CLAUDE.md` nennen `aud`, `client_id` und Migration 003; `main.ts`, `mcp.ts`, `apple-client.ts`, `apple-jwks.ts`, `.github/`, `project.yml` und jede Swift-Datei bleiben unberührt. Zusätzlich bestätigt `grep -rn "client_id\|clientId" server/src/apple.ts server/src/apple-vault.ts server/src/accounts.ts`, dass kein Treffer in einem `throw`-Text oder `console`-Aufruf steht.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apple.ts` | MODIFY | `Verdict` und Rückgabe um `aud`, ≈ +2 |
| `server/migrations/003_apple_client_id.sql` | CREATE | additive Spalte mit Kommentar, ≈ +4 |
| `server/src/apple-vault.ts` | MODIFY | viertes Argument, Prüfung, Upsert mit `client_id`, ≈ +6 |
| `server/src/accounts.ts` | MODIFY | `Deletion` und Abfrage um `client_id`, ≈ +4 (und 2 geändert) |
| `server/test/apple.test.ts` | MODIFY | `aud`-Test, Fehlerformen-Test, 6 Zeilen angepasst, ≈ +25 |
| `server/test/apple-jwks.test.ts` | MODIFY | 1 Zeile angepasst |
| `server/test/apple-vault.test.ts` | MODIFY | neue Tests AC-4/AC-5, bestehende Aufrufe um das vierte Argument, ≈ +35 |
| `server/test/accounts.test.ts` | MODIFY | Rundweg-Test AC-6, 3 `deepEqual` und 1 Migrationsliste angepasst, ≈ +25 |
| `server/test/schema.test.ts` | MODIFY | Migrationsliste und Anzahl angepasst, 2 Zeilen; Migrationstest AC-3 ≈ +15 (in dieser Datei) |
| `CLAUDE.md` | MODIFY | drei Zeilen im Abschnitt `server/` ergänzt, ≈ +3 |

### Estimated Changes

- **Files: 10 (alle geändert, eine neu).** Das liegt **über der Richtgröße von 4 bis 5 Dateien**. Ehrlich aufgeschlüsselt: 4 Quelldateien (`apple.ts`, die SQL-Datei, `apple-vault.ts`, `accounts.ts`), 5 Testdateien und `CLAUDE.md`. Fünf der zehn Dateien sind Testdateien, in denen bestehende Zeilen nur mechanisch mitgehen (zusätzliches Feld in einem erwarteten Objekt, zusätzliches Argument, zusätzlicher Eintrag in der Migrationsliste), ohne Verhaltensänderung eines Testfalls; die Änderung am Vertrag (`aud`, `client_id`) trifft sie zwangsläufig. Ein weiterer Zuschnitt (z. B. `aud` getrennt von `client_id`) würde nur die Testdateien auf zwei Schnitte verteilen und denselben Pfad doppelt durchlaufen; deshalb bleibt es ein Schnitt. Die Entscheidung über diesen Überhang trifft der PO mit der Freigabe.
- LoC: ≈ 120 gesamt, gezählt wie in 2c-2 (Code, Tests, Doku): Code ≈ 16 (+2 geändert), Tests ≈ 100 (neue Tests plus mechanische Anpassungen bestehender Zeilen, rund 14 Zeilen), Doku ≈ 3. Die Schätzung der Analyse (≈ 35 Code) war hoch angesetzt; gemessen an der Skizze der Änderungen reichen ≈ 16. Limit ±250, deutlich darunter.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, kein `generate`. Eine Migration (additiv). Seiteneffekt außerhalb des Tickets: keiner; die geänderten Signaturen haben außer den Tests keinen Aufrufer.

## Risiken

- **Migration auf Produktionsdaten:** `ADD COLUMN` ohne Vorgabewert ist in Postgres ohne Tabellenneuschreibung und unter kurzer Sperre; `apple_tokens` hat in Produktion keine Zeilen. Gegenmaßnahme: Test auf Bestandsdaten (AC-3), nur additiv (Produktion ist ab dem ersten Deploy additiv).
- **Zeilen ohne `client_id`:** Widerruf nicht möglich, S3c loggt und löscht trotzdem. Heute theoretisch (keine solchen Zeilen); in AC-6 belegt, dass `deleteAccount` sie korrekt als `null` meldet.
- **Falsche `aud` abgelegt:** Wenn S3b eine andere als die geprüfte `aud` ablegt, lehnt Apple beim Widerruf ab. Darum liefert die Prüfung selbst die `aud` aus der Liste (AC-1, beide Client-IDs).
- **Signaturänderung bricht Aufrufer:** `storeRefreshToken` und `Deletion` haben keinen Aufrufer außer den Tests; typecheck in `test-local.sh` fängt jeden übersehenen Aufruf (AC-7).
- **Geheimnisse in Fehlern:** `client_id` ist kein Geheimnis, kommt aber nie in Meldungen (AC-5, AC-8).
- **Erwartete Testzeilen übersehen:** Der Fund in `apple-jwks.test.ts` und den Migrationslisten zeigt, dass die Analyse nicht alle Stellen kannte; die Liste oben stammt aus `grep` über `server/test` und `server/src` (2026-11-04) und wird in der Validierung wiederholt (AC-8).

## Test Plan

### Automated Tests (TDD RED)

RED: Zuerst die neuen und angepassten Tests; sie schlagen fehl, weil `aud`, die Spalte, das vierte Argument und `clientId` fehlen. Die nicht angepassten bestehenden Tests laufen weiter.

- [ ] Test 1 (AC-1, AC-2): GIVEN Identity-Tokens für beide Client-IDs und die bestehenden Fehlerfälle WHEN `verifyIdentityToken` läuft THEN `{ ok: true, sub, aud }` mit richtiger `aud`, bzw. Fehler mit genau `ok` und `reason`.
- [ ] Test 2 (AC-3): GIVEN eine bis 002 migrierte Datenbank mit einer Token-Zeile WHEN `migrate` mit 003 läuft THEN Zeile erhalten, `client_id` NULL, zweiter Lauf leer.
- [ ] Test 3 (AC-4, AC-5): GIVEN ein Konto WHEN `storeRefreshToken` zweimal mit anderen Werten und mit Fehlbedienungen aufgerufen wird THEN Ersatz bzw. Wurf ohne Wert im Text und ohne Datenbankzugriff.
- [ ] Test 4 (AC-6): GIVEN Konten mit und ohne Token, mit alter Zeile und unbekannt WHEN `deleteAccount` läuft THEN die vier erwarteten `Deletion`-Werte und leere Tabellen.
- [ ] Test 5 (AC-7, AC-8): GIVEN der fertige Zweig WHEN `./server/scripts/test-local.sh`, `server.yml` und `git diff --name-only origin/main -- . ':!docs' ':!.claude'` THEN grün, grün, genau die zehn Dateien.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): Spalte `apple_tokens.client_id` und `Verdict.aud`.** Die Anmeldung liefert die Wahrheit; der Widerruf nutzt exakt dieselbe Kennung. Kleine additive Migration.
- **B: keine Spalte, beim Widerruf `clientIds[0]` nehmen.** Spart rund 15 Zeilen und die Migration, ist aber bei einem zweiten konfigurierten Client still falsch (Apple lehnt ab, der Widerruf geht verloren). Kippt keine ADR; verworfen, weil die Spalte billig ist.
- **C: `aud` neu aus dem Identity-Token lesen statt `Verdict` zu erweitern.** Zweite Stelle, die das Token zerlegt, ohne die Prüfung; verworfen.
- **D: `client_id` in den verschlüsselten Blob packen.** Ändert das Blobformat (Version, Tresor-Tests), schwerer zu lesen und nicht abfragbar; verworfen.
- Befunde gegen den Plan: keine blockierenden; Umfang gegenüber der Analyse um `apple-jwks.test.ts` und zwei Migrationslisten erweitert (siehe „Bestehende Tests“).

## Nicht in diesem Schnitt / Folgeschnitte

- S3b: `auth.ts` mit `POST /auth/apple` und `/auth/logout`, Bearer-Auslesen, Test über `extraRoutes`.
- S3c: `POST /auth/delete`, Start-Konfiguration und JWKS in `main()`, Body-Grenze und Rand-Härtung.
- S4 App (nach #625). Schlüsselrotation des Tresors.

### Für S3b/S3c festgehalten (nicht in diesem Schnitt)

- **Anmelden (S3b):** verify (liefert `sub` und `aud`) → `redeemCode(code, aud, …)` → `sub`-Vergleich (`redeemCode.sub !== verdict.sub` heißt 401, nichts abgelegt) → `findOrCreate` → verschlüsseln und mit `aud` ablegen → `createSession` **zuletzt**, damit kein Fehler in der Mitte eine Sitzung hinterlässt.
- **Löschen (S3c):** Sitzung auflösen → `deleteAccount` → erst danach `decryptToken` und `revokeToken(token, clientId, …)`; der Widerruf blockiert das Löschen nie (`ok: false`, `null` oder `clientId: null` ergibt eine Logzeile ohne Token und Kennungen, Antwort bleibt 204).
- **Sitzungsablauf:** nicht in S3; Merkposten an #621, weil `resolveSession` der gemeinsame Kern mit dem `/mcp`-Token ist.
- **Drosselung:** als `limit_req` im nginx-Host (Infra), nicht im Prozess.

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulator nötig. Nachweis: `./server/scripts/test-local.sh` grün und der CI-Job `server.yml` auf dem PR grün.
- Stufe 3 entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt `aud`, `client_id` und Migration 003
- [ ] #615 kommentiert (Stand Schnitt 3a, Folge S3b), Board-Karte aktuell, Merkposten Sitzungsablauf an #621

## Changelog

- 2026-11-04: Initial spec created (Schnitt 3a)
