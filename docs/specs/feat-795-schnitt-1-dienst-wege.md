---
entity_id: feat-795-schnitt-1-dienst-wege
type: feature
created: 2026-11-11
updated: 2026-11-11
status: draft
workflow: feat-795-app-auftraege
---

# Spec: Dienst-Wege für die App, Schnitt S1 (#795, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S1 von sechs; das Issue bleibt offen (`Refs #795`, nie `Closes #795`).
Analyse: `docs/context/feat-795-app-auftraege.md` (Abschnitte „Schnitte“ und „Technical Approach (S1)“).
Vorgänger: `docs/specs/spike-613-schnitt-c3a-abschrift-annehmen.md` (`putTranscript`), `docs/specs/spike-613-schnitt-c3b-auftraege.md` (`claimOrder`, `putResult`, `device` als freier Text „bis C6“, Rückholen „später“), `docs/specs/feat-615-schnitt-3b-anmelden-abmelden.md` (`bearerToken`, Muster `/auth/logout`), `docs/specs/feat-615-schnitt-3c2-einhaengen.md` (Routentabelle, `gated`, Körpergrenze).

## Für den PO

Heute kann der Dienst Abschriften und Aufträge verwalten, aber nur Claude kommt von der einen Seite heran. Dieser Schnitt baut im Dienst die drei Türen für die andere Seite, die App: Abschrift ablegen, einen offenen Auftrag abholen, das Ergebnis melden. Jede Tür verlangt die Anmeldung der App; ohne gültige Anmeldung ist die Antwort immer ein nacktes „nicht erlaubt“. Neu ist außerdem eine Sicherung gegen hängende Aufträge: Holt ein Gerät einen Auftrag und meldet sich zehn Minuten nicht, bekommt ihn beim nächsten Abholen ein Gerät, das fragt. Von außen ändert sich noch nichts: Der Server vor dem Dienst lässt diese Pfade erst im nächsten Schnitt durch, und die App ruft nichts auf.

## Purpose

`server/src/app-routes.ts` (neu) bietet `POST /app/transcript`, `POST /app/orders/claim` und `POST /app/orders/result` an und hängt sie in `server/src/main.ts` ein. Sie rufen die fertigen Funktionen `putTranscript`, `claimOrder` und `putResult` auf. `claimOrder` in `server/src/orders.ts` bekommt die Rückholregel: ein vergebener Auftrag ohne Ergebnis, dessen Vergabe älter als 10 Minuten ist, wird beim nächsten `claim` wieder frei, in derselben `UPDATE`-Anweisung, mit der Zeit aus der Datenbank. Die Spalte `orders.claimed_at` existiert seit `001_claude_schema.sql`; **keine Migration**. **Regeln vor Modell:** Protokoll- und Betriebsarbeit, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Quelle (Recherche 2026-11-11, aus der Analyse): Eine Warteschlange, bei der ein Verbraucher ein Element „ausleiht“ und es nach Ablauf einer Frist ohne Quittung wieder frei wird, ist das übliche Muster (Sichtbarkeits-Timeout, z. B. bei SQS und `SELECT … FOR UPDATE SKIP LOCKED`-Warteschlangen); es liefert „mindestens einmal“ statt „genau einmal“. Die Doppelausführung fängt hier der Vertrag ab: `OrderExecutor` prüft den erwarteten Stand (`stale`), und ein Ergebnis des alten Geräts wird danach abgelehnt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-21 — Weg B (Dienst zwischen Claude und App, Abschrift und Aufträge); dieser Schnitt setzt die App-Seite der Wege um und ändert die Entscheidung nicht. Die Rückholregel ergänzt die Vergabe „an genau ein Gerät“ aus dem Vertrag um eine Frist (Ergänzung im Vertragsdokument, kein neuer ADR).
- **Rationale:** (1) Die Routen stehen in einer eigenen Datei wie `auth.ts`, damit `main.ts` nur einhängt. (2) Die Sitzung wird genau wie bei `/auth/logout` und `/auth/delete` geprüft, der Dienst kennt nur ein Sitzungs-Token der App (nicht das OAuth-Token von Claude). (3) Die Rückholregel liegt in der einen `UPDATE`-Anweisung, weil nur so „vergeben“ und „zurückgeholt“ nicht gegeneinander laufen; die Frist rechnet die Datenbank, nie die Uhr des Prozesses oder des Geräts.

## Source

**Files:** `server/src/app-routes.ts` (neu), `server/src/orders.ts` (`claimOrder`), `server/src/main.ts` (einhängen), `server/test/app-routes.test.ts` (neu), `docs/reference/claude-abschrift-vertrag.md`, `CLAUDE.md` (Abschnitt `server/`)
**Identifier:** `appRoutes`, `claimOrder`, `CLAIM_TIMEOUT_MINUTES`

### Schnittstelle

`appRoutes(deps: { pool: pg.Pool }): Record<string, Route>` liefert genau drei Pfade; Ausnahmen werden nicht gefangen, `dispatch` in `main.ts` macht daraus 500 ohne Körper. Jede Antwort trägt `cache-control: no-store`, jede Ablehnung hat keinen Körper.

Gemeinsame Reihenfolge der Prüfungen (die erste Verletzung antwortet):

1. Methode: nicht `POST` → **405** mit `allow: POST`.
2. Sitzung: `bearerToken(request)` fehlt, falsches Schema, leer oder mehrere → **401**; `resolveSession` liefert `null` (unbekannt, abgelaufen) → **401**. Nie ein Hinweis, welche Prüfung scheiterte.
3. Gerät (nur `claim` und `result`): Kopf `X-Device` fehlt oder ist keine UUID (Form `8-4-4-4-12` Hex, beliebige Groß-/Kleinschreibung) → **400**. Der Dienst legt die UUID in Kleinschreibung ab und vergleicht sie so. `transcript` verlangt kein Gerät: die Abschrift gehört dem Konto, nicht dem Gerät.
4. Inhaltstyp (nur `transcript` und `result`): nicht `application/json` (Parameter wie `charset` erlaubt) → **415**.
5. Körper (nur `transcript` und `result`): beim Lesen gezählt (die `Content-Length` kann lügen), über **256 KiB** (262 144 Bytes) → **413**. `claim` liest keinen Körper und ignoriert einen mitgesandten.
6. JSON: nicht lesbar → **400**.

Die Wege:

- **`POST /app/transcript`:** ruft `putTranscript(pool, account, doc)`. `stored` → **204**. `older` (eine gleich alte oder ältere Abschrift als die abgelegte, das heißt: der Dienst hat schon eine neuere, etwa von einem zweiten Gerät) → **204**, nicht 409: Das Ergebnis ist für die App dasselbe, der Aufruf ist gültig, und ein Fehlerstatus würde die App zu Wiederholungen verleiten, die nie etwas ändern. Ungültige Abschrift (`FormError` aus `checkTranscript`, auch Rohtext oder Notiz in der Abschrift) → **400** ohne Körper; Pfad und Grund aus der Meldung gehen nie nach außen. Ein anderer Fehler (Datenbank) → wird nicht gefangen, 500.
- **`POST /app/orders/claim`:** ruft `claimOrder(pool, account, device)`. Gibt es einen freien (oder zurückgeholten) Auftrag → **200**, Körper ist der Auftrag, `content-type: application/json`; keiner offen → **204**.
- **`POST /app/orders/result`:** ruft `putResult(pool, account, device, doc)`. `stored` oder `duplicate` → **204**; `refused` (unbekannter Auftrag, Auftrag eines anderen Kontos, Auftrag eines anderen Geräts, nie vergeben, zurückgeholt) → **409**; ungültiges Ergebnis (`FormError` aus `checkResult`) → **400** ohne Körper.

### Rückholregel

`claimOrder` wählt in derselben Anweisung unter den Aufträgen des Kontos den ältesten (`ORDER BY created_at, id`, `FOR UPDATE SKIP LOCKED`, `LIMIT 1`), der entweder frei ist (`claimed_by IS NULL`) oder **vergeben, ohne Ergebnis und die Vergabe älter als 10 Minuten** (`claimed_at < now() - make_interval(mins => 10)` und `NOT EXISTS (SELECT 1 FROM order_results WHERE order_id = orders.id)`). Beim Zurückholen werden `claimed_by` und `claimed_at` neu gesetzt (die CHECK-Bedingung „beide oder keiner“ bleibt erfüllt). Die Frist steht als eine benannte Konstante (`CLAIM_TIMEOUT_MINUTES = 10`) in `orders.ts`; die Zeit liefert Postgres (`now()`), nie ein Parameter aus dem Prozess. Die Signatur von `claimOrder` bleibt; bestehende Tests in `orders.test.ts` laufen unverändert.

Folgen, die so gewollt sind: (a) Ein Ergebnis des alten Geräts nach der Rückgabe an ein neues ist `refused`, weil `putResult` verlangt, dass `claimed_by` das meldende Gerät ist. (b) Ein Auftrag, für den schon ein Ergebnis liegt, wird nie zurückgeholt, auch nicht nach Stunden. (c) „Mindestens einmal“ statt „genau einmal“: Hat das alte Gerät den Auftrag doch ausgeführt und nur das Ergebnis nicht melden können, führt das neue Gerät ihn erneut aus; der erwartete Stand im Auftrag macht daraus `stale` (Vertrag), nicht eine doppelte Änderung. Ausnahme, dem Vertrag nach bekannt: ein `capture` ist nicht durch einen erwarteten Stand geschützt; ein zurückgeholtes `capture` kann also doppelt erfasst werden. (d) Ein Gerät, das auf denselben Auftrag zweimal in Folge zurückgreift (dieselbe UUID), bekommt ihn auch zurück und darf sein Ergebnis melden.

### Festlegungen

- **Gerätekennung:** UUID, nicht personenbezogen, je Installation (Erzeugung in S2). `orders.claimed_by` bleibt Text; die Prüfung der Form geschieht nur an der Tür, `claimOrder` und `putResult` bleiben unverändert in dem, was sie als `device` annehmen.
- **Eine Abschrift je Konto, nicht je Gerät:** das zuletzt berechnete (`generatedAt`) gewinnt, wie in C3a.
- **Einhängen in `main.ts`:** `mountApp(pool, isReady)` hängt `appRoutes({ pool })` immer ein (ohne Option; die Routen brauchen keine Apple-Einrichtung) und verpackt jede Route in `gated(isReady, …)`; vor `migrate` also **503** ohne Körper. Die Tabelle bleibt `{ ...mountAuth, ...mountApp, ...options.extraRoutes, "/health", "/mcp" }`: `/health` und `/mcp` bleiben unüberschreibbar. Die globale Körpergrenze im `bridge` (1 MiB) bleibt davor bestehen.
- **Stille:** keine neuen Logzeilen; weder Abschrift, Auftrag, Ergebnis noch Token, Gerät oder Konto verlassen den Dienst in einer Meldung.
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; keine neuen Pakete.
- **Unberührt:** `transcripts.ts`, `auth.ts`, `accounts.ts`, `mcp.ts`, alle Migrationen, `.github/`, `project.yml`, jede Swift-Datei.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `putTranscript`, `FormError` (`transcripts.ts`) | bestehend, unverändert |
| `claimOrder`, `putResult` (`orders.ts`) | bestehend; `claimOrder` erweitert (Rückholregel) |
| `bearerToken` (`auth.ts`), `resolveSession` (`accounts.ts`) | bestehend, unverändert |
| `gated`, `Route`, Routentabelle (`main.ts`) | bestehend; Einhängen neu |
| `node:test`, `pg` | bestehend, **keine neuen Pakete** |
| Downstream | S1b nginx (`/app/` freigeben, `henemm-infra`), S2 App-Client (ruft die Wege), #622-DoD (Beleg aus claude.ai hängt an #795) |

## Acceptance Criteria

Alle Tests mit `node:test` und `node:assert/strict` in `server/test/app-routes.test.ts`, gegen das Wegwerf-Postgres aus `server/test/db.ts` (`freshPool`, `migrate`) und, wo `main.ts` betroffen ist, gegen `start()` mit echter Routentabelle; Sitzungen mit `findOrCreate` und `createSession`. Kein Netz. Ablehnungsfälle tabellengetrieben, ein Fall je Zeile. Abschrift, Auftrag und Ergebnis kommen aus den ```json-Beispielen des Vertragsdokuments bzw. den Bauteilen von `transcripts.test.ts` und `orders.test.ts`, nicht aus Abschriften von Hand. Kein bestehender Testfall wird geändert.

- **AC-1:** Abschrift ablegen: GIVEN eine gültige App-Sitzung und eine gültige Abschrift WHEN `POST /app/transcript` mit `content-type: application/json` THEN **204** ohne Körper, `cache-control: no-store`, und `getTranscript` liefert für dieses Konto genau diese Abschrift. Ein zweiter Aufruf mit größerem `generatedAt` ersetzt sie (204, neue Abschrift gespeichert). Test: „app: abschrift ablegen und ersetzen“.
- **AC-2:** Ältere Abschrift ist kein Fehler: GIVEN abgelegte Abschrift mit `generatedAt` T WHEN `POST /app/transcript` mit `generatedAt` T (gleich) und mit T minus 1 Minute (älter) THEN beide **204**, und die abgelegte Abschrift ist unverändert (`received_at` und Inhalt gleich). Test: „app: aeltere abschrift 204 ohne wirkung“.
- **AC-3:** Ungültige Abschrift: WHEN `POST /app/transcript` mit (a) einem Feld zu wenig, (b) unbekannter Version 2, (c) einem Schlüssel `rawText` in einer Aufgabe, (d) einem Schlüssel `note`, (e) JSON, das kein Objekt ist (`[]`, `"x"`, `null`), (f) nicht lesbarem JSON (`{`) THEN jeweils **400** ohne Körper (die Antwort enthält weder Pfad noch Grund, `await response.text()` ist leer), und für das Konto liegt keine Abschrift. Tabellengetrieben, ein Fall je Zeile. Test: „app: ungueltige abschrift 400 ohne details“.
- **AC-4:** Auftrag abholen: GIVEN ein freier Auftrag des Kontos (per `putOrder`) und gültige Sitzung, Kopf `X-Device` = UUID WHEN `POST /app/orders/claim` THEN **200**, `content-type: application/json`, `cache-control: no-store`, Körper ist der Auftrag, gleichwertig (`deepEqual`) zum abgelegten Dokument, und `orders.claimed_by` ist die UUID in Kleinschreibung (auch bei großgeschriebener UUID im Kopf). Ein zweiter `claim` desselben oder eines anderen Geräts sofort danach: **204** (kein freier Auftrag mehr). Test: „app: auftrag abholen genau einmal“.
- **AC-4a:** Reihenfolge und Konto: GIVEN drei freie Aufträge, eingereiht in der Reihenfolge A, B, C, und ein vierter, freier eines anderen Kontos WHEN dreimal `claim` THEN A, B, C in dieser Reihenfolge, beim vierten Mal 204; der Auftrag des anderen Kontos wird nie ausgeliefert. Test: „app: abholen in reihenfolge und nur eigenes konto“.
- **AC-5:** Nichts offen: GIVEN keine Aufträge WHEN `POST /app/orders/claim` THEN **204** ohne Körper, `cache-control: no-store`. Test: „app: abholen ohne auftrag 204“.
- **AC-6:** Ergebnis melden: GIVEN ein an Gerät G vergebener Auftrag WHEN `POST /app/orders/result` mit `X-Device` = G und dem Ergebnis (`outcome: done`, danach im Test ein zweiter Auftrag mit `rejected` und `reason: stale`) THEN **204**; `getResult` meldet `result` mit genau diesem Dokument. Dasselbe Ergebnis ein zweites Mal von G: **204**, die Zeile in `order_results` ist unverändert (`duplicate`). Test: „app: ergebnis melden und wiederholen“.
- **AC-7:** Ergebnis abgelehnt: WHEN `POST /app/orders/result` für (a) einen unbekannten Auftrag, (b) einen nie vergebenen Auftrag, (c) einen an ein anderes Gerät vergebenen, (d) den Auftrag eines anderen Kontos THEN jeweils **409** ohne Körper, und `order_results` bleibt leer. Tabellengetrieben. Test: „app: ergebnis abgelehnt 409“.
- **AC-8:** Ungültiges Ergebnis: WHEN `POST /app/orders/result` mit (a) fehlendem `orderID`, (b) `outcome: rejected` ohne `reason`, (c) unbekanntem `outcome`, (d) `reason` bei `done`, (e) nicht lesbarem JSON THEN jeweils **400** ohne Körper, `order_results` bleibt leer. Test: „app: ungueltiges ergebnis 400“.
- **AC-9:** Anmeldung, tabellengetrieben über alle drei Wege: (a) kein `authorization`-Kopf, (b) Schema `Basic`, (c) `Bearer` ohne Token, (d) `Bearer a b`, (e) unbekanntes Token, (f) abgelaufene Sitzung (`last_used_at` vor 91 Tagen gesetzt), (g) beendete Sitzung (`endSession`), (h) das Token eines gelöschten Kontos, (i) gültige Sitzung mit **fehlendem** `X-Device` bzw. (j) **falschem** `X-Device` (`"gerät"`, UUID ohne Bindestriche, UUID mit 35 Zeichen; nur `claim` und `result`) → (a) bis (h) jeweils **401** ohne Körper und mit `cache-control: no-store`, (i) und (j) jeweils **400**; ein 401 geht der Geräteprüfung voraus (Fall: unbekanntes Token **und** fehlendes `X-Device` → 401). In keinem Fall ändern sich `transcripts`, `orders` oder `order_results` (Zeilenzahlen und Inhalt gleich). Test: „app: sitzung und geraet, jede ablehnung“.
- **AC-10:** Methode, Inhaltstyp, Größe: (a) `GET`, `PUT`, `DELETE` auf jeden der drei Pfade mit gültiger Sitzung → **405** mit `allow: POST`; (b) `POST /app/transcript` und `/app/orders/result` mit `content-type: text/plain` oder ohne → **415**; (c) `application/json; charset=utf-8` → angenommen; (d) ein Körper von genau 256 KiB (262 144 Bytes, gültiges JSON mit Füllfeld) wird gelesen (die Antwort ist dann ein **400** aus der Formprüfung, nicht 413); 256 KiB + 1 Byte und 900 KiB → **413** ohne Körper und die Datenbank ist unberührt; (e) ein Körper über 256 KiB **ohne** `Content-Length` (chunked) und einer, dessen `Content-Length` weniger behauptet, als gesendet wird, ergeben ebenfalls 413 bzw. eine abgebrochene Verbindung, ohne dass Daten abgelegt werden; (f) ein unauthentifizierter Aufruf (kein Token) mit falschem Inhaltstyp oder zu großem Körper antwortet **401**, nicht 415 oder 413 (die Anmeldung geht den Körperprüfungen voraus). Tabellengetrieben, ein Fall je Zeile. Test: „app: methode inhaltstyp und groesse“.
- **AC-11:** Rückholregel, Kern: GIVEN ein an Gerät G1 vergebener Auftrag, dessen `claimed_at` per SQL auf `now() - interval '11 minutes'` gesetzt ist, ohne Ergebnis WHEN Gerät G2 `claim` ruft THEN **200** mit demselben Auftrag, `orders.claimed_by` = G2 und `claimed_at` frisch (nach der Zeit vor dem Aufruf). Danach meldet G1 sein Ergebnis → **409** (`order_results` leer); G2 meldet → **204**. Test: „app: rueckholen nach zehn minuten“.
- **AC-12:** Rückholregel, Grenzen: Die Frist rechnet die Datenbank, sie gilt strikt „älter als“. (a) `claimed_at` = `now() - interval '9 minutes'` → ein `claim` eines anderen Geräts liefert **204** (Auftrag bleibt bei G1, `claimed_by` unverändert); (b) `claimed_at` = `now() - interval '11 minutes'`, **aber** mit schon abgelegtem Ergebnis → **204**, nie zurückgeholt, `order_results` und `claimed_by` unverändert; (c) ein zweiter, freier Auftrag neben einem zurückholbaren: der **ältere** (`created_at`) wird zuerst ausgeliefert, bei zwei `claim`-Aufrufen kommen beide, jeder genau einmal; (d) ein zurückholbarer Auftrag eines **anderen Kontos** wird nicht ausgeliefert. Tabellengetrieben. Test: „app: rueckholen grenzen“.
- **AC-13:** Rückholregel ist atomar: GIVEN ein zurückholbarer Auftrag WHEN zwei Geräte gleichzeitig `claim` rufen (`Promise.all` über zwei Verbindungen des Pools, 20 Wiederholungen mit je frischem Auftrag) THEN genau einer bekommt 200, der andere 204, und `claimed_by` entspricht dem Gewinner; nie zwei 200. Test: „app: rueckholen gleichzeitig genau einer“.
- **AC-14:** Einhängen und Betrieb: (a) Vor `migrate` (Datenbank nicht erreichbar, wie in den bestehenden Tests von `main.test.ts`) antworten alle drei Pfade **503** ohne Körper und rufen die Datenbank nicht; nach `ready` laufen sie. (b) Die Routen laufen in `start()` **ohne** Option `auth` (kein Apple-Setup nötig). (c) `extraRoutes` mit den Schlüsseln `/health` und `/mcp` ändert weiterhin nichts an diesen beiden Pfaden; ein `extraRoutes`-Eintrag `/app/transcript` überschreibt die App-Route (Reihenfolge wie bei `auth`, Test-Naht) — nur belegt, nicht gewünscht in Produktion. (d) Eine Anfrage über dem globalen 1-MiB-Limit des `bridge` an `/app/transcript` antwortet 413 mit `connection: close`, ohne dass die Route läuft. (e) Ein 401 und ein 400 zählen ins Fehlerfenster wie jede Antwort ≥ 400 bleibt unverändert: `/health` kippt weiterhin nur nach Regel aus `main.test.ts`; hier nur belegt, dass 204 und 200 nicht kippen. Test: „app: einhaengen vor migrate und ohne auth“.
- **AC-15:** Keine Preisgabe: Bei jeder Antwort mit Status ≥ 400 aus AC-3, AC-7 bis AC-10 ist `await response.text()` leer (`""`); kein Header außer `cache-control: no-store` (und `allow` bei 405, `connection` bei 413) trägt Inhalt. Der Test sammelt beim Durchlauf der Tabellen aus AC-3, AC-7, AC-8, AC-9, AC-10 jeweils Status, Körper und Kopfnamen und prüft sie gegen diese Regel; ein Logger-Spion in `console.error` (Muster aus `main.test.ts`) bleibt über den ganzen Lauf leer. Test: „app: ablehnungen ohne koerper und ohne log“.
- **AC-16:** Vertragsdokument und Doku: `docs/reference/claude-abschrift-vertrag.md` hat einen neuen Abschnitt (Überschrift enthält „Wege der App“) mit den drei Pfaden (Methode, Kopf `Authorization: Bearer <App-Sitzung>`, `X-Device`, Statuscodes und Körper) und einem Absatz „Rückholen“ mit der Frist 10 Minuten, den Folgen (a) bis (d) aus „Rückholregel“ und dem Hinweis „mindestens einmal“. Der Abschnitt enthält **keinen** weiteren ```json-Block (die Tests von `orders.test.ts` lesen genau drei Blöcke und schlagen sonst fehl; Beispiele im Abschnitt stehen als ```http oder ```text). `CLAUDE.md`, Abschnitt `server/`, nennt `src/app-routes.ts` (drei Wege, Sitzung, `X-Device`, 256 KiB, `gated`, Rückholregel in `claimOrder`, nginx und App noch offen, S1b/S2). Test: „app: vertrag und doku“ (Prüfung per `readFileSync` und Regex: die drei Pfade, `X-Device`, `10 Minuten`, genau drei ```json-Blöcke im Vertrag, `app-routes.ts` in `CLAUDE.md`).
- **AC-17:** Grenze und Länge: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/app-routes.ts`, `server/src/orders.ts`, `server/src/main.ts`, `server/test/app-routes.test.ts` und `CLAUDE.md`; `transcripts.ts`, `auth.ts`, `accounts.ts`, `mcp.ts`, `server/migrations/` und alle weiteren Dateien sind unverändert; jede Funktion in den drei Quelldateien hat höchstens 50 Zeilen; in `orders.ts` ändern sich nur `claimOrder` und die Konstante `CLAIM_TIMEOUT_MINUTES`. **Kein dauerhafter Test** (ein Test gegen `origin/main` scheitert im flachen CI-Checkout und ist nach dem Merge leer): Beleg einmalig in `/60-validate`, Befehl, Ausgabe und Funktionslängen im Validierungsprotokoll.

## Test Plan

Geplante Tests (Namen, alle in `server/test/app-routes.test.ts`):

- „app: abschrift ablegen und ersetzen“ (AC-1)
- „app: aeltere abschrift 204 ohne wirkung“ (AC-2)
- „app: ungueltige abschrift 400 ohne details“ (AC-3)
- „app: auftrag abholen genau einmal“ (AC-4)
- „app: abholen in reihenfolge und nur eigenes konto“ (AC-4a)
- „app: abholen ohne auftrag 204“ (AC-5)
- „app: ergebnis melden und wiederholen“ (AC-6)
- „app: ergebnis abgelehnt 409“ (AC-7)
- „app: ungueltiges ergebnis 400“ (AC-8)
- „app: sitzung und geraet, jede ablehnung“ (AC-9)
- „app: methode inhaltstyp und groesse“ (AC-10)
- „app: rueckholen nach zehn minuten“ (AC-11)
- „app: rueckholen grenzen“ (AC-12)
- „app: rueckholen gleichzeitig genau einer“ (AC-13)
- „app: einhaengen vor migrate und ohne auth“ (AC-14)
- „app: ablehnungen ohne koerper und ohne log“ (AC-15)
- „app: vertrag und doku“ (AC-16)
- AC-17: kein Test, Validierungsbeleg in `/60-validate`

RED: `app-routes.ts` existiert nicht, alle Tests schlagen beim Import fehl; AC-11 bis AC-13 schlagen auch mit vorhandener Datei fehl, solange `claimOrder` nicht zurückholt.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): drei Wege, Rückholen beim nächsten `claim`, ohne Hintergrundprozess.** Keine Uhr, kein Aufräumer, nichts, was ausfallen kann; ein zurückholbarer Auftrag liegt, bis jemand fragt, was für eine Abholung beim Start der App ohnehin geschieht.
- **B: Abschrift je Gerät statt je Konto** (jedes Gerät legt eigene Abschrift ab): würde widersprüchliche Stände zweier Geräte sichtbar machen; verworfen, weil iCloud die Geräte ohnehin angleicht und `generatedAt` den neueren nimmt. Kippte die Festlegung „eine Abschrift je Konto“ aus ADR-21 (Abschnitt Abschrift), die hier nicht gekippt wird.
- **C: Abholen als Long-Poll oder offene Verbindung** statt `claim` mit sofortiger Antwort: spart dem Gerät die Wiederholung im Vordergrund, wirkt aber im Hintergrund nicht und verlangt Haltezeiten im Dienst und in nginx; nur eine Ergänzung, kein Ersatz. Kippte nichts Bestehendes, würde aber die Grenze „Antworten kurz, kein Streaming auf `/app/`“ aus S1b öffnen.
- **D: Hängende Aufträge von Claude zurückfordern lassen** (statt Frist im Dienst, ein Werkzeug „Auftrag zurückziehen“): verlangt ein neues MCP-Werkzeug und die Entscheidung von Claude, die er nicht treffen kann (er sieht nicht, ob das Gerät lebt); verworfen. Kippte die Zeile in ADR-21 „keine Löschung/kein Rückzug von Aufträgen“.
- **E: `older` als 409.** Verworfen (siehe oben): eine gleichzeitige Abschrift eines zweiten Geräts ist kein Fehler, und die App würde jeden 409 als „wiederholen“ behandeln.
- **F: Frist 10 Minuten oder anders?** Ein Auftrag dauert auf dem Gerät Millisekunden bis wenige Sekunden (`OrderExecutor` speichert selbst); die Zeit trägt vor allem die Netzstrecke und das App-Leben im Hintergrund. 10 Minuten liegt über einem Hintergrundfenster von iOS (meist unter 30 Sekunden) und unter dem, was ein Nutzer in Claude als „hängt“ wahrnimmt. Die Zahl ist eine Konstante und trägt nach einer Messung (S3) eine Änderung ohne Vertragsbruch.

## Risiken

- **Hängender Auftrag eines toten Geräts bis zur nächsten Abholung:** begrenzt durch die Rückholregel; wann das nächste Gerät fragt, bestimmt S3 (Start, Vordergrund) und S5 (Weckruf).
- **Doppelte Erfassung bei zurückgeholtem `capture`:** im Vertrag bekannt; nur bei gleichzeitigem Ausfall der Ergebnismeldung. Die Folge ist eine zusätzliche Aufgabe, nie ein Verlust, und der Nutzer sieht sie.
- **Fenster beim Zurückholen:** Meldet das alte Gerät sein Ergebnis in genau dem Moment, in dem `claim` den Auftrag zurückholt, kann ein Auftrag mit Ergebnis noch einmal ausgeliefert werden (Read Committed prüft eine Unterabfrage nicht erneut). Folge: das neue Gerät führt aus, der erwartete Stand ergibt `stale`, das Ergebnis des neuen Geräts ist `refused`, `getResult` zeigt das zuerst gespeicherte. Harmlos und nicht weiter verfolgt; AC-12 b belegt den Normalfall.
- **256 KiB reichen für sehr große Bestände nicht:** Eine Abschrift enthält nur offene Aufgaben (ohne Rohtext und Notiz), etwa 200 bis 300 Bytes je Aufgabe; die Grenze trägt rund 900 bis 1 300 offene Aufgaben. Bei Überschreitung antwortet der Dienst 413, und die App meldet es in S2/S3. Die Grenze ist eine Konstante in `app-routes.ts` plus eine Zeile in nginx (S1b).
- **Tür:** Die Wege laufen mit jeder gültigen App-Sitzung; `ALLOWED_APPLE_SUBS` lässt heute nur Hennings Konto zu. Eine Öffnung der Tür (#625) ändert diese Spec nicht.
- **Ausrollen:** Wie bei 615-3b/3c-2 gilt: Der Schnitt ändert den laufenden Dienst erst mit dem Ausrollen von Hand (`scripts/deploy-loose-ends.sh` auf `rennwienix`, fester Stand `LE_COMMIT`) und ist bis S1b von außen nicht erreichbar, weil nginx `/app/` nicht durchlässt (Allowlist: `/health`, `/mcp`, `/.well-known/`, `/oauth/`, `/auth/apple|logout|delete`). Die Wege bleiben damit bis S1b tot; kein Seiteneffekt für Claude, kein Seiteneffekt für Nutzer. Das Ausrollen ist ein eigener Schritt von Claude nach dem Merge; ein Ausrollen vor S1b ist unschädlich.

## Scope und Seiteneffekte

- Dateien: `server/src/app-routes.ts` (neu, ca. 100 Zeilen), `server/src/orders.ts` (ca. +12/−4: Konstante, `claimOrder` mit Rückholregel), `server/src/main.ts` (ca. +10: Import, `mountApp`, Tabelle), `server/test/app-routes.test.ts` (neu, ca. 330 Zeilen), `docs/reference/claude-abschrift-vertrag.md` (ca. +35), `CLAUDE.md` (ca. +6).
- Code-Dateien: 4 (`app-routes.ts`, `orders.ts`, `main.ts`, `app-routes.test.ts`), dazu zwei Textdateien; innerhalb der Grenze von 4–5 Dateien.
- **LoC ehrlich geschätzt:** Produktcode rund 125 (`app-routes.ts` 100, `orders.ts` 16, `main.ts` 10), Tests rund 330 (zwei Drittel Tabellen und Testaufbau), Doku rund 41. Summe rund 495, davon **Produktcode und Doku rund 165, Tests rund 330**; für die Grenze von `openspec.yaml` zählen rund 460 (`docs/` ist ausgenommen, `server/test/` nicht). Meldeschwelle: Liegen die Testzeilen nach RED über 380 oder der Endstand über 520, wird vor dem Weiterbauen erneut gefragt. Die Analyse schätzte +230 (davon ~120 Tests) und lag bei den Tests zu niedrig, weil die Ablehnungstabellen (AC-9, AC-10, AC-12) je Zeile eine Anfrage brauchen. Die 250-LoC-Grenze wird mit den Tests überschritten, ohne sie nicht. **Ansage für den PO nach Muster von #615 S2a (Überhang durch Sicherheitstests, angenommen):** Die Zeilen über der Grenze sind Tests der Sicherheitsränder (Anmeldung, Größe, Rückholen); ein Teilen der Datei würde nur den Testaufbau doppeln. Kippt der Teil des Überhangs nicht, schlägt die Spec vor, `AC-13` (gleichzeitig) und `AC-15` (keine Preisgabe) in einen zweiten Schnitt S1c zu verschieben (ca. −70 Zeilen), statt die Grenze zu erweitern.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, **keine Migration** (`claimed_at` besteht seit `001`), kein `generate`.
- Seiteneffekte außerhalb des Tickets: keiner nach außen (nginx lässt `/app/` nicht durch). Die einzige Verhaltensänderung für Bestehendes: `claimOrder` gibt auch zurückholbare Aufträge heraus; das berührt keinen heutigen Aufrufer (nur Tests rufen es, die App ruft den Dienst noch nirgends).

## Nicht in diesem Schnitt / Folgeschnitte

- **S1b nginx** (`henemm-infra`): `/app/` freigeben (Zone wie `loose_ends_auth`, 256k); Claude macht es selbst, vor S2.
- **S2 App-Client:** `ServiceClient.putTranscript/claimOrder/putResult`, Gerätekennung je Installation, `AccountState` gibt Aufruf mit Token.
- **S3 Auslöser `ClaudeSync`:** Senden und Holen in der App, A/B-Nachweis mit lokalem Dienst.
- **S4 Datenschutz:** Absatz „Abschrift“ und `PrivacyInfo.xcprivacy`, vor `LEAccountEnabled` an (#625).
- **S5 Weckruf:** stille Mitteilung (APNs), Gerätetoken-Weg im Dienst.
- Rückholen mit Zähler oder „Auftrag aufgegeben“ nach n Rückholungen: kein Bedarf belegt, nicht in S1.

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulator nötig. Nachweis: `./server/scripts/test-local.sh` grün (Wegwerf-Postgres, `npm run typecheck` und `npm test`) und `server.yml` auf dem PR grün (Linux, `postgres:18`).
- Ausrollen auf `rennwienix` wie bei 615-3c-2 als eigener Schritt von Claude (Beleg: `/health` 200 mit dem neuen Stand), nach dem Merge; kein Beleg aus dem öffentlichen Netz möglich, solange S1b aussteht.
- Stufe 3 entfällt. **Kein Pfad der Geräteliste berührt.**

## Definition of Done

- [ ] AC-1 bis AC-17 erfüllt (inkl. AC-4a)
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt `src/app-routes.ts`
- [ ] Vertragsdokument ergänzt (Wege der App, Rückholen), genau drei ```json-Blöcke
- [ ] #795 kommentiert (Stand S1, Folge S1b nginx), Board-Karte aktuell

## Known Limitations

Aus /60-validate (2026-11-11), am Code geprüft, keine Codeänderung:

- **AC-10(e), zu kleine `Content-Length`:** Der Server liest genau die behauptete Länge; der Überschuss ist für HTTP der Beginn der nächsten Anfrage. Ein 413 ist hier nicht möglich, die Antwort ist ein Nicht-2xx (Formprüfung oder Parserfehler) mit abgebrochener Verbindung. Der Test prüft „kein 2xx“ und am Ende die leere Datenbank; das ist die tragende Zusage („ohne dass Daten abgelegt werden“).
- **AC-15, Logger-Spion:** Während des absichtlich unerreichbaren Datenbankstarts aus AC-14(a) ist der Spion aus; `main.ts` meldet dort `migrate failed, retrying`. Aus den App-Wegen selbst kommt in keinem Fall eine Zeile.
- **AC-10(f) gegen AC-14(d):** 401 vor 413 gilt für die Grenze der Route (256 KiB, belegt mit 300 KiB). Über 1 MiB antwortet die globale Grenze des `bridge` mit 413 und `connection: close`, bevor eine Route oder Anmeldung läuft (bestehendes Verhalten seit #615 S3c-2).

## Changelog

- 2026-11-11: Entwurf (Schnitt S1 von #795)
- 2026-11-11: Known Limitations aus /60-validate
