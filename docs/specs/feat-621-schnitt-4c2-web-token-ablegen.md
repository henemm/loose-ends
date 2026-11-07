---
entity_id: feat-621-schnitt-4c2-web-token-ablegen
type: feature
created: 2026-11-07
updated: 2026-11-07
status: draft
workflow: feat-621-s4c2-web-token
---

# Spec: Der Rückweg legt das Web-Token ab (Schnitt 4c-2, #621, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#621 (Epic #612). Schnitt 4c-2; das Issue bleibt offen (`Refs #621`, nie `Closes #621`, Größe L, mehrere Schnitte).
Analyse: `docs/context/feat-621-s4c2-web-token.md` und, für Recherche und Wegevergleich, `docs/context/feat-621-s4c-web-token.md`. Vorgänger: `docs/specs/feat-621-schnitt-4c1-ablage-je-client.md` (PR #863: Tabelle je Konto und Client, Löschen mit Liste, Widerruf je Zeile mit eigener Kennung), `docs/specs/feat-621-schnitt-4b2a-rueckweg.md` (der Rückweg; dort **AC-14** „Web-Token wird weder gespeichert noch widerrufen“ und Alternative F, Verzicht auf die Ablage). **Dieser Schnitt hebt AC-14 aus 4b-2a auf:** der zugehörige Test wird umgedreht. Folge: S5 (Zustimmung), S6 (Betrieb).

## Für den PO

Wenn Claude sich im Browser mit Loose Ends verbindet, meldet sich der Nutzer über Apple an, und Apple gibt dem Dienst dafür eine Berechtigung. Bisher wirft der Dienst diese Berechtigung nach der Anmeldung weg. Das war mit Absicht so, solange er nicht mehrere Berechtigungen je Konto merken konnte. Seit dem letzten Schnitt (4c-1) kann er das, und beim Löschen eines Kontos gibt er jede Berechtigung bei Apple zurück. Dieser Schnitt schließt die Lücke: Der Dienst **merkt sich die Browser-Berechtigung verschlüsselt**, sodass sie beim Löschen des Kontos ebenfalls bei Apple zurückgegeben wird. Ohne ihn bliebe nach jeder Kontolöschung eine Berechtigung bei Apple liegen.

Für dich ändert sich **nichts Sichtbares**: Der Dienst ist von außen noch nicht erreichbar (erst mit S6), die App und deine Daten sind nicht berührt, es gibt keine Datenbankänderung. **Du musst nichts entscheiden.** Der Schnitt ist klein (drei Dateien, rund 125 Zeilen) und liegt innerhalb der üblichen Grenzen.

## Purpose

`outcome()` in `server/src/oauth-return.ts` löst Apples `code` ein (`redeemCode` mit der Services ID), prüft das `id_token` (`verifyIdentityToken`, Zielgruppe nur `webClientId`, Nonce) und legt das Konto an oder findet es (`findOrCreate`). Das Refresh-Token aus der Einlösung wird dabei verworfen (Zeile 90, Kommentar „neither stored nor revoked“). Seit 4c-1 trägt `apple_tokens` den Schlüssel `(account_id, client_id)`, `storeRefreshToken` ist ein Upsert je Paar, und `/auth/delete` widerruft jede Zeile mit ihrer eigenen `client_id` (App-IDs und Web-ID zugelassen). Es fehlt nur das Ablegen im Rückweg.

Änderung (Weg A der Analyse), eine Stelle in `outcome()`, nach `findOrCreate`, im Muster von `signIn` in `auth.ts` (Prüfungen, Konto, Token, Ergebnis):

1. `encryptToken(config.tokenKey, accountId, redeemed.refreshToken)`: AES-256-GCM, das Konto als AAD.
2. `storeRefreshToken(deps.pool, accountId, blob, webClientId)`: Upsert der Zeile `(accountId, webClientId)`.
3. `true`: Ergebnis wie heute, Ticket `{ uid, accountId }`.
4. `false` (Konto während der Anmeldung gelöscht, 23503): Ticket `{ uid, error: "access_denied" }`, **nie** ein Ticket mit Konto-ID. Die Anmeldung scheitert wie bei `/auth/apple` (dort 401).
5. Wurf (Datenbankfehler beim Ablegen): unverändert wie jeder Wurf in `outcome()`, `finishReturn` fängt ihn, protokolliert `oauth return store failed` und antwortet mit der festen 400 `bad request`; kein Ticket, keine Weiterleitung.

Der Kommentar in Zeile 90 entfällt, der Import aus `apple-vault.ts` kommt hinzu. Es gibt **keine neuen Protokollereignisse**; das Token steht nie im Klartext in Tabelle, Antwort oder Protokoll.

**Regeln vor Modell:** Datenbank-, Protokoll- und Sicherheitsablauf ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Festlegungen:

- **Erst ablegen, wenn alle Prüfungen bestanden sind.** Abgelehnte Einlösung, Apples `error` und abgelehnte `id_token`-Prüfung erreichen die Ablage nie; für sie entsteht keine Zeile in `apple_tokens` (und kein Konto).
- **Der `sub` des Kontos kommt aus `verifyIdentityToken` auf genau dem `id_token`, das `redeemCode` zurückgab.** Ein eigener Abgleich `redeemed.sub === verdict.sub` wie in `signIn` ist deshalb nicht nötig: beides stammt aus demselben Token.
- **App-Zeile bleibt unberührt.** Das Paar `(Konto, webClientId)` ist ein anderer Schlüssel als `(Konto, App-ID)`; die App-Zeile desselben Kontos ändert sich nicht (Upsert je Paar seit 4c-1).
- **Eine Zeile je Konto und Web-ID.** Eine zweite Browser-Anmeldung desselben Kontos ersetzt Blob und `created_at` der Web-Zeile; es entsteht keine zweite.
- **Ende-zu-Ende ist mit dem vorhandenen Aufbau machbar.** Der Aufbau in `oauth-return.test.ts` (`service` mit `auth: { config: withWeb, fetch }`) hängt neben dem Rückweg auch die Routen von `/auth/*` an (`start` in `main.ts` mountet beide aus derselben Konfiguration und demselben Fake-`fetch`). Ein Test kann also den Rückweg durchlaufen, eine Sitzung mit `createSession` anlegen, `POST /auth/delete` aufrufen und den Widerruf im Fake-Apple lesen. Dafür merkt sich der Fake das Formular jedes Widerrufs (drei Zeilen). Der Test gehört in `oauth-return.test.ts`, nicht in `auth.test.ts`: dort gibt es keinen Rückweg, und beide Aufbauten zu kombinieren wäre aufwendiger. `auth.test.ts` bleibt unberührt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt den in 4b-2a vertagten und in 4c-1 vorbereiteten Plan (Ablage je Client) um; kein neues Verfahren, keine neue Abhängigkeit, ADR-21 bleibt unberührt.

**Rationale:** Die Ablage im Rückweg ist der letzte Baustein dafür, dass nach der Kontolöschung keine Berechtigung bei Apple liegen bleibt. Sie benutzt ausschließlich vorhandene, getestete Bausteine (`encryptToken`, `storeRefreshToken`, `/auth/delete`) und ist mit Testdatenbank und Fake-Apple vollständig belegbar.

## Source

**Files:** `server/src/oauth-return.ts` (ändern), `server/test/oauth-return.test.ts` (ändern), `CLAUDE.md` (ändern).
**Identifier:** `outcome`, `finishReturn`, `encryptToken`, `storeRefreshToken`, `findOrCreate`, `redeemCode`, `verifyIdentityToken`, `AppleConfig` (`tokenKey`, `webClientId`), `apple_tokens`, `deleteAccount`, `revokeAfterDelete`

### Schnittstelle

- **`oauth-return.ts`**: Import `{ encryptToken, storeRefreshToken } from "./apple-vault.ts"`. In `outcome()` ersetzt der Block nach der Prüfung des `id_token`:

  ```ts
  const accountId = await findOrCreate(deps.pool, verdict.sub);
  const blob = encryptToken(config.tokenKey, accountId, redeemed.refreshToken);
  // false: the account was deleted meanwhile; no ticket that names it.
  if (!(await storeRefreshToken(deps.pool, accountId, blob, webClientId))) return { uid, error: "access_denied" };
  return { uid, accountId };
  ```

  Der Kommentar „The web refresh token is dropped …“ entfällt. Der Kommentar über `outcome` nennt zusätzlich: ein Konto, das während der Anmeldung verschwindet, ergibt `access_denied`. `outcome` bleibt unter 50 Zeilen. Signaturen, Typen (`Ticket`, `AppleReturnDeps`) und alle Pfade in `finishReturn` und `appleReturn` bleiben.
- **Test-Fake** (`fakeApple` in `oauth-return.test.ts`): zusätzliches Feld `revokeForms: URLSearchParams[]`; der Widerruf-Zweig (`REVOKE_URL`) hängt `new URLSearchParams(String(init?.body))` an und zählt weiter `revokes`.
- **Unverändert:** `apple-vault.ts`, `accounts.ts`, `auth.ts`, `apple-client.ts`, `apple.ts`, `main.ts`, `oauth-interaction.ts`, alle Migrationen, `server/package.json`.

### Festlegungen

- **Kein Wert in Protokoll, Antwort oder Ablage:** weder Refresh-Token noch Konto-ID, `client_id`, `sub` oder Fehlertext; Protokoll nur `oauth return refused` und `oauth return store failed`. Das `detail` eines 23503-Fehlers nennt die Konto-ID; `storeRefreshToken` fängt es und gibt `false`.
- **Alles Bestehende bleibt grün,** außer dem unten ausdrücklich umgedrehten Test.
- **Stil:** Kommentare knapp auf Englisch; Tests `node:test` + `node:assert/strict`, eingereichtes `fetch`, kein Netz, Wegwerf-Schema je Test. Kein Test benutzt `git diff origin/main`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `redeemCode` (liefert `refreshToken`, `idToken` im Web-Fluss) | bestehend, ungeändert |
| `verifyIdentityToken`, `findOrCreate` | bestehend, ungeändert |
| `encryptToken`, `storeRefreshToken` (Upsert je `(account_id, client_id)`, `false` bei 23503, leere ID wirft) | bestehend (4c-1), ungeändert |
| `/auth/delete` → `deleteAccount` (Liste je Client) → `revokeAfterDelete` (Web-ID zugelassen) | bestehend (4c-1), ungeändert |
| Tests: `service`, `withApple`, `through`, `ticketOf`, `ticketRow`, `denied`, `countOf`, `fakeApple`, `assertQuiet`, `note` (`oauth-return.test.ts`); `createSession`, `deleteAccount`, `findOrCreate` (`accounts.ts`); `decryptToken`, `storeRefreshToken` (`apple-vault.ts`) | bestehend |
| Downstream | S5 (Zustimmung), S6 (Betrieb); `finish` (4b-2b) liest nur das Ticket, unberührt |

## Acceptance Criteria

Wenn nicht anders genannt, läuft jeder Test in `server/test/oauth-return.test.ts` gegen ein Wegwerf-Schema mit allen Migrationen und `withApple` (Konfiguration `withWeb`, Fake-Apple); Hinweg und Rückweg laufen über `through`.

- **AC-1:** Erfolg legt das Web-Token verschlüsselt ab: GIVEN ein gültiger Hinweg und ein gültiger Rückweg WHEN `POST /oauth/apple/return` läuft THEN antwortet er 303 mit Ticket `{ uid, accountId }`, es gibt genau eine Zeile in `apple_tokens`, ihre `account_id` ist die des Tickets und des angelegten Kontos, ihre `client_id` ist `webClientId`, ihr Blob entschlüsselt sich mit `decryptToken(withWeb.tokenKey, accountId, blob)` zum Token aus Apples Antwort, und der Klartext steht in keinem Byte der Zeile (Blob ohne die Zeichenfolge), in keiner Zeile von `oauth_records`, in keiner Antwort (Körper und Kopfzeilen) und in keiner Protokollzeile (`assertQuiet`); Apple sah keinen Widerruf (`revokes` ist 0). Dies **kehrt AC-14 aus 4b-2a um**. Test: server/test/oauth-return.test.ts „rueckweg: web-token wird verschluesselt mit webClientId abgelegt“ (ersetzt „rueckweg: web-token wird nicht gespeichert und nicht widerrufen“).
- **AC-2:** Abgelehnte Wege legen nichts ab: GIVEN ein Rückweg mit (a) Apples `error`, (b) abgelehnter Einlösung (`invalid_grant`, `invalid_client`, 500, Antwort ohne `refresh_token`), (c) abgelehnter `id_token`-Prüfung (falsche Nonce, fremde Zielgruppe, fremder Schlüssel, abgelaufen, anderer Algorithmus, ohne `sub`, anderer Aussteller), (d) Apple nicht erreichbar (Netzfehler, Zeitüberschreitung, Schlüsselsatz nicht abrufbar) WHEN der Rückweg läuft THEN gilt für jeden Fall wie bisher Ticket mit `access_denied` bzw. `temporarily_unavailable` ohne Konto, und zusätzlich gibt es in `apple_tokens` keine Zeile. Test: server/test/oauth-return.test.ts „rueckweg: apple-fehler ergibt ticket access_denied“, „rueckweg: abgelehnte einloesung ergibt access_denied“, „rueckweg: ungueltiges identity-token ergibt access_denied“, „rueckweg: apple nicht erreichbar ergibt temporarily_unavailable“ (bestehend, je um die Prüfung `apple_tokens` ist leer ergänzt; der Test zum ungültigen Token prüft das bereits).
- **AC-3:** Die App-Zeile desselben Kontos bleibt unverändert: GIVEN ein Konto zum `sub` des Fakes mit einer App-Zeile (`storeRefreshToken` mit der App-ID und eigenem Blob, `created_at` eine Stunde zurückgesetzt) WHEN der Rückweg für dasselbe Konto läuft THEN gibt es zwei Zeilen in `apple_tokens`, die App-Zeile ist byte-gleich unberührt (Blob, `created_at`, `client_id`), die Web-Zeile trägt `webClientId` und das Web-Token, das Ticket nennt dasselbe Konto, und es wurde kein zweites Konto angelegt. Test: server/test/oauth-return.test.ts „rueckweg: app-zeile desselben kontos bleibt neben der web-zeile“.
- **AC-4:** Eine zweite Browser-Anmeldung ersetzt die Web-Zeile: GIVEN zwei Rückwege nacheinander für denselben `sub`, der zweite mit einem anderen Refresh-Token von Apple, und die Zeit der ersten Zeile eine Stunde zurückgesetzt WHEN beide durchlaufen sind THEN gibt es weiter genau eine Zeile mit `client_id = webClientId`, ihr Blob entschlüsselt sich zum zweiten Token, `created_at` ist vorgerückt, und es gibt genau ein Konto. Test: server/test/oauth-return.test.ts „rueckweg: zweite anmeldung ersetzt die web-zeile“.
- **AC-5:** Konto zwischendurch gelöscht ergibt `access_denied` ohne Konto-ID: GIVEN ein Rückweg, bei dem das Konto unmittelbar vor dem Ablegen des Tokens gelöscht wird (ein vorgeschalteter Pool löscht das Konto per `deleteAccount`, sobald der `INSERT INTO apple_tokens` kommt, Muster des bestehenden Tests zum gelöschten Konto) WHEN der Rückweg läuft THEN antwortet er 303 auf `finish` mit Ticket, die Ablage des Tickets ist `{ uid, error: "access_denied" }` mit `account_id` NULL, die Ablage enthält die Konto-ID nirgends, es gibt keine Zeile in `apple_tokens` und kein Konto, das Protokoll ist leer, und kein Wert aus Token oder Konto steht in der Antwort. Test: server/test/oauth-return.test.ts „rueckweg: konto beim ablegen geloescht ergibt access_denied ohne konto-id“.
- **AC-6:** Datenbankfehler beim Ablegen ergibt die feste 400: GIVEN ein Rückweg, bei dem der `INSERT INTO apple_tokens` mit einem Datenbankfehler scheitert (vorgeschalteter Pool wirft nur für diese Anweisung; der Fehlertext enthält Konto-ID und ein erkennbares Wort) WHEN der Rückweg läuft THEN antwortet er 400 `bad request` (`assertFixed`: `no-store`, keine Weiterleitung), es gibt kein Ticket in `oauth_records`, keine Zeile in `apple_tokens`, das Protokoll ist genau `["oauth return store failed"]`, weder Fehlertext, Konto-ID noch Token stehen in Antwort oder Protokoll, und der `state` ist verbraucht (ein Wiederholen desselben `state` ergibt die feste 400 `oauth return refused`). Test: server/test/oauth-return.test.ts „rueckweg: datenbankfehler beim ablegen ergibt feste 400 ohne ticket“.
- **AC-7:** Ende-zu-Ende, das Löschen widerruft das Web-Token mit der Web-ID: GIVEN ein Rückweg, der die Web-Zeile abgelegt hat, und eine Sitzung für das Konto (`createSession`), Apple antwortet auf den Widerruf mit 200 WHEN `POST /auth/delete` mit dieser Sitzung läuft THEN antwortet es 204 mit leerem Körper, das Konto und alle seine Zeilen (`apple_tokens`, `oauth_records` des Kontos) sind weg, es gibt genau einen Widerruf am Fake, dessen Formular `token` = das Token aus der Einlösung und `client_id` = `webClientId` trägt (nicht die App-ID), und das Protokoll des Dienstes enthält weder Token noch Web-ID. Test: server/test/oauth-return.test.ts „rueckweg: loeschen widerruft das abgelegte web-token mit der web-id“. **Entscheidung zum optionalen Test:** aufgenommen, weil der Aufbau beide Routen schon trägt; er braucht den Fake-Zusatz `revokeForms` (drei Zeilen) und rund 25 Zeilen Test, bleibt also im Rahmen.
- **AC-8:** Gesamtlauf und Rest unverändert: GIVEN der fertige Schnitt WHEN `./server/scripts/test-local.sh` (typecheck + alle Tests) läuft THEN ist er grün und räumt auf; alle übrigen Tests in `oauth-return.test.ts` (Ticket gehasht, Replay, `state`, Übergröße, Methode und Typ, Felder, `user`, geschlossenes Konto, Protokoll, Fehlerfenster, JWKS-Instanz) sowie `oauth-interaction.test.ts`, `oauth-provider.test.ts`, `main.test.ts`, `auth.test.ts`, `apple-vault.test.ts`, `accounts.test.ts` laufen unverändert grün; es gibt keinen neuen Eintrag in `server/package.json` und keine neue Migration. Dateiliste (drei Dateien) und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Test: Gesamtlauf `./server/scripts/test-local.sh` und CI `server.yml`; Dateiliste in `/60-validate`.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/oauth-return.ts` | MODIFY | `outcome()`: verschlüsseln und mit `webClientId` ablegen, `false` ergibt `access_denied`; Import; Kommentar Z. 90 entfällt, ≈ +7/−2 |
| `server/test/oauth-return.test.ts` | MODIFY | AC-14-Test umgedreht (AC-1), vier Tests je um eine Prüfung ergänzt (AC-2), neue Tests AC-3 bis AC-7, Fake-Zusatz `revokeForms`, ≈ +100/−10 |
| `CLAUDE.md` | MODIFY | `server/`-Abschnitt: zwei Sätze ersetzt (siehe unten), ≈ +2/−2 |

### Estimated Changes

- **Files: 3** (Code: 1, Tests: 1, Doku: 1), innerhalb des Limits von 4 bis 5 Dateien.
- **Code ≈ 9 LoC, Tests ≈ 110 LoC, Doku ≈ 4 LoC, insgesamt ≈ 123 LoC** (Zeilen hinzugefügt, geändert und gelöscht), innerhalb des Limits von ±250 LoC. Die Last liegt in den Tests (Erfahrung: Tests ≈ 2,5× Code, hier mehr, weil jeder Fehlerpfad und der Ende-zu-Ende-Beleg einzeln stehen). **Meldeschwelle beim Bauen:** wächst die Summe über 250 LoC, wird das vor dem Weiterbauen gemeldet.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, kein `generate`, keine neue Abhängigkeit, keine Migration.
- Doku als Teil des Schnitts, `CLAUDE.md`, `server/`-Abschnitt:
  - Im Absatz zu `src/oauth-return.ts` wird der Satz „The web refresh token is neither stored nor revoked (own cut before S6).“ ersetzt durch: der Rückweg legt das Web-Token nach `findOrCreate` verschlüsselt mit `webClientId` ab (`encryptToken`, `storeRefreshToken`, #621 S4c-2); ein während der Anmeldung gelöschtes Konto (`false`) ergibt das Ticket `access_denied` ohne Konto-ID, ein Datenbankfehler die feste 400 `store failed`; `/auth/delete` widerruft die Zeile mit der Web-ID.
  - Im Absatz zu `src/oauth-interaction.ts` wird der Halbsatz „storing the web Apple token comes in its own cut before S6“ ersetzt durch: das Web-Token legt der Rückweg ab (`src/oauth-return.ts`, S4c-2).
- Seiteneffekte nach außen: keine. Der Dienst ist nicht erreichbar (nginx bis S6); in Produktion ist `APPLE_*` nicht gesetzt, der Rückweg läuft dort nicht.
- **Parallele Arbeit:** PR #866 bis #868 (S5) ändern ebenfalls `CLAUDE.md`, #868 hängt Tests ans Ende von `oauth-return.test.ts`. Der Konflikt ist nur textuell (verschiedene Absätze beziehungsweise Dateiende), nicht inhaltlich; beim Zusammenführen sind beide Stände zu behalten. PR #865 (eigene Tabelle `apple_web_tokens`) ist geschlossen und ungemergt.

## Risiken

- **Konto zwischen `findOrCreate` und Ablage gelöscht.** Ohne Behandlung entstünde ein Ticket mit einer Konto-ID, die es nicht mehr gibt (und `finish` meldete sie als Anmeldung). Gegenmittel: `false` ergibt `access_denied`; AC-5.
- **Datenbankfehler beim Ablegen.** Ein Wurf muss in der festen 400 enden, nie in einer Weiterleitung ohne Ticket, nie mit Werten. Gegenmittel: der bestehende `try` in `finishReturn`; AC-6.
- **Token im Klartext.** Das Refresh-Token ist ein Geheimnis mit langer Laufzeit. Gegenmittel: nur `encryptToken` schreibt in die Tabelle, kein neues Protokollereignis, AC-1 sucht den Klartext in Zeile, Ablage, Antwort und Protokoll.
- **Überschreiben des App-Tokens.** Wäre der Schlüssel falsch, ersetzte die Browser-Anmeldung die App-Zeile. Gegenmittel: Schlüssel je Paar seit 4c-1; AC-3.
- **Zusätzliche Last im Rückweg:** ein Verschlüsseln und ein Upsert; vernachlässigbar, kein zusätzlicher Netzaufruf.
- **Widerruf über Client-Grenzen undokumentiert** (Forum 844628): wie in 4c-1 ohne Folge; ein bereits ungültiges Token ergibt bei Apple 200 oder `invalid_grant` und höchstens ein `apple revoke failed` beim Löschen.

## Test Plan

### Automated Tests (TDD RED)

RED: Der umgedrehte Test (AC-1) schlägt fehl, weil keine Zeile entsteht; AC-3, AC-4 und AC-7 schlagen fehl (keine Web-Zeile, kein Widerruf); AC-5 und AC-6 laufen ins Leere (das Ablegen wird nie versucht, der vorgeschaltete Pool sieht keinen `INSERT INTO apple_tokens`, der Test prüft das mit einem Zähler und schlägt fehl). Die um `apple_tokens` ergänzten Fälle (AC-2) sind schon vor dem Bau grün und bleiben es.

| Testname | AC |
|---|---|
| „rueckweg: web-token wird verschluesselt mit webClientId abgelegt“ | AC-1 |
| „rueckweg: apple-fehler ergibt ticket access_denied“, „rueckweg: abgelehnte einloesung ergibt access_denied“, „rueckweg: ungueltiges identity-token ergibt access_denied“, „rueckweg: apple nicht erreichbar ergibt temporarily_unavailable“ (je ergänzt) | AC-2 |
| „rueckweg: app-zeile desselben kontos bleibt neben der web-zeile“ | AC-3 |
| „rueckweg: zweite anmeldung ersetzt die web-zeile“ | AC-4 |
| „rueckweg: konto beim ablegen geloescht ergibt access_denied ohne konto-id“ | AC-5 |
| „rueckweg: datenbankfehler beim ablegen ergibt feste 400 ohne ticket“ | AC-6 |
| „rueckweg: loeschen widerruft das abgelegte web-token mit der web-id“ | AC-7 |
| `./server/scripts/test-local.sh`, `/60-validate` (Dateiliste per `git diff`) | AC-8 |

- [ ] Test 1 (AC-1): GIVEN gültiger Rückweg WHEN POST THEN eine Web-Zeile, entschlüsselbar, Klartext nirgends, kein Widerruf.
- [ ] Test 2 (AC-2): GIVEN Apple-Fehler, abgelehnte Einlösung, ungültiges Token, Ausfall WHEN POST THEN keine Zeile in `apple_tokens`.
- [ ] Test 3 (AC-3, AC-4): GIVEN App-Zeile bzw. früherer Web-Rückweg WHEN Rückweg THEN App-Zeile unberührt bzw. Web-Zeile ersetzt, genau ein Konto.
- [ ] Test 4 (AC-5, AC-6): GIVEN Konto gelöscht bzw. Datenbankfehler beim Ablegen WHEN Rückweg THEN `access_denied` ohne Konto-ID bzw. feste 400, kein Wert im Protokoll.
- [ ] Test 5 (AC-7): GIVEN abgelegte Web-Zeile WHEN `/auth/delete` THEN 204, ein Widerruf mit `client_id = webClientId` und dem Token.
- [ ] Test 6 (AC-8): GIVEN Gesamtlauf WHEN `./server/scripts/test-local.sh` THEN grün, keine neue Abhängigkeit.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): im Rückweg nach `findOrCreate` verschlüsseln und mit `webClientId` ablegen** | `outcome()` im Muster von `signIn` | bestehende, getestete Bausteine; ≈ 9 Zeilen Code; Löschen und Widerruf sind seit 4c-1 fertig; vollständig belegbar mit Testdatenbank und Fake-Apple | ein weiteres Geheimnis in der Datenbank (wie das App-Token, gleich geschützt) | — |
| **B Token sofort bei Apple widerrufen statt ablegen** (Alternative F aus 4b-2a, „Weg 1“) | nach der Prüfung `revokeToken(refreshToken, webClientId)`, nichts speichern | keine Ablage, kein Geheimnis in der Datenbank | Apple löst die Verbindung mit der Services ID sofort wieder; beim Löschen gäbe es nichts zu widerrufen; jede Browser-Anmeldung kostet einen zweiten Apple-Aufruf; die Wirkung auf die App-Berechtigung ist undokumentiert (Forum 844628) | der Plan „Ablage je Client“ aus 4c-1; verworfen |
| **C eigene Tabelle `apple_web_tokens`** (PR #865, geschlossen) | Web-Token neben `apple_tokens` | App-Tabelle bleibt unberührt | doppelt zu 4c-1; Löschen und Widerruf müssten zwei Tabellen lesen; der Aufbau kollidiert mit dem gemergten Schlüssel `(account_id, client_id)` | die Entscheidung von 4c-1, eine Tabelle mit Client im Schlüssel; verworfen |
| **D Ablegen erst in `finish`** (S4b-2b) | das Token reist im Ticket mit, `finish` legt es ab | `finish` kennt die Sitzung des Ausstellers | das Token müsste verschlüsselt in `oauth_records` zwischenliegen (60 s, zweite Fundstelle für ein Geheimnis); `finish` bekäme eine neue Aufgabe und eine neue Fehlerart; mehr Fläche ohne Gewinn | die Trennung „Rückweg prüft und legt ab, `finish` schließt die Interaktion“; verworfen |

Alternative zu A bleibt offen: zeigt eine Messung nach S6, dass Apple den Widerruf je Client sauber trennt und eine Browser-Berechtigung beim Löschen nicht zurückgegeben werden muss, könnte B genügen; kein Ticket nötig, solange A trägt.

## Out of Scope / Folgeschnitte

- **Zustimmungsseite und Erlaubnisliste (S5)** (PR #866 bis #868), **Betrieb (S6)** mit Services ID, nginx, Schlüsseln in Compose und Echtbrowser-Nachweis.
- **F001 und F002 aus 4b-2a** (LOW, Rückweg): nicht in diesem Schnitt.
- Änderungen an `/auth/*`, `apple-vault.ts`, `accounts.ts`, Migrationen: keine, 4c-1 hat sie erledigt.

## Abnahme

Kein Pfad der Geräteliste berührt. (Nur `server/` und `CLAUDE.md`, keine App, kein `project.yml`.) Die Abnahme endet nach den Tests: `./server/scripts/test-local.sh` (typecheck + `node --test` gegen ein Wegwerf-Postgres) grün und die CI `server.yml` auf dem PR grün. Ein Simulator-Durchlauf entfällt, weil es reiner Dienstcode ohne Oberfläche ist und der Dienst von außen nicht erreichbar ist; die Kette Rückweg, Ablage, Löschen, Widerruf wird in AC-7 Ende-zu-Ende mit echter Datenbank, echtem Vault und Fake-Apple durchgespielt. Stufe 3 entfällt.

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] Der Test „rueckweg: web-token wird nicht gespeichert und nicht widerrufen“ ist umgedreht und umbenannt; kein alter Name mit falscher Aussage bleibt
- [ ] `CLAUDE.md` (`server/`-Abschnitt) aktualisiert: beide Sätze zum nicht gespeicherten Web-Token ersetzt
- [ ] #621 kommentiert (Stand Schnitt 4c-2; Folge: S5, S6), Board-Karte aktuell

## Changelog

- 2026-11-07: Initial spec created (Schnitt 4c-2)
- 2026-11-07: **Gekippter bestehender Test:** `server/test/oauth-return.test.ts` „rueckweg: web-token wird nicht gespeichert und nicht widerrufen“ (AC-14 aus 4b-2a, erwartet `apple_tokens` leer und `revokes` 0): **umgedreht und umbenannt** zu „rueckweg: web-token wird verschluesselt mit webClientId abgelegt“ (AC-1). Die vier Tests aus AC-2 behalten Namen und Aussage und werden nur um die Prüfung ergänzt, dass `apple_tokens` leer bleibt.
