---
entity_id: feat-621-schnitt-4b2a-rueckweg
type: feature
created: 2026-11-06
updated: 2026-11-06
status: draft
workflow: feat-621-s4b-2-rueckweg
---

# Spec: Anmeldung über Apple im Browser, Rückweg bis zum Ticket (Schnitt 4b-2a, #621, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#621 (Epic #612). Schnitt 4b-2a; das Issue bleibt offen (`Refs #621`, nie `Closes #621`, Größe L, mehrere Schnitte).
Analyse: `docs/context/feat-621-s4b-2-rueckweg.md` (Abschnitte „Recherche“, „Analysis“, „Alternativen“, „Teilung“); Vorgänger: `docs/specs/feat-621-schnitt-4b1-hinweg.md` (Hinweg, Modell `AppleLogin`), S4a (`redeemCode` mit Web-ID, `authorizeUrl`, `appleReturnUrl`), S2 (`PgAdapter`). Folge: S4b-2b (Abschluss `finish`).

## Für den PO

Wenn du Claude im Browser mit Loose Ends verbindest, schickt dich der Dienst zu Apple und Apple schickt dich wieder zurück. Dieser Schnitt baut den **Rückweg**: Der Dienst nimmt Apples Antwort an, prüft sie streng (stammt sie von diesem einen Versuch, ist sie echt, ist sie für diesen Dienst gedacht), legt dein Konto an oder erkennt es wieder und hält das Ergebnis für kurze Zeit (eine Minute) bereit. Den letzten Schritt, mit dem der Browser das Ergebnis abholt und die Anmeldung wirklich abschließt, baut der nächste Schnitt (S4b-2b).

Für dich ändert sich **nichts Sichtbares**: Der Dienst ist von außen noch nicht erreichbar, die App und deine Daten sind nicht berührt, und ohne den letzten Schritt wird niemand angemeldet. **Zu entscheiden hast du nichts.** Technisch entschieden: Das Apple-Token aus dem Browser-Weg wird weiter nicht gespeichert und nicht widerrufen (eigener Schnitt vor S6).

## Purpose

Der Rückweg `POST /oauth/apple/return` (Apples `form_post`) existiert nur, wenn der Hinweg gebaut wird (Web-ID, OAuth-Schlüssel, keine eingehängte Test-Interaktion). Er tut genau dies und nicht mehr:

1. Anfrage prüfen: Methode, Inhaltstyp, Größe (zählend gelesen), Felder.
2. `state` einlösen (`PgAdapter(pool, "AppleLogin", now)`, einmalig).
3. Ergebnis bestimmen: Apple-Fehler → `access_denied`; sonst Code einlösen, Identity-Token vollständig prüfen, Konto anlegen oder erkennen; Apple nicht erreichbar → `temporarily_unavailable`; jede andere Ablehnung → `access_denied` (nach außen keine Unterscheidung).
4. Ergebnis als **einmaliges Ticket** (Modell `AppleTicket`, 60 s, an die `uid` der Interaktion gebunden) ablegen.
5. 303 auf `<publicUrl>/oauth/interaction/<uid>/finish?ticket=<ticket>`.

`finish` hat bis S4b-2b keinen Handler (der Hinweg liest den Pfad als uid, das Ergebnis ist die feste Absage des Ausstellers); das Ticket verfällt nach 60 s ungenutzt. Es wird niemand angemeldet. Login-CSRF (eine fremde Anmeldung einem Browser unterschieben) ist erst mit `finish` abgewehrt (Cookie **und** Ticket); bis dahin ist der Rückweg ohne Wirkung.

**Regeln vor Modell:** Protokoll- und Sicherheitsablauf ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Festlegungen aus der Analyse (Recherche 2026-11-06):

- **Ein Abschlusspfad.** Auch Apple-Fehler und Apple-Ausfall laufen über ein Ticket und `finish`, weil `interactionFinished` das Interaktions-Cookie braucht. Ticket-Inhalt: `{ uid, accountId }` oder `{ uid, error }` mit `error` ∈ {`access_denied`, `temporarily_unavailable`}.
- **Apple-Ausfall ist kein 5xx.** `unavailable` und `keys_unavailable` ergeben ein Ticket `temporarily_unavailable` und die 303, damit ein Apple-Ausfall das Fehlerfenster nicht füllt und `/health` nicht auf 503 zieht (Dienst ist im Monitor kritisch).
- **Ticket mit `accountId`:** `PgAdapter` schreibt `payload.accountId` in `oauth_records.account_id` (FK, Cascade). Ein gelöschtes Konto lässt die Ablage scheitern (feste 400), und `deleteAccount` räumt offene Tickets mit ab. Der FK-Fehler nennt die Konto-ID und wird nie protokolliert.
- **Web-Refresh-Token weder speichern noch widerrufen.** Speichern braucht Migration 005 (`apple_tokens` hat eine Zeile je Konto und würde das App-Token überschreiben), Widerrufen hat eine von Apple nicht belegte Wirkung auf die App-Berechtigung. Der Verzicht steht als Kommentar im Code mit Verweis auf die spätere Token-Ablage.
- **Identity-Token aus der Einlösung.** Der POST mit `response_type=code` (S4a) trägt `code` und `state`, nicht verlässlich einen `id_token`. Das Token, dessen Signatur, `aud`, Ablauf und Nonce geprüft werden, ist daher das `id_token` aus Apples Antwort auf die Einlösung (TLS-Antwort direkt von Apple, zusätzlich vollständig mit `verifyIdentityToken` geprüft). Dafür gibt `redeemCode` das `id_token` zusätzlich als `idToken` zurück (siehe Schnittstelle). Der Vergleich „gleicher `sub` aus Einlösung und Prüfung“ aus der Analyse entfällt damit, weil beide aus demselben Token stammen und nicht abweichen können; das Konto entsteht aus dem **geprüften** `sub`.
- **Protokoll:** nur feste Ereignisnamen `oauth return refused` und `oauth return store failed`, nie `state`, `code`, `sub`, Ticket, `uid`, Token, Fehlerobjekte oder Apples Fehlertext.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt den Plan aus dem ADR-21-Nachtrag (Schnitt 4: Apple in der Interaction des Ausstellers) um; ADR-21 und die S4a-Wahl `form_post` bleiben unberührt, keine neue Abhängigkeit, keine Migration.

**Rationale:** Der Rückweg bis zum Ticket ist allein prüfbar (Antwort, Ablage, Ablehnungen) und ungefährlich, weil das Ticket ohne `finish` nichts bewirkt. Der Abschluss mit Cookie-Prüfung ist eigene Sicherheitslogik mit eigenen Tests; beide zusammen lägen bei ≈ 530 LoC.

## Source

**Files:** `server/src/oauth-return.ts` (neu), `server/src/oauth-provider.ts` (ändern), `server/src/main.ts` (ändern), `server/src/apple-client.ts` (ändern, +3), `server/test/oauth-return.test.ts` (neu), `server/test/apple-client.test.ts` (ändern, Erwartung `idToken`).
**Identifier:** `appleReturn`, `ReturnHandler`, `redeemCode`/`Redeemed.idToken`, `verifyIdentityToken`, `findOrCreate`, `PgAdapter` (Modelle `AppleLogin`, `AppleTicket`), `appleReturnUrl`, `createProvider`, `mountIssuer`, `interactionFor`

### Schnittstelle

- **`server/src/oauth-return.ts`** (neu)
  - `type ReturnHandler = (req: IncomingMessage, res: ServerResponse) => Promise<void>`.
  - `appleReturn(deps: { pool: pg.Pool; config: AppleConfig; publicUrl: string; now: () => Date; fetch: typeof fetch; keys: KeyLookup; log: (event: string) => void }): ReturnHandler`.
  - Ablauf (feste Reihenfolge; jede Ablehnung nennt keinen Wert, `cache-control: no-store`):
    1. Methode ≠ POST → 405, Header `allow: POST`, leerer Körper.
    2. `content-type` (Parameter wie `; charset=utf-8` erlaubt) ≠ `application/x-www-form-urlencoded` → 415, leer.
    3. Körper selbst lesen, mit zählendem Limit von 16 KiB (Bytes beim Lesen gezählt, nicht nur `Content-Length`, Muster `readLimited` in `auth.ts`); darüber → 413, leer, `connection: close`, Rest wird nicht weitergelesen.
    4. Felder parsen (`URLSearchParams`): `state` genau einmal und nicht leer; genau eines von `code` und `error`, je höchstens einmal und nicht leer; `user` und alle anderen Felder werden ignoriert (auch doppelt, nie gelesen oder protokolliert). Sonst 400, Körper `bad request` (`content-type: text/plain; charset=utf-8`), Protokoll `oauth return refused`; `state` wird dabei nicht eingelöst.
    5. `state` einlösen: `find(state)` liefert den Payload `{ uid, nonce }` (beide Strings, sonst wie unbekannt), danach `consume(state)`; unbekannt, abgelaufen, bereits verbraucht (`consume` wirft) oder Datenbankfehler → 400 `bad request`, Protokoll `oauth return refused` (Datenbankfehler: `oauth return store failed`). Ab hier steht die `uid` fest und es wird ein Ticket gebaut.
    6. Ergebnis:
       - Feld `error` (jeder Wert) → `{ uid, error: "access_denied" }`; kein Aufruf an Apple.
       - sonst `redeemCode(code, webClientId, { config, fetch, now: () => now().getTime(), redirectUri: appleReturnUrl(publicUrl) })`: `reason === "unavailable"` → `temporarily_unavailable`; jede andere Ablehnung → `access_denied`.
       - `verifyIdentityToken(redeemed.idToken, nonce, { config, keys, now: now().getTime(), audiences: [webClientId] })` mit der **rohen** Nonce aus der State-Zeile: `reason === "keys_unavailable"` → `temporarily_unavailable`; jede andere Ablehnung (Signatur, Algorithmus, Ablauf, Nonce, `aud`, Aussteller, fehlende Kennung) → `access_denied`.
       - sonst `accountId = await findOrCreate(pool, verdict.sub)` → `{ uid, accountId }`.
       - Das Refresh-Token aus der Einlösung wird verworfen (nicht gespeichert, nicht widerrufen; Kommentar mit Verweis auf die spätere Token-Ablage, Migration 005).
    7. Ticket: Kennung = 32 Zufallsbytes als base64url (`node:crypto`); `new PgAdapter(pool, "AppleTicket", now).upsert(ticket, payload, 60)`. Scheitert die Ablage (auch FK, Konto inzwischen gelöscht) → 400 `bad request`, Protokoll `oauth return store failed`, nie eine Weiterleitung ohne gespeichertes Ticket.
    8. 303 mit `location: <publicUrl-Origin>/oauth/interaction/<encodeURIComponent(uid)>/finish?ticket=<ticket>`, `cache-control: no-store`, `referrer-policy: no-referrer`, leerer Körper.
  - Jeder Fehler in 5 bis 8, der nicht vorgesehen ist (z. B. `findOrCreate` wirft), wird gefangen: 400 `bad request` und `oauth return store failed`, nie ein Fehlerobjekt nach außen. Eine Funktion höchstens 50 Zeilen: Lesen/Parsen, Ergebnis bestimmen, Antworten getrennt.
- **`server/src/apple-client.ts`** (ändern): `Redeemed` wird `{ ok: true; refreshToken: string; sub: string; idToken: string } | { ok: false; reason: string }`; `readAnswer` gibt das bereits gelesene `body.id_token` mit zurück (nur `idTokenSub` hat es bisher geprüft). Sonst keine Änderung; `apple-client.test.ts` passt die drei `deepEqual`-Erwartungen auf `{ …, idToken }` an.
- **`server/src/oauth-provider.ts`** (ändern): `ProviderOptions` bekommt `appleReturn?: ReturnHandler`. Die Weiche in `createProvider` fängt zusätzlich `ctx.path === "/oauth/apple/return"` (genau dieser Pfad, jede Methode) ab, setzt `ctx.respond = false` und ruft den Handler, **nur wenn** `appleReturn` übergeben ist; ohne Handler bleibt die 404 des Ausstellers. Der Handler hat keinen Rückfall auf `productInteraction`.
- **`server/src/main.ts`** (ändern): `mountIssuer` baut `appleReturn` unter genau den Bedingungen, unter denen `interactionFor` `appleInteraction` baut (`auth.config.webClientId` gesetzt, geteilte JWKS-Instanz vorhanden, `oauth.interaction` nicht gesetzt, OAuth-Schlüssel vorhanden) und nimmt dafür dieselbe JWKS-Instanz, `options.auth.fetch ?? globalThis.fetch`, dieselbe Uhr und `logError`. Fehlerfenster: der bestehende `finish`-Haken bleibt; jede Antwort außer der festen 501 zählt, die 303 ist kein 5xx und füllt es nicht.

### Festlegungen

- **Keine Werte in Antworten, Protokoll, Fehlern:** weder `state`, `code`, `sub`, Ticket, `uid`, Token, Web-ID noch Apples Fehlertext; die einzige Stelle mit Ticket und `uid` außerhalb der Ablage ist die `location` der 303.
- **Alles Bestehende bleibt grün;** der App-Weg, der Hinweg und `oauth-provider.test.ts` sehen keinen Unterschied.
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; Tests `node:test` + `node:assert/strict`, eingereichtes `fetch`, kein Netz, Wegwerf-Schema je Dienst.
- **Unberührt:** `apple.ts`, `apple-jwks.ts`, `accounts.ts`, `oauth-adapter.ts`, `oauth-interaction.ts`, `auth.ts`, Migrationen, jede Swift-Datei, `.github/`, nginx und Compose.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `redeemCode`, `appleReturnUrl`, `AppleConfig.webClientId` (S4a) | bestehend; `Redeemed.idToken` neu |
| `verifyIdentityToken` mit `audiences` (S4a), `KeyLookup` (`createJwks`) | bestehend, ungeändert |
| `findOrCreate`, `deleteAccount` (S1) | bestehend, ungeändert |
| `PgAdapter` (S2), Modelle `AppleLogin` (S4b-1) und `AppleTicket` (neu, ohne eigene Tabelle) | bestehend |
| `createProvider`, `Interaction` (S3) | bestehend, um `appleReturn` erweitert |
| Tests: `fakeApple`, `idToken`, `begin`, `service`, `raw`, `after`-Mitschnitt aus `oauth-interaction.test.ts` | Vorbild; nicht exportiert, im neuen File knapp nachgebaut (gemeinsame Helfer nur, wenn ohne Änderung des Altfiles möglich) |
| Downstream | S4b-2b (`finish`, Cookie + Ticket, `interactionFinished`), S5 (Zustimmung), Web-Token-Ablage vor S6, S6 (nginx `/oauth/*` einschließlich `/oauth/apple/return`, `APPLE_WEB_CLIENT_ID`, Schlüssel in Compose) |

## Acceptance Criteria

Tests in `server/test/oauth-return.test.ts`. Aufbau: `start()` mit `oauth: { publicUrl: "https://loose-ends.test", keys, fetch: <CIMD-Client> }` und `auth: { config, fetch: <fakeApple> }` (Web-ID `com.henning.looseends.web`); die Anmeldung läuft mit dem CIMD-Client bis zur Interaktion und durch den Hinweg (`begin()`), der `state` und die rohe Nonce kommen aus der `location` bzw. der Zeile `AppleLogin`; `fakeApple` antwortet auf den Token-Endpunkt mit einem selbst signierten `id_token` (Test-Schlüssel wie in `apple-client.test.ts`) und auf Apples Schlüsselsatz. Apple wird nie erreicht. „POST“ meint `POST /oauth/apple/return` mit `content-type: application/x-www-form-urlencoded`, soweit nicht anders genannt.

- **AC-1:** Erfolg bis zur 303: GIVEN ein Hinweg mit gespeichertem `state` und ein `fakeApple`, das den Code gegen ein gültiges `id_token` (Web-ID als `aud`, Aussteller Apple, rohe Nonce als SHA-256-Hex, `sub` „apple-sub-1“) einlöst WHEN POST mit `state` und `code` THEN Status 303, `location` ist genau `https://loose-ends.test/oauth/interaction/<uid>/finish?ticket=<ticket>` (die `uid` der Interaktion, Ticket ≥ 43 Zeichen base64url), `cache-control: no-store`, `referrer-policy: no-referrer`, leerer Körper; genau ein Konto mit `apple_sub = apple-sub-1` existiert; der Aufruf an den Token-Endpunkt trägt `client_id = com.henning.looseends.web`, `redirect_uri = https://loose-ends.test/oauth/apple/return`, `grant_type = authorization_code` und den Code. Test: „rueckweg: erfolg ergibt 303 auf finish mit ticket und legt konto an“.
- **AC-2:** Ticket gehasht, gebunden, kurzlebig, einmalig: GIVEN das Ticket aus AC-1 WHEN die Zeile in `oauth_records` (Modell `AppleTicket`) gelesen wird THEN steht dort `id_hash` = SHA-256 des Tickets (das Ticket selbst in keiner Spalte als Klartext), `uid` = die der Interaktion, `account_id` = das Konto aus AC-1, `payload` enthält genau `uid` und `accountId` (nichts sonst, kein Token, kein `sub`), `expires_at` liegt ≤ 60 s hinter der (injizierten) Jetztzeit; `new PgAdapter(pool, "AppleTicket", now).find(ticket)` liefert den Payload, das erste `consume` gelingt, das zweite wirft, ein `find` nach Ablauf (Uhr um 61 s vorgestellt) liefert nichts. Zwei vollständige Durchläufe ergeben verschiedene Tickets. Test: „rueckweg: ticket gehasht, gebunden, 60 sekunden, einmalig“.
- **AC-3:** Zweites Einlösen desselben `state` scheitert: GIVEN der erfolgreiche POST aus AC-1 WHEN derselbe Körper erneut gesendet wird THEN 400, Körper genau `bad request`, kein zweites Ticket, kein weiterer Aufruf an Apple (Zähler am `fakeApple`), kein weiteres Konto. Test: „rueckweg: replay desselben state wird abgelehnt“.
- **AC-4:** Unbekanntes, fremdes oder abgelaufenes `state` scheitert: GIVEN (a) ein nie ausgegebenes `state`, (b) ein `state` als Ticket-Kennung bzw. aus einem anderen Modell (z. B. eine echte Ticket-Kennung als `state`), (c) ein `state`, dessen Zeile abgelaufen ist (Uhr hinter den Ablauf vorgestellt) WHEN POST mit gültigem Code THEN jeweils 400 `bad request`, kein Ticket, kein Konto, kein Aufruf an Apple. Test: „rueckweg: unbekanntes fremdes oder abgelaufenes state wird abgelehnt“.
- **AC-5:** Übergröße scheitert zählend: GIVEN ein Körper mit 16 KiB + 1 Byte, einmal mit `Content-Length` und einmal ohne (chunked, ohne Längenangabe) WHEN POST THEN 413, leerer Körper, `connection: close`, `cache-control: no-store`; ein Körper von genau 16 KiB wird gelesen (und dann wegen fehlender Felder mit 400 abgelehnt); der `state` einer gültigen Zeile bleibt in beiden Fällen unverbraucht (ein folgender gültiger POST gelingt). Test: „rueckweg: uebergroesse wird beim lesen gezaehlt abgelehnt“.
- **AC-6:** Methode und Inhaltstyp: GIVEN GET, PUT und DELETE auf `/oauth/apple/return` WHEN gesendet THEN jeweils 405 mit `allow: POST`, leerer Körper; GIVEN POST mit `application/json`, mit `text/plain` und ohne `content-type` THEN jeweils 415, leer; `application/x-www-form-urlencoded; charset=utf-8` wird angenommen. In keinem Fall wird `state` verbraucht oder Apple aufgerufen. Test: „rueckweg: falsche methode und falscher inhaltstyp“.
- **AC-7:** Fehlende und doppelte Felder: GIVEN Körper (a) ohne `state`, (b) mit zwei `state`, (c) mit leerem `state`, (d) mit zwei `code`, (e) mit zwei `error`, (f) mit `code` und `error` zugleich, (g) weder `code` noch `error`, (h) leerer Körper WHEN POST THEN jeweils 400 `bad request`, `cache-control: no-store`, kein Ticket, kein Aufruf an Apple, der gültige `state` bleibt unverbraucht. Test: „rueckweg: fehlende und doppelte felder ergeben 400“.
- **AC-8:** Das Feld `user` wird ignoriert: GIVEN ein gültiger POST aus AC-1 mit zusätzlichem Feld `user` (einmal gültiges JSON mit Namen und E-Mail, einmal Müll, einmal doppelt) WHEN gesendet THEN dasselbe Ergebnis wie AC-1 (303, ein Konto); weder Name noch E-Mail noch der `user`-Inhalt stehen in einer Zeile von `oauth_records`, in `accounts` oder im Protokoll. Test: „rueckweg: feld user wird ignoriert“.
- **AC-9:** Apple-Fehler ergibt `access_denied`: GIVEN ein POST mit `state` und `error=user_cancelled_authorize` (und einmal `error=beliebiger_text`) ohne `code` WHEN gesendet THEN 303 wie in AC-1, das Ticket trägt `{ uid, error: "access_denied" }` (kein `accountId`, `account_id` leer), es gab keinen Aufruf an Apple und es entstand kein Konto; der Fehlertext von Apple steht nirgends in der Datenbank. Test: „rueckweg: apple-fehler ergibt ticket access_denied“.
- **AC-10:** Abgelehnte Einlösung ergibt `access_denied`: GIVEN `fakeApple` antwortet auf die Einlösung mit (a) 400 `invalid_grant`, (b) 400 `invalid_client`, (c) 500, (d) 200 ohne `refresh_token`, (e) 200 mit `id_token` für die App-ID als `aud` statt der Web-ID WHEN POST THEN jeweils 303, Ticket `{ uid, error: "access_denied" }`, kein Konto; von außen sind die Fälle nicht zu unterscheiden (gleiche Statusangabe, gleiche Header, gleicher Ticket-Inhalt). Test: „rueckweg: abgelehnte einloesung ergibt access_denied“.
- **AC-11:** Ungültiges Identity-Token ergibt `access_denied`: GIVEN eine erfolgreiche Einlösung, deren `id_token` (a) eine falsche Nonce trägt (Nonce eines anderen Versuchs), (b) für eine fremde `aud` ausgestellt ist, (c) mit fremdem Schlüssel signiert ist, (d) abgelaufen ist, (e) einen anderen Algorithmus als RS256 nutzt, (f) keine `sub` trägt, (g) einen anderen Aussteller trägt WHEN POST THEN jeweils 303 mit Ticket `{ uid, error: "access_denied" }`, kein Konto, kein `apple_tokens`-Eintrag; (a) und (b) sind getrennte Fälle und beide belegt, weil `redeemCode` nur `aud` und Aussteller liest, die Nonce aber nur `verifyIdentityToken` prüft. Test: „rueckweg: ungueltiges identity-token ergibt access_denied“.
- **AC-12:** Apple nicht erreichbar ergibt `temporarily_unavailable` ohne 5xx: GIVEN (a) der Token-Endpunkt wirft (Netzfehler), (b) antwortet nicht in der Zeit (Zeitüberschreitung über den Abbruch des eingereichten `fetch`), (c) Apples Schlüsselsatz ist nicht erreichbar (`keys_unavailable`), während die Einlösung gelingt WHEN POST THEN jeweils 303 (kein 5xx), Ticket `{ uid, error: "temporarily_unavailable" }`, kein Konto. Test: „rueckweg: apple nicht erreichbar ergibt temporarily_unavailable“.
- **AC-13:** Konto zwischendurch gelöscht: GIVEN die Ablage des Tickets scheitert am Fremdschlüssel, weil das Konto nach `findOrCreate` und vor dem Schreiben gelöscht wird (Aufbau im Test: Pool-Ersatz, dessen `query` beim Schreiben des Modells `AppleTicket` zuvor `deleteAccount` ausführt, wie der Ersatz in AC-8 des Hinweg-Tests) WHEN POST THEN 400 `bad request` ohne `location`, kein Ticket in der Datenbank, Protokoll nur `oauth return store failed`, die Konto-ID und der Fehlertext des Fremdschlüssels stehen weder in Antwort noch Protokoll. Zusätzlich: GIVEN ein gültiges Ticket und danach `deleteAccount` WHEN die Zeile gelesen wird THEN ist das Ticket mit entfernt. Test: „rueckweg: geloeschtes konto ergibt 400 und raeumt tickets mit ab“.
- **AC-14:** Web-Token wird weder gespeichert noch widerrufen: GIVEN AC-1 WHEN geprüft wird THEN gibt es keine Zeile in `apple_tokens`, `fakeApple` sah nie einen Aufruf an `/auth/revoke`, und das Refresh-Token aus der Einlösung steht in keiner Zeile von `oauth_records`, keiner Antwort und keiner Protokollzeile. Test: „rueckweg: web-token wird nicht gespeichert und nicht widerrufen“.
- **AC-15:** Ohne Rückweg bleibt die 404 des Ausstellers: GIVEN (a) `start()` mit OAuth-Schlüsseln, aber ohne `auth`, (b) mit `auth: { config }` ohne `webClientId`, (c) mit gesetzter `oauth.interaction` und Web-ID WHEN POST `/oauth/apple/return` (leer und mit gültigem Körper) THEN jeweils die übliche 404 des Ausstellers ohne Wert, es entsteht nichts in der Datenbank, Apple wird nicht aufgerufen. Zusätzlich: Pfade `/oauth/apple/return/x`, `/oauth/apple/returnx` und `/oauth/apple` werden auch mit Rückweg nicht vom Handler beantwortet (404 des Ausstellers). Test: „rueckweg: ohne rueckweg und bei fremden pfaden 404 des ausstellers“.
- **AC-16:** `finish` bleibt unbehandelt: GIVEN die 303 aus AC-1 WHEN GET der `location` (mit dem Interaktions-Cookie des Hinweg-Browsers und ohne) THEN antwortet der Dienst weiterhin mit der festen 400 des Hinweges (die uid im Pfad wäre `<uid>/finish`, ungleich der Cookie-uid), schließt die Interaktion nicht ab, legt keine Sitzung und keinen Code an und verbraucht das Ticket nicht. Test: „rueckweg: finish ist noch nicht behandelt und verbraucht nichts“.
- **AC-17:** Keine Werte im Protokoll: GIVEN alle Fälle aus AC-1 bis AC-16 WHEN `console.log`, `console.error`, `process.stdout` und `process.stderr` im Test mitgeschnitten werden THEN besteht jede Zeile aus genau einem der festen Ereignisnamen `oauth return refused`, `oauth return store failed`, `oauth interaction refused`, `oauth interaction store failed` (Hinweg) oder einem bestehenden festen Ereignis aus `main.ts`; keine Zeile enthält `state`, `code`, `sub`, Ticket, `uid`, Token, Web-ID, Apple-Adresse, Konto-ID oder Fehlertext. Der Mitschnitt erlaubt keine Zeile außerhalb dieser Liste. Test: „rueckweg: protokoll nur feste ereignisse ohne werte“.
- **AC-18:** Fehlerfenster: Apple-Ausfall füllt es nicht: GIVEN ein Dienst mit injizierter Uhr, die Anmeldungen und Hinwege laufen vor dem Test, danach wird die Uhr um mehr als 5 min vorgestellt (die Hinweg-Anfragen liegen nicht mehr im Fenster) WHEN ≥ 25 Rückweg-Anfragen in 5 min beantwortet werden, alle mit Apple nicht erreichbar (303 `temporarily_unavailable`) oder 4xx THEN antwortet `/health` mit 200; Gegenprobe: GIVEN ≥ 25 Rückweg-Anfragen in 5 min, die mit 500 enden (Ersatz-Handler über die Option `appleReturn`, der wirft; Koa antwortet 500) THEN antwortet `/health` mit 503 (5xx zählt). Test: „rueckweg: fehlerfenster zaehlt 5xx und nicht die 303“.
- **AC-19:** Eine JWKS-Instanz je `start()`, benutzt vom Rückweg: GIVEN `start()` mit Apple-Konfiguration samt Web-ID und OAuth-Schlüsseln, `auth.fetch` zählt Abrufe von Apples Schlüsselsatz WHEN ein Rückweg mit gültigem Token läuft und danach `/auth/apple` mit einem Identity-Token derselben `kid` befragt wird THEN lädt der Schlüsselsatz insgesamt genau einmal (der Rückweg benutzt `keys`, der App-Weg trifft den Zwischenspeicher; ein zweiter Rückweg lädt nicht erneut). Belegt durch den Abruf-Zähler, nicht durch Einblick in interne Felder (Nachschärfung 3 aus `/60-validate` S4b-1). Test: „rueckweg: eine jwks-instanz je start fuer rueckweg und app-weg“.
- **AC-20:** `redeemCode` gibt das Token weiter: GIVEN Apples Antwort mit `id_token` WHEN `redeemCode` einlöst THEN enthält das Ergebnis `idToken` gleich dem `id_token` der Antwort; in allen Fehlerfällen bleibt `{ ok: false, reason }` unverändert. Test: die angepassten Erwartungen in `apple-client.test.ts` (Fälle „erfolg …“ und „web aud web“) und AC-1/AC-11.
- **AC-21:** Gesamtlauf: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf; `oauth-interaction.test.ts`, `oauth-provider.test.ts`, `main.test.ts`, `auth.test.ts` laufen unverändert grün; es gibt keinen neuen Eintrag in `server/package.json` und keine neue Migration. Dateiliste und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main -- server`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Nachweis: `./server/scripts/test-local.sh`, CI `server.yml`, `/60-validate`.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/oauth-return.ts` | CREATE | `appleReturn(deps)`: Lesen mit Limit, Felder, `state` einlösen, Ergebnis, Ticket, 303, ≈ +85 |
| `server/src/oauth-provider.ts` | MODIFY | Option `appleReturn?`, Weiche für genau `/oauth/apple/return`, ≈ +6 |
| `server/src/main.ts` | MODIFY | Rückweg bauen, wenn der Hinweg gebaut wird; geteilte JWKS-Instanz durchreichen, ≈ +8 |
| `server/src/apple-client.ts` | MODIFY | `Redeemed.idToken`, ≈ +3 |
| `server/test/oauth-return.test.ts` | CREATE | AC-1 bis AC-19, ≈ +215 |
| `server/test/apple-client.test.ts` | MODIFY | drei Erwartungen um `idToken` ergänzt, ≈ +3 |

### Estimated Changes

- **Files: 6** (Code: `oauth-return.ts`, `oauth-provider.ts`, `main.ts`, `apple-client.ts`; Tests: `oauth-return.test.ts`, `apple-client.test.ts`). **Das sind eine Datei mehr als das Limit von 4 bis 5.** Grund: Die Nonce lässt sich nur am `id_token` prüfen, und das liefert `redeemCode` bisher nicht heraus (die Analyse ging von einem `id_token` im POST aus; mit `response_type=code` ist er dort nicht verlässlich). Die zwei zusätzlichen Dateien sind je 3 Zeilen; die Dateizahl wird mit der Freigabe dieser Spec angenommen.
- **Code ≈ +100 LoC**, **Tests ≈ +220 LoC** (≈ 2,2× Code), insgesamt ≈ **320 LoC**. Das liegt **über dem Limit von ±250 LoC**. Warum angenommen: Die Last liegt in den Sicherheitstests (Replay, fremdes und abgelaufenes `state`, Übergröße, Typ, doppelte Felder, vier Fehlerfamilien von Apple, Ausfall, gelöschtes Konto, Protokoll, Zähler); sie lassen sich ohne Verlust an Aussage nicht kürzen, und eine weitere Teilung bräuchte denselben Testaufbau zweimal. Knapp gehalten wird das Testfile durch gemeinsame Helfer (`begin`, `fakeApple`, `post`), tabellengetriebene Fälle (AC-5, AC-6, AC-7, AC-10, AC-11) und einen einzigen Mitschnitt für AC-17. Wächst die Schätzung beim Bauen über 380, wird das vor dem Weiterbauen gemeldet. Präzedenz: #621 S3, S4a, S4b-1 (496 LoC angenommen), #615 S2a. Der Gesamtschnitt S4b-2 lag in der Analyse bei ≈ 530 LoC und ist deshalb in 2a und 2b geteilt.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine Migration, kein `generate`, keine neue Abhängigkeit.
- Doku als Teil des Schnitts: `CLAUDE.md` (`server/`-Abschnitt) bekommt eine Zeile zu `src/oauth-return.ts` (`appleReturn`: POST, Limit, Ergebnis, Ticket `AppleTicket`, 303 auf `finish`; `finish` und Abschluss in S4b-2b) und bei `apple-client.ts` den Zusatz `idToken`.
- Seiteneffekte nach außen: keine. Der Dienst ist nicht erreichbar (nginx bis S6); ohne `APPLE_WEB_CLIENT_ID` und OAuth-Schlüssel ändert sich kein Verhalten; ohne `finish` wird niemand angemeldet.

## Risiken

- **Login-CSRF / Unterschieben einer fremden Anmeldung:** Der Rückweg allein bindet nicht an den Browser (der seitenübergreifende POST trägt das Interaktions-Cookie nicht). Die Bindung ist die Kernprüfung von S4b-2b (Cookie **und** Ticket). Bis dahin bewirkt das Ticket nichts (AC-16) und verfällt nach 60 s (AC-2).
- **Replay und Fremdzustand:** `state` ist einmalig (AC-3), Ticket einmalig und gehasht (AC-2), fremde Modelle sind nicht vertauschbar (AC-4).
- **Annahme zur Nonce im Token der Einlösung:** Der Plan setzt voraus, dass Apple die Nonce der Anforderung im `id_token` der Einlösung mitgibt. Das ist in Apples Dokumentation für den Autorisierungs-Ablauf vorgesehen, in der Einlösung aber nirgends gesondert belegt. Gegenmaßnahme: Fehlt die Nonce im Token, scheitert die Anmeldung geschlossen (`access_denied`, AC-11a), nie offen. Ob Apple sie liefert, zeigt erst der erste echte Lauf in S6; dann wird nachgeschärft, die Prüfung wird nicht aufgeweicht.
- **Apple-Ausfall als Dauerfehler:** Ergibt eine 303, kein 5xx; der Client bekommt in S4b-2b einen sauberen OAuth-Fehler `temporarily_unavailable`. Ein dauerhaft kaputter Apple-Zugang bliebe im Fehlerfenster unsichtbar. Hinnahme, weil nichts öffentlich ist und der Monitor `/health` bewusst nur an echte 5xx koppelt.
- **Werte in Protokoll oder Antwort** (Fremdschlüssel-Detail nennt die Konto-ID, Apples Fehlertext, `user` mit Name und E-Mail): AC-8, AC-13, AC-17.
- **Datenschutz:** gespeichert werden nur Hashes, Zufallswerte, `uid` und Konto-ID, höchstens 60 s (Ticket); Name und E-Mail aus `user` werden nicht gelesen. Konten entstehen aus Apples `sub`, wie im App-Weg. Datenschutztext unberührt.
- **Unverwaltetes Web-Token bei Apple:** Das Refresh-Token der Services ID bleibt ungespeichert bei Apple liegen (nicht widerrufen). Bis #625 ist nur Henning zugelassen und der Dienst nicht öffentlich; die Token-Ablage mit Widerruf beim Löschen ist ein eigener Schnitt vor S6.

## Test Plan

### Automated Tests (TDD RED)

RED: `server/src/oauth-return.ts` existiert nicht, `createProvider` kennt `appleReturn` nicht, `Redeemed` hat kein `idToken`; alle Rückweg-Tests schlagen fehl (404 statt 303, fehlender Import).

| Testname | AC |
|---|---|
| „rueckweg: erfolg ergibt 303 auf finish mit ticket und legt konto an“ | AC-1 |
| „rueckweg: ticket gehasht, gebunden, 60 sekunden, einmalig“ | AC-2 |
| „rueckweg: replay desselben state wird abgelehnt“ | AC-3 |
| „rueckweg: unbekanntes fremdes oder abgelaufenes state wird abgelehnt“ | AC-4 |
| „rueckweg: uebergroesse wird beim lesen gezaehlt abgelehnt“ | AC-5 |
| „rueckweg: falsche methode und falscher inhaltstyp“ | AC-6 |
| „rueckweg: fehlende und doppelte felder ergeben 400“ | AC-7 |
| „rueckweg: feld user wird ignoriert“ | AC-8 |
| „rueckweg: apple-fehler ergibt ticket access_denied“ | AC-9 |
| „rueckweg: abgelehnte einloesung ergibt access_denied“ | AC-10 |
| „rueckweg: ungueltiges identity-token ergibt access_denied“ | AC-11 |
| „rueckweg: apple nicht erreichbar ergibt temporarily_unavailable“ | AC-12 |
| „rueckweg: geloeschtes konto ergibt 400 und raeumt tickets mit ab“ | AC-13 |
| „rueckweg: web-token wird nicht gespeichert und nicht widerrufen“ | AC-14 |
| „rueckweg: ohne rueckweg und bei fremden pfaden 404 des ausstellers“ | AC-15 |
| „rueckweg: finish ist noch nicht behandelt und verbraucht nichts“ | AC-16 |
| „rueckweg: protokoll nur feste ereignisse ohne werte“ | AC-17 |
| „rueckweg: fehlerfenster zaehlt 5xx und nicht die 303“ | AC-18 |
| „rueckweg: eine jwks-instanz je start fuer rueckweg und app-weg“ | AC-19 |
| angepasste Fälle in `apple-client.test.ts` + AC-1/AC-11 | AC-20 |
| `./server/scripts/test-local.sh`, `/60-validate` (Dateiliste per `git diff`) | AC-21 |

- [ ] Test 1 (AC-1, AC-2, AC-14): GIVEN Hinweg und `fakeApple` WHEN gültiger POST THEN 303, Konto, Ticket gehasht, gebunden, 60 s, einmalig, Web-Token ungespeichert und unwiderrufen.
- [ ] Test 2 (AC-3, AC-4): GIVEN Replay, unbekanntes, fremdes, abgelaufenes `state` WHEN POST THEN feste 400, nichts angelegt, Apple unberührt.
- [ ] Test 3 (AC-5, AC-6, AC-7, AC-8): GIVEN Übergröße, falsche Methode und Typ, fehlende und doppelte Felder, `user` WHEN POST THEN 413/405/415/400 bzw. ignoriert, `state` unverbraucht.
- [ ] Test 4 (AC-9, AC-10, AC-11, AC-12): GIVEN Apple-Fehler, abgelehnte Einlösung, ungültiges Token, Ausfall WHEN POST THEN 303 mit `access_denied` bzw. `temporarily_unavailable`, kein Konto.
- [ ] Test 5 (AC-13, AC-15, AC-16): GIVEN gelöschtes Konto, fehlender Rückweg, fremde Pfade, `finish` WHEN abgefragt THEN feste 400 bzw. 404, nichts verbraucht.
- [ ] Test 6 (AC-17, AC-18, AC-19, AC-20, AC-21): GIVEN alle Fälle WHEN Protokoll, Fehlerfenster, Abruf-Zähler und Gesamtlauf geprüft werden THEN keine Werte, 5xx zählt und 303 nicht, ein Schlüsselabruf, alles grün.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): Ticket-Weg** | POST → alles prüfen → Ticket in `oauth_records` (60 s, an `uid` gebunden, einmalig) → 303 → später GET `finish` mit Cookie + Ticket | bindet an denselben Browser, kein neues Cookie, keine Migration | zusätzlicher Schritt, Zeilen in `oauth_records` | — |
| B Abschluss direkt im POST über `provider.Interaction.find(uid)` | kein Ticket, kein Sprung | einfacher | kein Cookie-Nachweis, also Login-CSRF | die Bindung an den Browser als Sicherheitsannahme von S4b |
| C eigenes `SameSite=None; Secure`-Cookie | Zustand im Browser | keine Ablage | zweite Cookie-Sorte, schwächere Haltung | die Wahl „Cookie-Haltung nur Bibliothek, Lax“ |
| D `response_mode=query` | normale Weiterleitung, Lax-Cookie reist | keine Ablage | Code steht in der URL | die S4a-Wahl „Code nie in einer URL“ |
| E Social-Login-Bibliothek für Apple | fertiger Rückweg | weniger eigener Code | neue Abhängigkeit, berührt ADR-21 und „nur Apple“ (#615); die vorhandenen geprüften Bausteine reichen | ADR-21; wird nicht vorgeschlagen |
| F Web-Token sofort widerrufen | keine unverwaltete Berechtigung bei Apple | sauber | Wirkung auf die App-Berechtigung desselben Nutzers von Apple nicht belegt (Forum 844628, unbeantwortet) | verworfen bis zur Token-Ablage |
| G Rückweg und Abschluss in einem Schnitt | ein Durchstich | ein PR | ≈ 530 LoC, zwei Sicherheitsrichtungen in einem Review | die Teilung 2a / 2b |

B bis E sind bereits in S4b verworfen und werden hier nicht neu verhandelt; F und G sind in der Analyse dieses Schnitts verworfen.

## Out of Scope / Folgeschnitte

- **S4b-2b, Abschluss `finish`:** Pfadweiche in `oauth-interaction.ts` (uid und Rest, `<uid>/finish`), Interaktions-Cookie **und** Ticket verlangen (einmalig, an die `uid` gebunden), `interactionFinished({ login: { accountId } })` bzw. `{ error }`; Ende-zu-Ende bis zur festen 501 der Zustimmung. Dort auch die Nachschärfungen 1 (Fehlerfenster-Test von S4b-1 ohne die `begin()`-Anfragen; hier in AC-18 für den Rückweg bereits so gebaut) und 2 (Mitschnitt in `after` des Hinweg-Tests erlaubt nur die festen Ereignisse; hier in AC-17 für den neuen Test bereits so gebaut) im Altfile `oauth-interaction.test.ts`.
- **Zustimmungsseite und Erlaubnisliste (S5):** `consent`-Prompt, nur Henning bis #625.
- **Web-Token-Ablage (eigener Schnitt vor S6):** Ablage je Konto und `client_id` (Migration 005), Widerruf beim Löschen, Entscheidung über sofortigen Widerruf.
- **Betrieb (S6):** Services ID im Apple-Konto, nginx `/oauth/*` einschließlich `/oauth/apple/return`, `APPLE_WEB_CLIENT_ID` und OAuth-Schlüssel in Compose (Repo `henemm-infra`).

## Abnahme

Kein Pfad der Geräteliste berührt (nur `server/`, keine App, kein `project.yml`). Die Abnahme endet nach den Tests: `./server/scripts/test-local.sh` (typecheck + `node --test` gegen ein Wegwerf-Postgres) grün und die CI `server.yml` auf dem PR grün. Ein Simulator-Durchlauf entfällt, weil es reiner Dienstcode ohne Oberfläche ist und der Dienst von außen noch nicht erreichbar ist; der Rückweg wird in den Tests Ende-zu-Ende vom CIMD-Client über `/oauth/auth` und den Hinweg bis zur 303 durchgespielt (echter Aussteller, echte Datenbank, nur Apple ist `fakeApple`). Stufe 3 entfällt.

## Definition of Done

- [ ] AC-1 bis AC-21 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) aktualisiert: neue Zeile zu `server/src/oauth-return.ts` (`appleReturn`, Modell `AppleTicket`, Ergebnisse, 303 auf `finish`, Web-Token weder gespeichert noch widerrufen, Abschluss S4b-2b) und `idToken` bei `apple-client.ts`
- [ ] #621 kommentiert (Stand Schnitt 4b-2a, Folge: S4b-2b `finish`, Web-Token-Ablage vor S6, S5, S6), Board-Karte aktuell

## Changelog

- 2026-11-06: Initial spec created (Schnitt 4b-2a)
