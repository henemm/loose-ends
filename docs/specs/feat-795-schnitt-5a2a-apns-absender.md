---
entity_id: feat-795-schnitt-5a2a-apns-absender
type: feature
created: 2026-11-14
updated: 2026-11-14
status: draft
workflow: feat-795-s5a2-apns-absender
---

# Spec: APNs-Absender im Dienst, Schnitt S5a-2a (#795, Weckruf)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S5a-2a des Weckrufs; das Issue bleibt offen (`Refs #795`, nie `Closes #795`).
Analyse: `docs/context/feat-795-s5a2-apns-absender.md`; Gesamtplan und PO-Entscheidung (Variante A): `docs/context/feat-795-s5-weckruf.md`.
Vorgänger: `docs/specs/feat-795-schnitt-5a1-geraet-anmelden.md` (Speicher `device_tokens`, `POST /app/device`). Die Analyse teilt S5a-2 in 2a und 2b, weil beides zusammen die Grenze von 4–5 Dateien und ±250 LoC reißt. **Diese Spec deckt nur 2a ab.**

## Für den PO

Damit der Dienst ein Gerät später wecken kann, braucht er den Teil, der bei Apple anklopft: eine stille Mitteilung an die gemerkten Geräteadressen des Kontos, ohne Ton und ohne Anzeige. Dieser Schnitt baut diesen Teil als Baustein im Dienst, aber noch ohne Anschluss: nichts ruft ihn auf, es gibt noch keinen Schlüssel von Apple, und es wird nichts gesendet. Für dich sichtbar ändert sich nichts. Das Anschließen an die Aufträge und die Konfiguration folgen im nächsten Schnitt.

## Purpose

`server/src/apns.ts` (neu) liefert `apnsConfigFromEnv` (Konfiguration aus vier Variablen), den Anbieter-Token (ES256-JWT, gecacht), den Transport `node:http2` und `createWaker`, dessen `wake(account)` an alle gemeldeten Geräte eines Kontos eine stille APNs-Mitteilung schickt und ungültige Tokens löscht. `server/src/devices.ts` bekommt `listTokens` und `dropToken`. **Von nichts aufgerufen:** weder `mcp.ts` noch `main.ts` noch `orders.ts` werden berührt, es gibt keinen echten Apple-Aufruf (der Schlüssel kommt erst in S5b). **Regeln vor Modell:** Protokoll- und Betriebsarbeit, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — der Schnitt setzt den Zuschnitt aus der Spec von S5a-1 und die PO-Entscheidung vom 2026-11-13 (Variante A) um; ADR-21 (Weg B) bleibt unverändert, keine bestehende Entscheidung fiele.
- **Rationale:** (1) Ein Anbieter-Token je Prozess, gecacht: Apple verlangt Wiederverwendung (frühestens nach 20, spätestens nach 60 Minuten erneuern; sonst 429 `TooManyProviderTokenUpdates` bzw. 403 `ExpiredProviderToken`); es läuft genau ein Dienst-Prozess. (2) Eine HTTP/2-Sitzung je Senden statt einer Dauerverbindung: wenige Weckrufe je Stunde, einfach und robust. (3) `wake` wirft nie, damit ein späteres `void wake()` keine unbehandelte Ablehnung erzeugt, die Node beendet.

## Source

**Files:** `server/src/apns.ts` (neu), `server/src/devices.ts`, `server/test/apns.test.ts` (neu), `CLAUDE.md` (Abschnitt `server/`, höchstens eine Zeile)
**Identifier:** `apnsConfigFromEnv`, `createWaker`, `listTokens`, `dropToken`

### Schnittstelle `server/src/apns.ts`

- `apnsConfigFromEnv(env = process.env): ApnsConfig | undefined`. `ApnsConfig` = `{ teamId, keyId, privateKey: KeyObject, topic }`. Gelesen werden `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY` (PEM, `\n` als Text wird zu Zeilenumbruch wie bei `APPLE_PRIVATE_KEY`) und `APNS_TOPIC`. Keine der vier gesetzt (fehlend oder nur Leerraum) → `undefined` (kein Weckruf). Alle vier gesetzt und gültig → Config. Teilweise gesetzt oder ungültig (Schlüssel nicht lesbar oder keine EC-P-256-Schlüssel, `createPrivateKey` schon hier) → `Error`, dessen Text **nur den Variablennamen** nennt, nie den Wert (Muster `loadAppleConfig`). Das Beenden von `main()` mit dieser Meldung ist **nicht** Teil dieses Schnitts (2b).
- **Anbieter-Token:** ES256-JWT, Kopf `{alg: "ES256", kid: keyId}`, Inhalt `{iss: teamId, iat}` (Sekunden), Signatur `sign("sha256", …, { dsaEncoding: "ieee-p1363" })` wie `clientSecret` in `apple-client.ts`. Die Uhr (`now: () => number`, Millisekunden) wird hineingereicht. Der Token liegt je Waker im Prozess im Cache mit dem Zeitpunkt seiner Ausstellung `issuedAt`. Regel: Ein Token wird erneuert, wenn er **mindestens 50 Minuten** alt ist; **nie früher als 20 Minuten** nach `issuedAt`, mit einer einzigen Ausnahme: Antwortet APNs 403 mit Grund `ExpiredProviderToken`, wird genau **einmal** mit dem Token wiederholt, den der Cache dann hält. Hat ein anderer Sendevorgang den Token inzwischen schon erneuert (der Cache hält einen anderen als den abgelehnten), wird er ohne Erneuerung benutzt. Hält der Cache noch den abgelehnten Token, wird nur erneuert, wenn er mindestens 20 Minuten alt ist; ist er jünger, gibt es **keinen** Wiederholversuch und der Versuch zählt als Fehlschlag (`apns send failed`, nichts gelöscht). Mehr als ein Wiederholversuch je Gerät und `wake` gibt es nie.
- **Transport** (`node:http2`, keine neue Abhängigkeit): `sendHttp2(request)` öffnet je Aufruf eine Sitzung zum Ursprung, sendet, schließt die Sitzung im `finally`, hört mit `session.on("error")` (ein Sitzungsfehler wird zum abgelehnten Aufruf, nie zum unbehandelten Ereignis) und bricht nach 5 s ab (Zeitlimit zählt als Netzfehler). Ursprung je Umgebung: `sandbox` → `https://api.sandbox.push.apple.com`, `production` → `https://api.push.apple.com`, überschreibbar über die Option `origins` (für Tests). Die Antwort ist `{ status: number, reason?: string }`; `reason` ist das Feld `reason` im JSON-Körper der Antwort, sonst fehlend.
- **Anfrage:** `POST /3/device/<token>` mit den Köpfen `authorization: bearer <JWT>`, `apns-topic: <topic>`, `apns-push-type: background`, `apns-priority: 5`, `content-type: application/json`; Körper genau `{"aps":{"content-available":1},"looseends":{"v":1}}`.
- `createWaker({ config, pool, send?, now?, log? }): { wake(account: string): Promise<void> }`. `send` ist die hineinreichbare Sendefunktion (Standard `sendHttp2`; Tests geben einen Stub). `log(event: string)` bekommt nur feste Ereignisnamen. `wake` liest `listTokens(pool, account)`, sendet an **alle** Geräte parallel (`Promise.allSettled`), und löscht per `dropToken` bei 410 `Unregistered`, 400 `BadDeviceToken` und 400 `DeviceTokenNotForTopic`; jede andere Antwort (2xx ausgenommen: Erfolg, stumm) und jeder Fehler (5xx, 429, andere 4xx, Netz, Zeitlimit) wird nur als `apns send failed` geloggt und löscht nichts. **`wake` wirft und rejected nie**, auch nicht bei Datenbankfehler, fehlerhaftem `send` oder fehlerhaftem `log`.
- **Log:** nur die festen Namen `apns send failed`, `apns token dropped`, `apns jwt failed` (der Token konnte nicht erzeugt werden, kein Senden); nie Token, Konto, Gerät, Apple-Grund oder Fehlertext.

### Schnittstelle `server/src/devices.ts` (zwei Funktionen dazu)

- `listTokens(pool, account): Promise<{ token: string; environment: "sandbox" | "production" }[]>`: alle Zeilen des Kontos, Reihenfolge `device` aufsteigend; ein anderes Konto liefert nie Zeilen. Datenbankfehler werden nicht gefangen.
- `dropToken(pool, token, environment): Promise<boolean>`: löscht nur die Zeile, bei der **Token und Umgebung** beide passen, und meldet, ob eine Zeile gelöscht wurde. Befund aus `server/migrations/008_device_tokens.sql`: `UNIQUE (token)` gilt über alle Konten, ein Token trifft also höchstens eine Zeile; die Umgebung im `WHERE` schützt trotzdem eine Zeile, die zwischen Senden und Löschen mit demselben Token in anderer Umgebung oder mit einem neuen Token neu gemeldet wurde (`putDevice` überschreibt die Zeile des Geräts): sie bleibt stehen. Das Token wird in Kleinschreibung verglichen (so legt `putDevice` es ab).

### Festlegungen

1. **Nichts verdrahtet:** `mcp.ts`, `main.ts`, `orders.ts`, `app-routes.ts`, `.github/`, `project.yml`, jede Swift-Datei und jedes Dokument unter `docs/reference/` bleiben unverändert (2b).
2. **`BadDeviceToken`** heißt oft nur „falsche Umgebung“; Löschen ist trotzdem richtig, weil die App ihr Token samt Umgebung bei jedem Start neu meldet (S5c).
3. **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; keine neuen Pakete.
4. **Kein echter Apple-Aufruf** in Tests und beim Ausrollen; der echte Weg gegen Apple wird erst in S5b belegt.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `node:crypto` (`createPrivateKey`, `sign`), `node:http2` | Node-Bordmittel, **keine neuen Pakete** |
| `device_tokens` (Migration 008), `putDevice` | bestehend, unverändert |
| Muster `loadAppleConfig` (`apple.ts`), `clientSecret` (`apple-client.ts`) | Vorlage, unverändert |
| `server/test/db.ts` (`freshPool`), `migrate`, `findOrCreate` | bestehend, unverändert |
| `node:test`, `pg` | bestehend |
| Upstream (erst S5b) | APNs HTTP/2 und ein .p8-Schlüssel mit APNs-Recht |
| Downstream | S5a-2b (Einhängen, Konfiguration, Vertrag), S5b, S5c |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| server/src/apns.ts | CREATE | Konfiguration, Anbieter-Token, Transport, `createWaker` |
| server/src/devices.ts | MODIFY | `listTokens`, `dropToken` |
| server/test/apns.test.ts | CREATE | Tests gegen Wegwerf-Postgres, Stub-Sender, h2c-Testserver |
| CLAUDE.md | MODIFY | höchstens eine Zeile im Abschnitt `server/` zu `src/apns.ts` (reine Doku) |

### Estimated Changes

- Dateien: 3 Code-Dateien (+ `CLAUDE.md` als Doku), innerhalb von 4–5.
- Produktcode ~+120 LoC (`apns.ts` ~100, `devices.ts` ~20); Tests ~+170 LoC. **Tests getrennt gezählt wie in S5a-1**: Sicherheits- und Protokolltests (Token-Regeln, Löschregeln, Rahmung) lassen sich nicht kürzen, ohne dass der Absender ungeprüft bliebe; ohne Tests liegt der Schnitt weit unter der Grenze. Mit Tests (~290 + 3 Zeilen Doku) liegt er über ±250; diese Zählweise ist die Tech-Lead-Entscheidung, die bei S5a-1 und #615 S2a schon angenommen wurde. Meldeschwelle: Liegt der Produktcode nach dem Bauen über 150 LoC oder `apns.test.ts` über 200 Zeilen, wird vor dem Weiterbauen neu geteilt.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Migration, keine Oberfläche, keine neuen Pakete, kein `generate`.

## Implementation Details

Aufbau und Signaturen wie oben. Die Sendefunktion hat die Form `send(request) → Promise<{ status, reason? }>` mit `request = { origin, token, jwt, topic, body }`, damit Stub-Tests Kopfzeilen, Körper und Ursprung prüfen können, ohne Netz; `sendHttp2` setzt daraus die Köpfe des Abschnitts „Anfrage“. `wake` ist ganz in `try/catch` gewickelt (auch `listTokens`, `log`), und jede Einzelsendung in ihrem eigenen `try/catch` innerhalb von `Promise.allSettled`. Der Anbieter-Token wird nur über eine Funktion `providerToken(now, rejected?)` bezogen, die die Regel „50 min, nie unter 20 min, ein Wiederholversuch“ an einer Stelle hält; scheitert die Erzeugung, wird `apns jwt failed` geloggt und nicht gesendet.

## Test Plan

Alle Tests mit `node:test` und `node:assert/strict` in `server/test/apns.test.ts`, gegen das Wegwerf-Postgres (`freshPool`, `migrate`, Konten mit `findOrCreate`, Zeilen mit `putDevice`; Muster `devices.test.ts`). Schlüssel werden im Test mit `generateKeyPairSync("ec", { namedCurve: "prime256v1" })` erzeugt. Fester Uhrenstand über hineingereichtes `now`. Kein Netz außer dem lokalen h2c-Server (AC-11). Tabellengetrieben, ein Fall je Zeile. Kein bestehender Testfall ändert sich.

### Automated Tests (TDD RED)

- [ ] GIVEN `apns.ts` und die zwei neuen Funktionen existieren nicht WHEN `server/test/apns.test.ts` läuft THEN schlagen alle Tests beim Import fehl (RED).
- [ ] Test „apns: config alles oder nichts“ (AC-1, AC-2)
- [ ] Test „apns: anbieter-jwt“ (AC-3)
- [ ] Test „apns: jwt cache und erneuerung“ (AC-4)
- [ ] Test „apns: expiredprovidertoken genau ein wiederholversuch“ (AC-5)
- [ ] Test „apns: anfrage kopfzeilen und koerper“ (AC-6)
- [ ] Test „apns: ungueltige tokens loeschen“ (AC-7)
- [ ] Test „apns: andere fehler loeschen nichts“ (AC-8)
- [ ] Test „apns: wake wirft nie“ (AC-9)
- [ ] Test „apns: log nur feste namen“ (AC-10)
- [ ] Test „apns: http2 rahmung“ (AC-11)
- [ ] Test „apns: listtokens und droptoken“ (AC-12)
- [ ] AC-13: kein Test (Beleg in `/60-validate`, Schnitt 2b verdrahtet absichtlich)
- [ ] AC-14: kein Test (Dateigrenze, Beleg in `/60-validate`)

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Acceptance Criteria

- **AC-1:** Konfiguration, Fälle ohne Fehler: GIVEN eine Umgebung ohne `APNS_*` (auch nur Leerraum) WHEN `apnsConfigFromEnv` THEN `undefined`; GIVEN alle vier Variablen gültig (Schlüssel als PEM, auch mit `\n` als Text) THEN eine Config mit `teamId`, `keyId`, `topic` und einem `KeyObject` vom Typ `ec`. Test: „apns: config alles oder nichts“.
- **AC-2:** Konfiguration, Fehlerfälle: GIVEN jede echte Teilmenge der vier Variablen (je eine fehlt) und je ein ungültiger Schlüssel (kein PEM, RSA-Schlüssel, andere EC-Kurve) WHEN `apnsConfigFromEnv` THEN wirft es einen `Error`, dessen Text genau den Namen der fehlenden oder ungültigen Variable enthält und weder den Wert des Schlüssels noch von Team, Schlüssel-ID oder Topic. Test: „apns: config alles oder nichts“.
- **AC-3:** Anbieter-Token: GIVEN eine Config und eine feste Uhr WHEN der erste Sendevorgang eines Wakers den Token erzeugt THEN hat der `authorization`-Kopf der Anfrage die Form `bearer <Kopf>.<Inhalt>.<Signatur>`, der Kopf ist `{alg: "ES256", kid: <keyId>}`, der Inhalt `{iss: <teamId>, iat: <Sekunden der Uhr>}` ohne weitere Schlüssel, und die Signatur ist 64 Byte lang (`ieee-p1363`) und prüft mit dem öffentlichen Schlüssel (`verify` mit `dsaEncoding: "ieee-p1363"`). Test: „apns: anbieter-jwt“.
- **AC-4:** Cache und Erneuerung: GIVEN ein Waker und eine verstellbare Uhr WHEN mehrere `wake`-Aufrufe bei +0, +19 und +49 Minuten laufen THEN tragen alle denselben Token (gleicher `iat`); WHEN ein Aufruf bei +50 Minuten läuft THEN trägt er einen neuen Token (`iat` = Zeit der Uhr), und der nächste Aufruf bei +60 Minuten (10 Minuten später) trägt wieder diesen neuen Token. Test: „apns: jwt cache und erneuerung“.
- **AC-5:** `ExpiredProviderToken`: GIVEN ein Stub, der beim ersten Versuch 403 mit `reason: "ExpiredProviderToken"` antwortet WHEN (a) der Cache-Token mindestens 20 Minuten alt ist THEN genau ein Wiederholversuch mit einem **neu erzeugten** Token (anderer `iat`), bei Erfolg des zweiten Versuchs nichts gelöscht und nichts geloggt; WHEN (b) der Cache-Token jünger als 20 Minuten ist THEN **kein** Wiederholversuch (genau ein `send`-Aufruf), `apns send failed` einmal, nichts gelöscht; WHEN (c) zwei Geräte gleichzeitig 403 `ExpiredProviderToken` bekommen und der Token mindestens 20 Minuten alt ist THEN wird er genau einmal erneuert und beide Wiederholversuche tragen denselben neuen Token; WHEN (d) auch der Wiederholversuch 403 `ExpiredProviderToken` antwortet THEN gibt es keinen dritten Versuch (je Gerät höchstens zwei `send`-Aufrufe), `apns send failed`, nichts gelöscht. Test: „apns: expiredprovidertoken genau ein wiederholversuch“.
- **AC-6:** Anfrage: GIVEN ein Konto mit je einem Gerät in `sandbox` und `production` und ein Stub-`send` WHEN `wake(account)` THEN bekommt der Stub genau zwei Aufrufe, einen mit Ursprung `https://api.sandbox.push.apple.com` und einen mit `https://api.push.apple.com`, jeweils mit dem Token der Zeile (Pfad `/3/device/<token>`), dem Topic der Config und dem Körper, der als JSON genau `{"aps":{"content-available":1},"looseends":{"v":1}}` entspricht; die Köpfe, die `sendHttp2` setzt, sind `apns-push-type: background`, `apns-priority: 5`, `content-type: application/json` (belegt in AC-11). Test: „apns: anfrage kopfzeilen und koerper“.
- **AC-7:** Ungültige Tokens löschen: GIVEN ein Konto mit mehreren Geräten WHEN der Stub für ein Gerät 410 `Unregistered`, für ein zweites 400 `BadDeviceToken`, für ein drittes 400 `DeviceTokenNotForTopic` und für ein viertes 200 antwortet THEN sind die ersten drei Zeilen in `device_tokens` weg, die vierte und die Zeilen anderer Konten bleiben; je gelöschtem Token wird `apns token dropped` geloggt. Test: „apns: ungueltige tokens loeschen“.
- **AC-8:** Alles andere löscht nichts: GIVEN je ein Gerät WHEN der Stub antwortet mit 500, 503, 429, 403 mit anderem Grund, 400 mit anderem Grund (z. B. `PayloadEmpty`), 410 ohne `reason`, 400 ohne `reason`, einem abgelehnten Aufruf (Netzfehler) oder einem Zeitlimit-Fehler THEN bleibt jede Zeile in `device_tokens` stehen und je Fall wird `apns send failed` genau einmal geloggt; ein Gerät mit 200 wird nicht geloggt. Ein Fehler eines Geräts hindert das Senden an die anderen nicht (alle Geräte werden angefragt). Test: „apns: andere fehler loeschen nichts“.
- **AC-9:** `wake` wirft nie: GIVEN (a) ein Pool, dessen `query` wirft, (b) ein `send`, das synchron wirft, (c) ein `send`, das ablehnt, (d) ein `log`, das wirft, (e) ein Konto ohne Geräte, (f) ein Anbieter-Token, das nicht erzeugt werden kann (Uhr liefert `NaN`) WHEN `await wake(account)` THEN resolved es jeweils ohne Fehler, es gibt keine unbehandelte Ablehnung (Handler auf `process.on("unhandledRejection")` bleibt leer), bei (e) wird `send` nie aufgerufen, bei (f) wird `apns jwt failed` geloggt und `send` nie aufgerufen. Test: „apns: wake wirft nie“.
- **AC-10:** Log: GIVEN alle Fehler- und Löschfälle aus AC-5 bis AC-9 mit Tokens, Konto-ID und Apple-Gründen als erkennbaren Wörtern WHEN `wake` läuft THEN ist jede an `log` übergebene Zeichenkette genau eine von `apns send failed`, `apns token dropped`, `apns jwt failed`, und keine geloggte Zeichenkette enthält ein Token, die Konto-ID, den Grund der Antwort oder einen Fehlertext; zusätzlich bleibt `console.error`/`console.log` (Spion) über den ganzen Lauf leer. Test: „apns: log nur feste namen“.
- **AC-11:** Transport, Rahmung: GIVEN ein lokaler `node:http2`-Server ohne TLS (h2c, über die Option `origins` als Ursprung für beide Umgebungen) WHEN `sendHttp2` eine Anfrage sendet THEN sieht der Server Methode `POST`, Pfad `/3/device/<token>`, die Köpfe `authorization`, `apns-topic`, `apns-push-type: background`, `apns-priority: 5` und den Körper wie in AC-6, und die Antwort `{status, reason}` entspricht dem Status und dem `reason` im JSON-Körper der Serverantwort (ohne Körper: kein `reason`); WHEN der Server nie antwortet THEN lehnt der Aufruf nach dem Zeitlimit ab (Test mit einem kurzen, über eine Option gesetzten Limit) und der Server sieht danach keine offene Sitzung; WHEN der Server die Sitzung hart schließt THEN lehnt der Aufruf ab, ohne unbehandeltes Ereignis. TLS wird nicht geprüft; der echte Weg gegen Apple folgt in S5b. Test: „apns: http2 rahmung“.
- **AC-12:** Gerätetokens lesen und löschen: GIVEN zwei Konten mit Geräten WHEN `listTokens(pool, A)` THEN genau die Zeilen von A als `{token, environment}`, nach `device` aufsteigend, keine von B, leere Liste für ein Konto ohne Geräte; WHEN `dropToken(pool, token, environment)` mit passender Umgebung THEN `true` und genau diese Zeile ist weg; WHEN die Umgebung nicht passt, das Token unbekannt ist oder das Gerät das Token inzwischen mit `putDevice` gegen ein neues getauscht hat THEN `false` und `device_tokens` ist unverändert; ein großgeschriebenes Token trifft die Zeile ebenfalls. Test: „apns: listtokens und droptoken“.
- **AC-13:** Nichts verdrahtet: `server/src/mcp.ts`, `server/src/main.ts`, `server/src/orders.ts` und `server/src/app-routes.ts` enthalten die Zeichenfolge `apns` nicht, und keine Datei in `server/src/` außer `apns.ts` importiert `./apns.ts`. **Kein dauerhafter Test**, weil Schnitt 2b genau diese Verdrahtung herstellt und der Test dort wieder fallen müsste: Beleg einmalig in `/60-validate` per `grep -il apns server/src/*.ts` (Ausgabe genau `server/src/apns.ts`) im Validierungsprotokoll.
- **AC-14:** Grenze und Länge: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/apns.ts`, `server/src/devices.ts`, `server/test/apns.test.ts` und höchstens `CLAUDE.md`; `mcp.ts`, `main.ts`, `orders.ts`, `app-routes.ts`, `.github/`, `project.yml`, `server/package.json` und jede Swift-Datei sind unverändert (keine neue Abhängigkeit); jede Funktion hat höchstens 50 Zeilen. **Kein dauerhafter Test** (ein Test gegen `origin/main` scheitert im flachen CI-Checkout): Beleg einmalig in `/60-validate`, Befehl, Ausgabe und Funktionslängen im Validierungsprotokoll (festes Vorgehen seit S1 AC-17, Ausnahme vom Tech Lead bestätigt).

## Alternativen

- **Abfrager statt direktem Weckruf:** ein Zeitgeber prüft `orders` auf neue Zeilen (Spalte „geweckt“, Migration) oder Postgres `LISTEN/NOTIFY` mit Trigger (eigene Dauerverbindung, Wiederverbinden). Entkoppelter, aber mehr Teile und Verzögerung; bei einem Prozess und wenigen Weckrufen je Stunde ohne Gewinn. Verpasste Weckrufe nach einem Absturz fängt der Abruf der App beim nächsten Vordergrund ab. Es fiele **keine ADR**, nur der Zuschnitt aus der Spec von S5a-1; nicht gebaut.
- **`fetch` statt `node:http2`:** weniger Code, aber Nodes eingebautes `fetch` (gebündeltes undici) handelt HTTP/2 nicht zuverlässig aus, APNs verlangt HTTP/2 (undici#2750, Beispiel `api.sandbox.push.apple.com`); ein HTTP/2-Dispatcher in undici wäre eine zusätzliche Abhängigkeit oder Experiment. Verworfen; ebenfalls keine ADR.
- **Eine Dauersitzung je Umgebung statt je Senden:** spart den Verbindungsaufbau, braucht aber Wiederverbinden, Leerlauf und Zustand; bei wenigen Weckrufen je Stunde ohne Gewinn. Nicht gebaut.
- **Ganz ohne Weckruf (Abruf beim Öffnen, Variante B/C):** vom PO zugunsten Variante A verworfen.

## Risiken

- **Falsche Umgebung löscht gültige Zeilen:** `BadDeviceToken` bei Sandbox-Token an Produktion löscht die Zeile; richtig, solange die App bei jedem Start neu meldet (S5c, Festlegung 2). Verzögert sich S5c, fehlt der Weckruf bis zum nächsten Start. Hier kein Sendebetrieb, also kein Schaden.
- **Prüfbau** (`com.henning.looseends.probe`) bekäme `DeviceTokenNotForTopic` und würde gelöscht; Kreislauf aus Melden und Löschen möglich; akzeptiert, in S5c prüfen.
- **h2c-Test prüft nur die Rahmung, nicht TLS;** der echte Weg gegen Apple wird erst in S5b belegt.
- **Zwei Aufträge kurz hintereinander = zwei Weckrufe;** harmlos, kein Bündeln.
- **Hotspot:** `CLAUDE.md` wird von parallelen Sitzungen berührt; vor dem PR `origin/main` einmischen.

## Nicht im Umfang / Folgeschnitt

- **S5a-2b (Einhängen):** `mcp.ts` (`mcpHandler(pool, { wake? })`, ein Helfer statt der zwei `putOrder`-Aufrufe, `void wake(owner)` nur bei `stored`, nie bei `duplicate`), `main.ts` (`apnsConfigFromEnv` in `main()`, Exit 1 mit `apns config invalid: <var>` vor Pool und Port, `StartOptions.apns`, Waker in `start()`), Tests dazu (stored weckt, duplicate nicht, Weckruf-Fehler stört den Auftrag nicht, halbe Konfiguration bricht ab), der Vertragsabsatz zum Weckruf in `docs/reference/claude-abschrift-vertrag.md` (ohne neuen ```json-Block) und die endgültige Zeile in `CLAUDE.md`. Keines der ACs oben hängt davon ab.
- **S5b:** nginx, neuer APNs-Schlüssel im Portal (Henning meldet sich nur an), Geheimnisse auf `rennwienix`, Ausrollen, erster echter Apple-Aufruf.
- **S5c:** App meldet Token samt Umgebung, erkennt den Weckruf am Schlüssel `looseends`; Vorbedingung Datenschutztext (Spec S5a-1, Festlegung 7).

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulator nötig. Nachweis: `./server/scripts/test-local.sh` grün (Wegwerf-Postgres, `npm run typecheck` und `npm test`) und `server.yml` auf dem PR grün. Kein echter Apple-Aufruf.
- Ausrollen ist unschädlich (der Baustein ist von nichts aufgerufen) und folgt mit S5a-2b.
- Stufe 3 entfällt. **Kein Pfad der Geräteliste berührt.**

## Definition of Done

- [ ] AC-1 bis AC-14 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] #795 kommentiert (Stand S5a-2a, Folge S5a-2b), Board-Karte aktuell

## Changelog

- 2026-11-14: Initial spec created (Schnitt S5a-2a von #795, Teilung von S5a-2)
- 2026-11-14 (TDD RED): Die Tests legen die Namen fest, die die Spec offen ließ: Typen `ApnsConfig`, `ApnsRequest` (`{ origin, token, jwt, topic, body }`, `body` als JSON-Text, `jwt` ohne `bearer`), `ApnsResponse` (`{ status, reason? }`); `sendHttp2(request, { timeoutMs? })` (Standard 5 s); `createWaker({ …, origins?: { sandbox, production } })`. `apns jwt failed` darf je Gerät oder je `wake` geloggt werden (AC-9 f mit einem Gerät: genau einmal). Meldeschwelle: `apns.test.ts` hat 227 Zeilen statt höchstens 200, weil AC-8/AC-10 zusätzlich `403 ExpiredProviderToken` bei frischem Token prüfen und AC-11 den Weg über `origins` mit dem echten Transport durchspielt; die Tests sind schon dicht, Kürzen hieße Fälle streichen. Tech-Lead-Entscheidung wie bei S5a-1 und #615 S2a: angenommen, kein Neuschnitt; die Schwelle für den Produktcode (150 LoC) gilt unverändert.
