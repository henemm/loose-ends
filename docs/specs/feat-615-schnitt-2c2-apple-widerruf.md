---
entity_id: feat-615-schnitt-2c2-apple-widerruf
type: feature
created: 2026-11-03
updated: 2026-11-03
status: draft
workflow: feat-615-s2c2-apple-widerruf
---

# Spec: Apples Refresh-Token widerrufen, Schnitt 2c-2 (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt 2c-2; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s2c2-apple-widerruf.md`, Abschnitt „Analysis“. Vorgänger: Schnitt 2c-1 (`docs/specs/feat-615-schnitt-2c1-apple-einloesen.md`), dessen Abschnitt „Nicht in diesem Schnitt“ diesen Schnitt benennt.

## Für den PO

Löscht jemand sein Konto, verlangt Apple, dass wir den Schlüssel, den wir bei der Anmeldung bekommen haben, an Apple zurückgeben (Apples Vorgabe für „Mit Apple anmelden“, auch Bedingung der App-Review). Dieser Schnitt baut dafür den Baustein im Dienst: eine Funktion, die Apple den Schlüssel zurückgibt und sagt, ob Apple es angenommen hat. In der App ändert sich nichts Sichtbares, und nichts ruft die Funktion auf. Das Verdrahten mit „Konto löschen“ folgt im nächsten Schnitt (S3). Ehrlich benannt: Apple antwortet laut Entwicklerberichten teils auch bei einem ungültigen Schlüssel mit „in Ordnung“; „ok“ heißt hier darum nur „Apple hat nicht abgelehnt“, nicht „Apple hat ihn nachweislich eingezogen“.

## Purpose

`revokeToken(refreshToken, clientId, opts)` in `server/src/apple-client.ts` ruft `POST https://appleid.apple.com/auth/revoke` auf. Es nutzt dasselbe Client-Secret wie `redeemCode` (`clientSecret`) und liefert ein Ergebnis statt zu werfen, damit S3 das Löschen des Kontos nie von Apples Antwort abhängig machen muss. Der Formular-POST mit Zeitlimit wird aus `redeemCode` in eine kleine gemeinsame Funktion gezogen, damit Zeitlimit und Netzfehlerabbildung eine Quelle haben.

Nur Dienstcode ohne Port; `fetch` und `now` werden hereingereicht, im Test Stub. Nichts ruft ihn auf (ADR-21).

**Regeln vor Modell:** reiner Protokollaufruf (Formular, Statuscode, JSON-Fehlername), keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Quellen (Recherche 2026-11-03): Apple, Revoke tokens (`POST /auth/revoke`, Formular `client_id`, `client_secret`, `token`, optional `token_type_hint`); Apple TN3194 (Widerruf bei Kontolöschung ist Pflicht); Entwicklerforum Thread 707545 (Endpunkt liefert teils 200 auch bei ungültigem Token oder Secret). **Annahme, nicht von Apple bestätigt:** das genaue Fehlerformat bei Status ≠ 200; es wird wie beim Einlösen behandelt (JSON mit `error`) und im Test per Stub festgelegt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 und die in S2a/2c-1 festgelegte Reihenfolge (einlösen, verschlüsselt ablegen, beim Löschen widerrufen) um; keine neue Architekturentscheidung, keine neue Abhängigkeit.
- **Rationale:** Neu festgelegt wird nur: Ergebnisunion statt Wurf bei Apples Antwort, `client_id` als Parameter, 200 heißt „nicht abgelehnt“.

## Source

**Files:** `server/src/apple-client.ts`, `server/test/apple-client.test.ts`, `CLAUDE.md`
**Identifier:** `revokeToken`, `Revoked`

### Schnittstelle

- `revokeToken(refreshToken: string, clientId: string, opts: { config: AppleConfig; fetch: typeof fetch; now: () => number; url?: string }): Promise<Revoked>` mit `Revoked = { ok: true } | { ok: false; reason: string }`. `url` nur für Tests; Vorgabe `https://appleid.apple.com/auth/revoke`.
- **Wirft nur bei eigener Fehlbedienung:** leerer oder nicht-textueller `refreshToken`, `clientId` außerhalb von `config.clientIds` (das wirft `clientSecret`), `now()` keine endliche Zahl. Bei Apples Antwort, Netzfehler und Zeitlimit **wirft sie nie**, sondern ergibt `{ ok: false, reason }`. Fehlertexte enthalten weder Token noch `clientId` noch Schlüssel.

### Festlegungen

- **Anfrage:** `fetch(url, { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, body, signal: AbortSignal.timeout(5000) })`; das Formular enthält genau `client_id`, `client_secret` (`clientSecret(config, clientId, now())`), `token`, `token_type_hint=refresh_token`.
- **Status 200:** `{ ok: true }`; der Rumpf wird nicht gelesen und nicht ausgewertet. Bedeutung: Apple hat nicht abgelehnt (siehe Forum 707545).
- **Status ≠ 200:** `apple:<error>`, wenn der JSON-Rumpf ein `error` aus den sechs bekannten Werten wie in `redeemCode` trägt (`invalid_request`, `invalid_client`, `invalid_grant`, `unauthorized_client`, `unsupported_grant_type`, `invalid_scope`), sonst `apple_status`. Apples Text wird nie übernommen. Bricht das Lesen des Rumpfes ab, ist es `unavailable`.
- **`unavailable`:** Netzfehler, Ausnahme von `fetch` (auch synchron), Zeitlimit.
- **Kein `malformed_response`:** bei 200 gibt es nichts zu lesen.
- **Gemeinsamer Teil:** `redeemCode` und `revokeToken` schicken über dieselbe interne Funktion (Formular, Kopf, Zeitlimit, Fang von Netzfehlern); die Fehlerabbildung für Status ≠ 200 ist ebenfalls eine Quelle. Das Verhalten von `redeemCode` ändert sich nicht (die 11 vorhandenen Einlöse-Tests bleiben unverändert und grün).
- **Keine Geheimnisse in Gründen und Fehlertexten:** weder `refreshToken`, `client_secret` noch Rohtext der Antwort.
- **Stille und Länge:** kein `console`, kein `process.stdout`/`stderr`; jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; nur `node:crypto`.

### Für S3 festgehalten (nicht in diesem Schnitt)

- Verdrahtung: `deleteAccount` gibt den verschlüsselten Blob zurück, `decryptToken` macht ihn lesbar (`null` bei jedem Fehler, dann entfällt der Widerruf, Best Effort nach TN3194), `revokeToken` gibt ihn an Apple zurück. Ein `ok: false` darf das Löschen nie blockieren (das Konto ist dann schon gelöscht); ob wiederholt oder protokolliert wird, entscheidet S3.
- Welche `client_id` beim Widerruf gilt: dieselbe wie beim Einlösen (Token ist an sie gebunden). `apple_tokens` speichert sie noch nicht; S3 entscheidet zwischen Spalte `client_id` per additiver Migration 003 und `clientIds[0]` bis #621.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `clientSecret`, `AppleConfig` | bestehend (`apple-client.ts`, `apple.ts`), `apple.ts` unverändert |
| `node:crypto` | Standardbibliothek, **keine neuen Pakete** |
| globales `fetch`, `AbortSignal.timeout` | hereingereicht; im Test Stub |
| Downstream | S3 (`DELETE /account`), #621 |

## Acceptance Criteria

Alle Tests laufen im Prozess, ohne Port, Netz und Datenbank, mit `node:test` und `node:assert/strict`, in `server/test/apple-client.test.ts` nach dem Stub-Muster der Einlöse-Tests (eigenes EC-P-256-Paar, Konfiguration mit zwei Client-IDs, Stub-`fetch` mit Aufrufzähler und austauschbarer Antwort, feste Uhr). Fehlerfälle tabellengetrieben, ein Fall je Zeile.

- **AC-1:** Anfrage genau wie festgelegt: Bei gültigem Aufruf ruft `revokeToken` `fetch` genau einmal auf, mit der Vorgabe-URL `https://appleid.apple.com/auth/revoke` (mit `opts.url` die übergebene), Methode `POST`, Kopf `content-type: application/x-www-form-urlencoded`, einem `AbortSignal` und einem Formular, das geparst genau die Schlüssel `client_id`, `client_secret`, `token`, `token_type_hint` hat; `token_type_hint` ist `refresh_token`, `client_id` und `token` sind die übergebenen Werte, und `client_secret` ist ein gültiges Secret für diese `client_id` zum Zeitpunkt `opts.now()` (Kopf, Nutzlast und Signatur wie in 2c-1 AC-1 mit dem öffentlichen Schlüssel prüfbar). Gilt für beide Client-IDs. Test: „revoke: anfrage“.
- **AC-2:** Erfolg: Status 200 mit beliebigem Rumpf (leer, JSON, kein JSON) ergibt genau `{ ok: true }` ohne weitere Felder. Test: „revoke: erfolg“.
- **AC-3:** Apple-Fehler: Status 400 und 401 mit `{ "error": X }` ergibt `{ ok: false, reason: "apple:X" }` für jeden der sechs bekannten Werte; ein unbekannter `error`-Wert (`GEHEIM-123`, `<script>`, leer, Zahl, Objekt, Liste) ergibt `apple_status`, ebenso Status 500/503/302 mit beliebigem Rumpf und Status 400 ohne JSON. Test: „revoke: apple-fehler und status“ (Fallliste).
- **AC-4:** Netz und Zeitlimit: Eine Ausnahme von `fetch`, ein synchroner Wurf, eine `TimeoutError`-Ausnahme, ein abgelehntes `fetch` und ein Rumpf, dessen Lesen bei Status ≠ 200 abbricht, ergeben `{ ok: false, reason: "unavailable" }` und werfen nie; das übergebene Signal ist ein Zeitlimit von höchstens 5000 ms (ein Stub, der auf das Signal wartet, endet mit `unavailable`). Test: „revoke: unavailable und zeitlimit“ (Fallliste).
- **AC-5:** Fehlbedienung wirft ohne Netz: `revokeToken` mit leerem oder nicht-textuellem `refreshToken`, mit `clientId` außerhalb der Liste (auch nur anders geschrieben) und mit `now()` = `NaN` wirft, **ohne dass `fetch` aufgerufen wird** (Zähler 0); kein Fehlertext enthält `clientId`, das Token (Testwert `GEHEIM-TOKEN`) oder Schlüsselmaterial. Test: „revoke fehlbedienung: wirft ohne netz“ (Fallliste).
- **AC-6:** Keine Geheimnisse und feste Menge: Über alle Fälle aus AC-3 und AC-4 sowie die Wurffälle aus AC-5 (dort gibt es keinen `reason`, nur den Fehlertext) (Testwerte `GEHEIM-TOKEN` für das Token, `GEHEIM-123` im Apple-`error` und im Rumpf) ist jeder `reason` einer von `apple:<einer der sechs>`, `apple_status`, `unavailable`; kein `reason` und kein Fehlertext enthält Token, Secret (weder Ganzes noch Segmente) oder Rohtext der Antwort. Test: „revoke reason: feste menge, keine geheimnisse“.
- **AC-7:** Stille: Während aller Aufrufe aus AC-1 bis AC-5 (Erfolg, `ok: false`, Wurf) wird nichts nach `console` oder `process.stdout`/`process.stderr` geschrieben (der Test ersetzt sie vorübergehend). Test: „revoke: silence“.
- **AC-8:** Regression, CI und Funktionslänge: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, `server.yml` ist auf dem PR grün, **alle bestehenden Tests in `apple-client.test.ts` laufen unverändert grün** (kein bestehender Testfall wird geändert oder gelöscht, nur neue kommen hinzu); jede Funktion in `server/src/apple-client.ts` hat höchstens 50 Zeilen, und die Datei importiert nur `node:crypto` und `./apple.ts`. Test: `./server/scripts/test-local.sh`, dazu `grep -n "^import" server/src/apple-client.ts` (nur `node:crypto` und `./apple.ts`) und `grep -nE "function" server/src/apple-client.ts` (Abstand zweier Funktionsanfänge und Dateiende ≤ 50).
- **AC-9:** Dateigrenze und Doku: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/apple-client.ts`, `server/test/apple-client.test.ts` und `CLAUDE.md` (Test: dieser Befehl, in der Validierung ausgeführt); die Zeile zu `src/apple-client.ts` im Abschnitt `server/` von `CLAUDE.md` nennt zusätzlich `revokeToken` (POST /auth/revoke, `ok` heißt nur „nicht abgelehnt“); `apple.ts`, `apple-jwks.ts`, `apple-vault.ts`, `accounts.ts`, `server/migrations/`, `server/test/db.ts`, `server/package.json`, `server/package-lock.json`, `server/src/main.ts`, `.github/workflows/`, `project.yml` und jede Swift-Datei bleiben unberührt.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apple-client.ts` | MODIFY | `revokeToken`, `Revoked`, gemeinsamer POST und gemeinsame Fehlerabbildung, `redeemCode` darauf umgestellt, ≈ +25 / −8 |
| `server/test/apple-client.test.ts` | MODIFY | AC-1 bis AC-7, nur Ergänzungen, ≈ +65 |
| `CLAUDE.md` | MODIFY | die `apple-client.ts`-Zeile im Abschnitt `server/` ergänzt, ≈ +1 |

### Estimated Changes

- Files: 3 (alle geändert).
- LoC: ≈ 99 gesamt, gezählt wie in 2c-1 (Code, Tests, Doku): Code ≈ 25 (+8 geändert), Tests ≈ 65, Doku ≈ 1. Limit ±250, weit darunter.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, kein `generate`, keine Migration. Seiteneffekt außerhalb des Tickets: keiner; einzig berührter bestehender Code ist `redeemCode`, abgesichert durch seine unveränderten Tests (AC-8).

## Risiken

- **Apple antwortet 200 bei ungültigem Token:** `ok: true` ist schwach belegt. Gegenmaßnahme: offen benannt (PO-Text, CLAUDE.md-Zeile), kein Versprechen „widerrufen“. Wir können es von außen nicht prüfen, auch ein späterer Test gegen Apple würde es nicht ändern.
- **Fehlerformat bei Status ≠ 200 ungesichert:** nicht von Apple dokumentiert, Annahme wie beim Einlösen; weicht es ab, ergibt sich `apple_status`, nie ein falsches `ok`. Der Test legt die Annahme fest.
- **Umstellung von `redeemCode`:** Fehler im gemeinsamen Teil würden das Einlösen brechen. Gegenmaßnahme: dessen 11 Tests bleiben unverändert (AC-8); Fallback ist die Kopie des POST-Teils (Alternative B), falls die Umstellung Tests kippt.
- **Falsche `client_id`:** Apple lehnt mit `invalid_client` ab. Darum Parameter statt Voreinstellung, Wurf außerhalb der Liste (AC-5).
- **Geheimnisse in Fehlern:** Token und Secret nie in Gründen oder Fehlertexten (AC-5, AC-6).
- **Apple antwortet nicht:** Zeitlimit 5 s, `unavailable` statt Hängen (AC-4).

## Test Plan

### Automated Tests (TDD RED)

RED: Zuerst die neuen Tests in `apple-client.test.ts`; `revokeToken` fehlt, sie schlagen fehl, die vorhandenen laufen weiter.

- [ ] Test 1 (AC-1, AC-2): GIVEN ein Stub-`fetch` WHEN `revokeToken` aufgerufen wird THEN Anfrage wie festgelegt und `{ ok: true }` bei 200.
- [ ] Test 2 (AC-3, AC-4): GIVEN die Fallliste der Apple-Fehler, Status und Netzfälle WHEN `revokeToken` aufgerufen wird THEN der erwartete Grund und nie ein Wurf.
- [ ] Test 3 (AC-5, AC-6): GIVEN Fehlbedienungen und Geheimniswerte in Stub-Antworten WHEN `revokeToken` aufgerufen wird THEN Wurf ohne `fetch` bzw. nur feste Gründe ohne Geheimnisse.
- [ ] Test 4 (AC-7): GIVEN `console.*` und `process.stdout/stderr` vorübergehend ersetzt WHEN alle Aufrufe laufen THEN keine Ausgabe.
- [ ] Test 5 (AC-8, AC-9): GIVEN der fertige Zweig WHEN `./server/scripts/test-local.sh`, `server.yml` und `git diff --name-only origin/main -- . ':!docs' ':!.claude'` THEN grün, grün, genau die drei Dateien.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): `revokeToken` in `apple-client.ts`, gemeinsamer POST mit `redeemCode`.** Eine Quelle für Zeitlimit und Fehlerabbildung.
- **B: POST-Teil kopieren, `redeemCode` unangetastet.** Kein Regressionsrisiko, aber zwei Stellen für dieselbe Fehlerabbildung. Fallback.
- **C: gar nicht widerrufen.** Verstößt gegen Apples Vorgabe (TN3194, App-Review 5.1.1(v)) und gefährdet die Freigabe der App; verworfen, kippt keine ADR.
- **D: Widerruf in der App statt im Dienst.** Der Refresh-Token liegt verschlüsselt im Dienst und müsste an die App herausgegeben werden; kippt ADR-21; verworfen.
- Befunde gegen den Plan: keine blockierenden; `client_id`-Ablage und Umgang mit `ok: false` bewusst nach S3 verlegt.

## Nicht in diesem Schnitt / Folgeschnitte

- S3 HTTP-Rand: Routen, `createJwks` einmal beim Start, Konfiguration, Vergleich des `sub`, `client_id`-Ablage, `DELETE /account` mit `deleteAccount` → `decryptToken` → `revokeToken`, Wiederholung/Protokoll. S4 App (nach #625).
- Schlüsselrotation des Tresors.

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulator nötig. Nachweis: `./server/scripts/test-local.sh` grün und der CI-Job `server.yml` auf dem PR grün.
- Stufe 3 entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-9 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt `revokeToken`
- [ ] #615 kommentiert (Stand Schnitt 2c-2, Folge S3), Board-Karte aktuell

## Changelog

- 2026-11-03: Initial spec created (Schnitt 2c-2)
