---
entity_id: feat-795-schnitt-5a1-geraet-anmelden
type: feature
created: 2026-11-13
updated: 2026-11-13
status: draft
workflow: feat-795-s5-weckruf
---

# Spec: Gerät beim Dienst anmelden, Schnitt S5a-1 (#795, Weckruf)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S5a-1 des Weckrufs; das Issue bleibt offen (`Refs #795`, nie `Closes #795`).
Analyse: `docs/context/feat-795-s5-weckruf.md` (Abschnitt „Technical Approach (Entscheidung PO: A)“). Die Analyse plante S5a „Dienst“ als einen Schnitt; das sprengt die Grenze von 4–5 Dateien und ±250 LoC (Servertests zählen mit). Entscheidung des Tech Leads: S5a wird geteilt.
Vorgänger: `docs/specs/feat-795-schnitt-1-dienst-wege.md` (Muster der App-Wege, `admitted`, `jsonBody`, `gated`), `docs/specs/feat-615-schnitt-3c1-konto-loeschen.md` (`deleteAccount`).

## Für den PO

Damit der Dienst ein Gerät später per stiller Mitteilung wecken kann, muss er die Adresse kennen, unter der Apple dieses Gerät erreicht (das „Gerätetoken“). Dieser Schnitt baut im Dienst nur die Tür dafür: Die App kann dem Dienst die Adresse ihres Geräts melden, der Dienst merkt sie sich je Konto und Gerät. Gesendet wird noch nichts, und die App ruft die Tür noch nicht an; auch von außen bleibt sie zu, bis der Server davor sie in einem späteren Schnitt freigibt. Löscht jemand sein Konto, verschwinden diese Adressen mit. Für dich sichtbar ändert sich nichts. Eine Sache, die du später entscheidest: Der Datenschutztext nennt diese Adresse noch nicht; die App darf sie erst senden, wenn der Text und die Website-Seite sie nennen (Festlegung 7).

## Purpose

`server/migrations/008_device_tokens.sql` (neu) legt die Tabelle `device_tokens` an. `server/src/devices.ts` (neu) prüft die Meldung (`checkDevice`) und legt sie ab (`putDevice`). `server/src/app-routes.ts` bekommt den vierten Weg `POST /app/device`. Aufgaben: das Token je Konto und Gerät halten, ein umgezogenes Token dem neuen Besitzer geben, die Zahl der Geräte je Konto begrenzen (damit ein Auftrag später höchstens zehn Weckrufe auslöst). Kein Senden, keine `APNS_*`-Konfiguration, kein `apns.ts` (S5a-2). **Regeln vor Modell:** Protokoll- und Betriebsarbeit, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Quelle (aus der Analyse, 2026-11-13): Apple legt die Länge des Gerätetokens nicht fest und warnt vor einer festen Annahme (Apple-Dokumentation „Registering your app with APNs“); darum prüft der Dienst nur Hex, gerade Länge und eine weite Spanne (64 bis 200 Zeichen). Ein Token gehört einem Gerät und einer Umgebung (Sandbox für Xcode-Läufe, Produktion für TestFlight und Store); der Dienst muss beides je Token kennen, weil Apple für jede Umgebung einen eigenen Server hat.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-21 — Weg B (Dienst zwischen Claude und App); der Weckruf ist eine Ergänzung nach PO-Entscheidung vom 2026-11-13 (Variante A, echter Weckruf per stiller APNs-Mitteilung, statt der empfohlenen Variante B). Dieser Schnitt ändert die Entscheidung nicht.
- **Rationale:** (1) Das Token hängt an `(account_id, device)`, nicht an der Sitzung: die Sitzung kennt kein Gerät, `X-Device` ist die Kennung der Installation (S1). (2) Ein Token gehört genau einem Konto und Gerät (`UNIQUE (token)`): meldet sich dasselbe Gerät nach einem Kontowechsel mit einem anderen Konto, zieht das Token um, statt dass der alte Besitzer weiter geweckt wird. (3) Die Grenze von 10 Geräten je Konto begrenzt Aufwand und Missbrauch an einer Stelle, die ohnehin geprüft werden muss. (4) Kein Weg „Gerät abmelden“: die App holt nur mit Konto; ein Weckruf an ein abgemeldetes Gerät bewirkt nichts.

## Source

**Files:** `server/migrations/008_device_tokens.sql` (neu), `server/src/devices.ts` (neu), `server/src/app-routes.ts`, `server/test/devices.test.ts` (neu), `server/test/app-routes.test.ts`, `server/test/accounts.test.ts`, `server/test/schema.test.ts` (die drei nur mechanisch: Pfad- bzw. Migrationsliste), `docs/reference/claude-abschrift-vertrag.md`, `CLAUDE.md` (Abschnitt `server/`)
**Identifier:** `device_tokens`, `checkDevice`, `putDevice`, `MAX_DEVICES`, `POST /app/device`

### Migration 008

Im Stil von `002` bis `007` (kein `BEGIN`/`COMMIT`, der Läufer wickelt die Datei in eine Transaktion):

```text
CREATE TABLE device_tokens (
  account_id  text        NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  device      text        NOT NULL,
  token       text        NOT NULL,
  environment text        NOT NULL CHECK (environment IN ('sandbox', 'production')),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, device),
  UNIQUE (token)
);
```

`account_id` ist `text`, weil `accounts.id` `text` ist (UUID in Textform, `002_accounts.sql`). `device` ist die UUID in Kleinschreibung (die Prüfung der Form geschieht an der Tür, wie bei `orders.claimed_by`), `token` Hex in Kleinschreibung.

### Schnittstelle `server/src/devices.ts`

- `checkDevice(doc: unknown): asserts doc is DeviceDoc`: das Dokument ist ein Objekt mit **genau** den Schlüsseln `token` und `environment`, sonst `FormError`. `token`: Text aus Hex-Ziffern (`0-9a-fA-F`), gerade Länge, **64 bis 200 Zeichen**, Groß- und Kleinschreibung beliebig. `environment`: genau `"sandbox"` oder `"production"`. Fehlerklasse und Muster wie `checkTranscript`/`checkResult` (`FormError`, Pfad und Grund in der Meldung); die Meldung verlässt den Dienst nie und nennt nie den Wert des Tokens.
- `putDevice(pool, account, device, doc): Promise<void>`: eine Transaktion. (a) Eine Zeile mit demselben Token (in Kleinschreibung) unter einem **anderen** `(account_id, device)` wird gelöscht (das Token ist umgezogen). (b) Upsert auf `(account_id, device)` mit dem Token in Kleinschreibung, der Umgebung und `updated_at = now()`. (c) Hat das Konto danach mehr als `MAX_DEVICES = 10` Zeilen, werden die ältesten gelöscht (Reihenfolge der Auswahl: `updated_at` aufsteigend, dann `device` aufsteigend), bis 10 übrig sind; die eben geschriebene Zeile bleibt dabei immer stehen. Fehler der Datenbank werden nicht gefangen; bei einem Fehler wird zurückgerollt.

### Der Weg `POST /app/device`

Genau das Muster der drei Wege (S1), Reihenfolge der Prüfungen: Methode (nicht `POST` → **405** mit `allow: POST`), Sitzung (**401**), `X-Device` **Pflicht** und eine UUID (**400**), Inhaltstyp `application/json` (**415**), Körper höchstens 256 KiB, beim Lesen gezählt (**413**), JSON und Form über `checkDevice` (**400** ohne Körper). Dann `putDevice(pool, account, device, doc)` → **204** ohne Körper. Jede Antwort trägt `cache-control: no-store`, jede Ablehnung hat keinen Körper. Datenbankfehler werden nicht gefangen, `dispatch` in `main.ts` macht daraus 500 ohne Körper. Im Code sind das etwa sechzehn Zeilen: eine Funktion `register` neben `claim`/`result` und ein Eintrag in `appRoutes`.

**Einhängen (geprüft):** `appRoutes` liefert die Pfade, `mountApp` in `main.ts` (Zeile 144) hängt jeden Eintrag von `appRoutes({ pool })` mit `gated(isReady, …)` ein. Der neue Pfad ist damit ohne Änderung an `main.ts` gesperrt (503 ohne Körper vor `migrate`), und `/health` und `/mcp` bleiben unüberschreibbar. `main.ts` bleibt unverändert.

### Festlegungen

1. **Abmelden** (`POST /auth/logout`) entfernt den Eintrag nicht: die Sitzung kennt kein Gerät. Ein späterer Weckruf an ein abgemeldetes Gerät bewirkt nichts, weil die App nur mit Konto holt.
2. **Konto löschen** entfernt alle Einträge des Kontos: **Befund:** `deleteAccount` löscht `order_results`, `orders`, `transcripts` und `oauth_records` einzeln und danach die Zeile in `accounts`; Sitzungen und Apple-Tokens folgen der Fremdschlüssel-Kaskade. `device_tokens.account_id` hängt mit `ON DELETE CASCADE` an `accounts`, also genügt die Kaskade; **`accounts.ts` bleibt unberührt.** Ein Test belegt es (AC-8).
3. **Stille:** keine neue Logzeile; weder Token noch Gerät noch Konto verlassen den Dienst in einer Meldung oder Antwort.
4. **Von außen** bleibt `/app/device` 404, bis nginx den Pfad in S5b durchlässt; die App ruft ihn erst in S5c. Der Vertrag „Wege der App“ bekommt den vierten Weg (siehe AC-10).
5. **Mengengrenze:** Die Zeile „Mengengrenze (#795 S1b)“ im Vertrag nennt dann vier Wege; die nginx-Zone dafür legt S5b fest.
6. **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; keine neuen Pakete.
7. **Datenschutz (Befund und Vorbedingung):** `docs/reference/datenschutz-entwurf.md` nennt unter „Was unser Dienst speichert“ Sitzung, Apple-Zugangsmerkmal, Konnektor-Zugangsdaten sowie Aufträge und Ergebnisse, **nicht** das Gerätetoken (und die „Beleg im Code“-Tabelle kennt `device_tokens` nicht). Der Absatz „Löschen“ („alle Daten, die der Dienst zu diesem Konto gespeichert hat“) deckt das Entfernen schon ab. Diese Spec ändert den Text **nicht**: Eine Änderung braucht Hennings Freigabe und die angepasste Website-Seite (Website-Repo `henemm/henemm-website`). **Vorbedingung für S5c:** Die App darf kein Token senden, bevor der Datenschutztext (Absatz „Was unser Dienst speichert“: Gerätetoken je Gerät und Umgebung, nur für den Weckruf, gelöscht mit dem Konto) und die Website-Seite es nennen und Henning den Text freigegeben hat. Das wird als eigener Punkt in die Definition of Done von #795 und als Vorbedingung in die Spec von S5c aufgenommen.
8. **Unberührt:** `main.ts`, `orders.ts`, `transcripts.ts`, `mcp.ts`, `auth.ts`, `accounts.ts`, `.github/`, `project.yml`, jede Swift-Datei.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `admitted`, `jsonBody`, `status` (`app-routes.ts`), `bearerToken`, `resolveSession` | bestehend, unverändert |
| `FormError` und das Muster der Formprüfung (`transcripts.ts`) | bestehend, unverändert |
| `accounts` (Tabelle, `id text`), `deleteAccount` | bestehend; Kaskade trägt das Löschen |
| `mountApp`/`gated` in `main.ts` | bestehend, unverändert |
| `node:test`, `pg` | bestehend, **keine neuen Pakete** |
| Downstream | S5a-2 (Absender, Konfiguration, Weckruf aus `putOrder`), S5b (nginx, neuer APNs-Schlüssel, Ausrollen), S5c (App) |

## Acceptance Criteria

Alle Tests mit `node:test` und `node:assert/strict` in `server/test/devices.test.ts`, gegen das Wegwerf-Postgres (`freshPool`, `migrate`, Sitzungen mit `findOrCreate` und `createSession`; Muster von `app-routes.test.ts`). Kein Netz. Formfälle und Ablehnungen tabellengetrieben, ein Fall je Zeile. Drei bestehende Testfälle ändern sich mechanisch, weil sie Listen festschreiben: (1) „app: einhaengen vor migrate und ohne auth“ in `server/test/app-routes.test.ts` bekommt `/app/device` als vierten Pfad (eine Zeile); (2) „AC-1: the migrations apply 001 and 002 once …“ in `server/test/accounts.test.ts` bekommt `008_device_tokens.sql` in der Migrationsliste (eine Zeile); (3) „AC-1: the real migrations folder applies 001 once …“ in `server/test/schema.test.ts` bekommt `008_device_tokens.sql` in der Liste und `rowCount` 8 statt 7 (zwei Zeilen). So hat es jede bisherige Migration gehalten (zuletzt 007). Sonst wird kein bestehender Testfall geändert.

- **AC-1:** Migration: GIVEN ein frisches Schema WHEN `migrate` läuft THEN gibt es die Tabelle `device_tokens` mit Primärschlüssel `(account_id, device)`, einer Eindeutigkeit auf `token`, einem CHECK auf `environment` (ein Einfügen mit `'staging'` scheitert) und einem Fremdschlüssel auf `accounts`; ein zweiter `migrate`-Lauf wendet `008` nicht noch einmal an (`schema_migrations` hat genau eine Zeile dafür). Test: „devices: migration 008 einmal angewendet“.
- **AC-2:** Formprüfung `checkDevice`, Annahme und Ablehnung: angenommen werden ein Token mit 64 und eines mit 200 Hex-Zeichen (je mit `sandbox` und `production`) und ein großgeschriebenes Token. Abgelehnt (`FormError`) werden: kein Objekt (`null`, `[]`, `"x"`), fehlender Schlüssel `token`, fehlender Schlüssel `environment`, ein zusätzlicher Schlüssel, Länge 63, Länge 201, ungerade Länge (65), Nicht-Hex-Zeichen (`g`, Leerzeichen, Zeilenumbruch), `token` kein Text (Zahl), `environment` falsch (`"Sandbox"`, `"prod"`, `""`, Zahl). Die Meldung enthält nie den Wert des Tokens. Tabellengetrieben. Test: „devices: checkDevice Formfaelle“.
- **AC-3:** Neu anlegen und aktualisieren: GIVEN ein Konto WHEN `putDevice` mit Token T1 (großgeschrieben) für Gerät G1 THEN steht genau eine Zeile `(Konto, G1, T1 in Kleinschreibung, Umgebung)` in `device_tokens`; WHEN `putDevice` für G1 mit Token T2 und anderer Umgebung THEN gibt es weiter genau eine Zeile für G1 mit T2 und der neuen Umgebung, und `updated_at` ist größer als zuvor. Test: „devices: neu und aktualisieren“.
- **AC-4:** Token zieht um: GIVEN Konto A mit Gerät G1 und Token T WHEN `putDevice` für Konto B, Gerät G2 mit demselben T (in anderer Schreibweise) THEN gehört T genau Konto B und G2, die Zeile von A ist weg, andere Zeilen von A bleiben; derselbe Fall innerhalb eines Kontos (Gerät G3 meldet T, das bisher G1 hatte) lässt genau G3 mit T zurück. Test: „devices: token zieht um“.
- **AC-5:** Grenze von zehn Geräten: GIVEN ein Konto mit zehn Geräten, deren `updated_at` aufsteigend und in der Vergangenheit gesetzt ist, je `now() - make_interval(mins => 20 - i)` für Gerät i = 0…9 (so ist die neu geschriebene Zeile mit `now()` sicher die jüngste) WHEN ein elftes Gerät sein Token meldet THEN hat das Konto genau 10 Zeilen, die Zeile des ältesten Geräts ist weg, die neue Zeile ist da; bei gleichem `updated_at` fällt das Gerät mit der kleineren Kennung zuerst; die Zeilen eines anderen Kontos bleiben unberührt; meldet ein schon bekanntes Gerät erneut (Zehnergrenze erreicht), fällt keine Zeile weg. Test: „devices: elftes geraet verdraengt aeltestes“.
- **AC-6:** Weg, Erfolg: GIVEN eine gültige App-Sitzung WHEN `POST /app/device` mit `Authorization: Bearer`, `X-Device` (UUID, großgeschrieben), `content-type: application/json` (auch mit `; charset=utf-8`) und gültigem Körper THEN **204**, `cache-control: no-store`, `await response.text()` ist leer, und die Zeile in `device_tokens` hat das Gerät in Kleinschreibung, das Token in Kleinschreibung und die gemeldete Umgebung. Ein zweiter Aufruf mit neuem Token ersetzt die Zeile. Test: „devices: weg meldet token“.
- **AC-7:** Weg, Ablehnungen, in der Reihenfolge der Prüfungen, tabellengetrieben mit je einer Anfrage: (a) `GET`, `PUT`, `DELETE` mit gültiger Sitzung → **405** mit `allow: POST`; (b) kein `authorization`-Kopf, Schema `Basic`, `Bearer` ohne Token, `Bearer a b`, unbekanntes Token, abgelaufene Sitzung (`last_used_at` vor 91 Tagen), beendete Sitzung → jeweils **401**; (c) gültige Sitzung mit fehlendem `X-Device` und mit falschem (`"gerät"`, UUID ohne Bindestriche, 35 Zeichen) → **400**; (d) `content-type: text/plain` und ohne → **415**; (e) Körper von genau 256 KiB (Füllfeld, danach 400 aus der Formprüfung, nicht 413) angenommen, 256 KiB + 1 Byte → **413**; (f) nicht lesbares JSON (`{`) und ein Körper, der `checkDevice` verletzt (zusätzlicher Schlüssel, Token der Länge 63, falsche Umgebung) → **400**; (g) unbekanntes Token **und** fehlendes `X-Device` → 401 (die Anmeldung geht der Geräteprüfung voraus), unbekanntes Token mit falschem Inhaltstyp → 401. In jedem Fall: Status wie genannt, `await response.text()` leer, `cache-control: no-store` (bei 405 zusätzlich `allow`), und `device_tokens` ist unverändert (Zeilenzahl und Inhalt). Ein Spion auf `console.error` bleibt über den ganzen Lauf leer. Test: „devices: weg jede ablehnung“.
- **AC-8:** Konto löschen: GIVEN zwei Konten mit je zwei Zeilen in `device_tokens` WHEN `deleteAccount` für Konto A läuft THEN sind beide Zeilen von A weg und beide von B unverändert; `accounts.ts` ist dafür nicht geändert (Kaskade). Test: „devices: konto loeschen entfernt tokens“.
- **AC-9:** Einhängen und Abmelden: (a) Vor `migrate` (Datenbank unerreichbar, wie in `main.test.ts` und S1 AC-14) antwortet `POST /app/device` über die echte Routentabelle von `start()` **503** ohne Körper und ruft die Datenbank nicht; nach `ready` läuft der Weg, **ohne** Option `auth`. (b) `endSession` (Abmelden) lässt die Zeile des Geräts in `device_tokens` stehen. Test: „devices: einhaengen vor migrate und abmelden“.
- **AC-10:** Vertrag und Doku: `docs/reference/claude-abschrift-vertrag.md`, Abschnitt „Wege der App“, nennt den vierten Weg `POST /app/device` (Körper mit `token` und `environment`, Beispiel als ```http oder ```text, **kein** weiterer ```json-Block: mehrere bestehende Tests in `server/test/` zählen oder lesen genau die drei vorhandenen), die Antworten (204, 400, 401, 405, 413, 415, mit `X-Device` Pflicht), den Umzug des Tokens, die Grenze von 10 Geräten je Konto, „Abmelden entfernt den Eintrag nicht, Konto löschen schon“ und „von außen erst ab S5b“; der Einleitungssatz („drei Wege“) und die Zeile „Mengengrenze“ nennen vier Wege. Alle Wörter, die `app: vertrag und doku` aus S1 prüft (`/app/transcript`, `/app/orders/claim`, `/app/orders/result`, `X-Device`, `Authorization: Bearer`, `10 Minuten`, `Rückholen`, `mindestens einmal`), bleiben im Abschnitt stehen. `CLAUDE.md`, Abschnitt `server/`, bekommt eine **eigene** knappe Zeile zu `src/devices.ts`, Migration 008 und `/app/device` (ohne die Zeichenfolge `src/app-routes.ts`, damit die Suche von `app: vertrag und doku` weiter die bestehende Zeile findet). Test: „devices: vertrag und doku“ (Prüfung per `readFileSync` und Regex: der Pfad `/app/device`, `device_tokens`/`environment` im Vertragsabschnitt, `10 Geräte` oder `zehn Geräte`, genau drei ```json-Blöcke, `devices.ts` in `CLAUDE.md`).
- **AC-11:** Grenze und Länge: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/migrations/008_device_tokens.sql`, `server/src/devices.ts`, `server/src/app-routes.ts`, `server/test/devices.test.ts`, `server/test/app-routes.test.ts` (nur die Pfadliste), `server/test/accounts.test.ts` und `server/test/schema.test.ts` (nur die Migrationsliste und die Zahl) und `CLAUDE.md`; `main.ts`, `orders.ts`, `accounts.ts`, `transcripts.ts`, `mcp.ts`, `auth.ts`, `.github/`, `project.yml` und jede Swift-Datei sind unverändert; jede Funktion hat höchstens 50 Zeilen. **Kein dauerhafter Test** (ein Test gegen `origin/main` scheitert im flachen CI-Checkout): Beleg einmalig in `/60-validate`, Befehl, Ausgabe und Funktionslängen im Validierungsprotokoll. Ausnahme von „jede AC hat einen Test“ vom Tech Lead bestätigt (festes Vorgehen seit S1 AC-17: die Dateigrenze wird nur in `/60-validate` geprüft, nie als Test gegen `main`).

## Test Plan

Geplante Tests (Namen, alle in `server/test/devices.test.ts`):

- „devices: migration 008 einmal angewendet“ (AC-1)
- „devices: checkDevice Formfaelle“ (AC-2)
- „devices: neu und aktualisieren“ (AC-3)
- „devices: token zieht um“ (AC-4)
- „devices: elftes geraet verdraengt aeltestes“ (AC-5)
- „devices: weg meldet token“ (AC-6)
- „devices: weg jede ablehnung“ (AC-7)
- „devices: konto loeschen entfernt tokens“ (AC-8)
- „devices: einhaengen vor migrate und abmelden“ (AC-9)
- „devices: vertrag und doku“ (AC-10)
- AC-11: kein Test (Tech-Lead-Ausnahme, siehe AC-11), Validierungsbeleg in `/60-validate`
- Mechanisch angepasst (keine neuen Testfälle): `app-routes.test.ts` „app: einhaengen vor migrate und ohne auth“ (Pfadliste), `accounts.test.ts` und `schema.test.ts` je „AC-1“ (Migrationsliste, Zahl 8)

RED: `devices.ts` und die Migration existieren nicht, alle Tests schlagen beim Import oder an der fehlenden Tabelle fehl.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt, PO-Entscheidung 2026-11-13): echter Weckruf per stiller APNs-Mitteilung.** Der Dienst braucht dafür die Gerätetokens; dieser Schnitt legt den Speicher. Verlangt einen neuen APNs-Schlüssel (Portal-Anmeldung Hennings, S5b) und einen Absatz im Datenschutztext (Festlegung 7).
- **B: Mac holt im Takt (Empfehlung der Analyse, verworfen vom PO).** Kein Dienstteil, kein Gerätetoken, kein neuer Schlüssel; der Mac holt etwa alle 2 Minuten, iPhone nur beim Öffnen. Verworfen, weil Henning den echten Weckruf wollte. Wäre B gewählt worden, entfiele dieser Schnitt ganz, und die Aussage „der Dienst speichert keine Gerätekennungen für Apple“ bliebe wahr.
- **C: Nichts, Holen beim Öffnen.** Null Aufwand; der Auftrag wartet bis zum nächsten Öffnen. Kippte nichts, deckt aber den Wunsch nach einem Weckruf nicht.
- **D: Token an die Sitzung statt an das Gerät hängen** (`sessions.push_token`): spart eine Tabelle, aber eine Sitzung kennt kein Gerät (`/auth/apple` bekommt keinen `X-Device`), und ein Abmelden würde das Token mit löschen, während ein Gerät mehrere Sitzungen haben kann. Verworfen; die Tabelle je `(Konto, Gerät)` passt zu `claimed_by`.
- **E: Abmelden löscht den Eintrag** (neuer Weg oder `X-Device` bei `/auth/logout`): sauberer, aber ein Eingriff in `auth.ts` und in den Vertrag der Abmeldung, den S1 bis S4 festgeschrieben haben; der Gewinn ist gering, weil ein Weckruf an ein abgemeldetes Gerät folgenlos bleibt. Nicht gebaut; fiele die Zeile „Abmelden beendet nur die Sitzung“ aus dem Datenschutztext, wäre es neu zu bewerten.

## Risiken

- **Datenschutz:** Der Dienst speichert erstmals ein Apple-Kennzeichen eines Geräts. Es ist nicht personenbezogen im Sinne eines Namens, aber ein Gerätekennzeichen; Vorbedingung für S5c (Festlegung 7), keine Sendung vorher.
- **Gleichzeitige Meldung desselben Tokens** durch zwei Geräte oder Konten: die Eindeutigkeit auf `token` lässt eine der beiden Transaktionen mit einem Fehler (500) scheitern; die App meldet beim nächsten Anlass erneut. Kein Datenverlust, kein Sonderfall im Code. Ebenso 500 in dem Zufallsfall, dass das Konto zwischen Sitzungsprüfung und Ablage gelöscht wird (Fremdschlüssel).
- **Alte Tokens bleiben stehen,** bis S5a-2 ungültige (410, `BadDeviceToken`, `Unregistered`) löscht; bis dahin wird nichts gesendet, also nichts verschwendet.
- **Ausrollen:** Die Migration läuft beim Start des Dienstes (`migrate`); der Schnitt ändert den laufenden Dienst erst mit dem Ausrollen von Hand (`scripts/deploy-loose-ends.sh`, fester Stand `LE_COMMIT`). Die Tabelle ist rein additiv; die Migration läuft auch ohne den Weg. Ausrollen vor S5b ist unschädlich, der Pfad bleibt von außen 404.
- **Hotspot:** `CLAUDE.md` und `docs/reference/claude-abschrift-vertrag.md` werden von parallelen Sitzungen berührt; vor dem PR `origin/main` einmischen.

## Scope und Seiteneffekte

- Dateien (Produkt und Tests): `server/migrations/008_device_tokens.sql` (neu, ca. 12 Zeilen), `server/src/devices.ts` (neu, ca. 65), `server/src/app-routes.ts` (ca. +16), `server/test/devices.test.ts` (neu, höchstens 144 Zeilen, Tabellen und Aufbau), `server/test/app-routes.test.ts` (eine Zeile: Pfadliste), `server/test/accounts.test.ts` (eine Zeile: Migrationsliste), `server/test/schema.test.ts` (zwei Zeilen: Migrationsliste, Zahl); dazu zwei Textdateien (`docs/reference/claude-abschrift-vertrag.md` ca. +25, `CLAUDE.md` ca. +3). Inhaltlich geänderte Code-Dateien: 4 (Migration, `devices.ts`, `app-routes.ts`, `devices.test.ts`); dazu drei bestehende Tests mit zusammen vier geänderten Zeilen, die nur Listen nachziehen, und `CLAUDE.md` als Doku: 8 Dateien ohne `docs/`. Tech-Lead-Entscheidung: angenommen, weil die drei Testdateien bei jeder Migration und jedem neuen Weg mechanisch mitwandern (zuletzt 007) und keine eigene Logik tragen, `CLAUDE.md` reine Doku ist und die LoC-Grenze hält; ein Einhängen an `appRoutes` vorbei würde `main.ts` berühren und wäre mehr Änderung, nicht weniger.
- **LoC ehrlich geschätzt:** Produktcode rund 93 (Migration 12, `devices.ts` 65, `app-routes.ts` 16), Tests höchstens 152 (144 neu + 8 aus den vier geänderten Listenzeilen, je Zeile eine Löschung und eine Ergänzung), `CLAUDE.md` rund 3; Summe gezählt wie die numstat-Ausgabe des Diffs (Ergänzungen plus Löschungen, ohne `docs/`) höchstens **248**, also innerhalb von ±250. Meldeschwelle: Liegt `devices.test.ts` nach RED über 144 Zeilen oder der Endstand über 250, wird vor dem Weiterbauen erneut gefragt; dann wandert AC-9 (Einhängen, Abmelden) in S5a-2.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, kein `generate`. **Eine Migration** (`008`, additiv).
- Seiteneffekte außerhalb des Tickets: keiner nach außen (nginx lässt `/app/device` nicht durch, die App ruft ihn nicht). Verhalten bestehender Wege unverändert.

## Nicht in diesem Schnitt / Folgeschnitte

- **S5a-2 Absender:** `server/src/apns.ts` (ES256-Anbieter-Token, `node:http2`), `APNS_*`-Konfiguration alles-oder-nichts in `main.ts`, Weckruf aus `putOrder` bei `stored`, ungültige Tokens (410, `BadDeviceToken`, `Unregistered`) löschen.
- **S5b nginx und Schlüssel** (`henemm-infra`): Erlaubnisliste um `/app/device`, neuer APNs-Schlüssel im Portal (Henning meldet sich nur an), Geheimnisse auf `rennwienix`, Ausrollen.
- **S5c App:** Registrierung für Mitteilungen, Token an `/app/device` senden, Eingang der stillen Mitteilung. **Vorbedingung:** Datenschutztext und Website-Seite nennen das Gerätetoken, Henning hat den Text freigegeben (Festlegung 7). Stufe 3 über TestFlight (Gerätepfade `project.yml`, `LooseEnds/Notifications/`).

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulator nötig (wie S1). Nachweis: `./server/scripts/test-local.sh` grün (Wegwerf-Postgres, `npm run typecheck` und `npm test`) und `server.yml` auf dem PR grün (Linux, `postgres:18`).
- Ausrollen auf `rennwienix` als eigener Schritt von Claude nach dem Merge (Beleg: `/health` 200 mit dem neuen Stand); aus dem öffentlichen Netz ist bis S5b kein Beleg möglich.
- Stufe 3 entfällt. **Kein Pfad der Geräteliste berührt.**

## Definition of Done

- [ ] AC-1 bis AC-11 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt `devices.ts`, Migration 008 und `/app/device`
- [ ] Vertragsdokument ergänzt (vierter Weg, Umzug, Grenze, Abmelden/Löschen), genau drei ```json-Blöcke
- [ ] #795: Vorbedingung für S5c (Datenschutztext und Website nennen das Gerätetoken, Henning gibt den Text frei) als Punkt in der Definition of Done aufgenommen; #795 kommentiert (Stand S5a-1, Folge S5a-2), Board-Karte aktuell

## Changelog

- 2026-11-13: Entwurf (Schnitt S5a-1 von #795, Teilung von S5a)
