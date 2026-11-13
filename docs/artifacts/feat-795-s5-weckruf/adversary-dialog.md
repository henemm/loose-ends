# Adversary Dialog — feat-795-s5-weckruf
Spec: docs/specs/feat-795-schnitt-5a1-geraet-anmelden.md
Datum: 2026-11-13 17:30

## Checkliste
- [x] **AC-1:** Migration: GIVEN ein frisches Schema WHEN `migrate` läuft THEN gibt es die Tabelle `device_tokens` mit Primärschlüssel `(account_id, device)`, einer Eindeutigkeit auf `token`, einem CHECK auf `environment` (ein Einfügen mit `'staging'` scheitert) und einem Fremdschlüssel auf `accounts`; ein zweiter `migrate`-Lauf wendet `008` nicht noch einmal an (`schema_migrations` hat genau eine Zeile dafür). Test: „devices: migration 008 einmal angewendet“.
- [x] **AC-2:** Formprüfung `checkDevice`, Annahme und Ablehnung: angenommen werden ein Token mit 64 und eines mit 200 Hex-Zeichen (je mit `sandbox` und `production`) und ein großgeschriebenes Token. Abgelehnt (`FormError`) werden: kein Objekt (`null`, `[]`, `"x"`), fehlender Schlüssel `token`, fehlender Schlüssel `environment`, ein zusätzlicher Schlüssel, Länge 63, Länge 201, ungerade Länge (65), Nicht-Hex-Zeichen (`g`, Leerzeichen, Zeilenumbruch), `token` kein Text (Zahl), `environment` falsch (`"Sandbox"`, `"prod"`, `""`, Zahl). Die Meldung enthält nie den Wert des Tokens. Tabellengetrieben. Test: „devices: checkDevice Formfaelle“.
- [x] **AC-3:** Neu anlegen und aktualisieren: GIVEN ein Konto WHEN `putDevice` mit Token T1 (großgeschrieben) für Gerät G1 THEN steht genau eine Zeile `(Konto, G1, T1 in Kleinschreibung, Umgebung)` in `device_tokens`; WHEN `putDevice` für G1 mit Token T2 und anderer Umgebung THEN gibt es weiter genau eine Zeile für G1 mit T2 und der neuen Umgebung, und `updated_at` ist größer als zuvor. Test: „devices: neu und aktualisieren“.
- [x] **AC-4:** Token zieht um: GIVEN Konto A mit Gerät G1 und Token T WHEN `putDevice` für Konto B, Gerät G2 mit demselben T (in anderer Schreibweise) THEN gehört T genau Konto B und G2, die Zeile von A ist weg, andere Zeilen von A bleiben; derselbe Fall innerhalb eines Kontos (Gerät G3 meldet T, das bisher G1 hatte) lässt genau G3 mit T zurück. Test: „devices: token zieht um“.
- [x] **AC-5:** Grenze von zehn Geräten: GIVEN ein Konto mit zehn Geräten, deren `updated_at` aufsteigend und in der Vergangenheit gesetzt ist, je `now() - make_interval(mins => 20 - i)` für Gerät i = 0…9 (so ist die neu geschriebene Zeile mit `now()` sicher die jüngste) WHEN ein elftes Gerät sein Token meldet THEN hat das Konto genau 10 Zeilen, die Zeile des ältesten Geräts ist weg, die neue Zeile ist da; bei gleichem `updated_at` fällt das Gerät mit der kleineren Kennung zuerst; die Zeilen eines anderen Kontos bleiben unberührt; meldet ein schon bekanntes Gerät erneut (Zehnergrenze erreicht), fällt keine Zeile weg. Test: „devices: elftes geraet verdraengt aeltestes“.
- [x] **AC-6:** Weg, Erfolg: GIVEN eine gültige App-Sitzung WHEN `POST /app/device` mit `Authorization: Bearer`, `X-Device` (UUID, großgeschrieben), `content-type: application/json` (auch mit `; charset=utf-8`) und gültigem Körper THEN **204**, `cache-control: no-store`, `await response.text()` ist leer, und die Zeile in `device_tokens` hat das Gerät in Kleinschreibung, das Token in Kleinschreibung und die gemeldete Umgebung. Ein zweiter Aufruf mit neuem Token ersetzt die Zeile. Test: „devices: weg meldet token“.
- [x] **AC-7:** Weg, Ablehnungen, in der Reihenfolge der Prüfungen, tabellengetrieben mit je einer Anfrage: (a) `GET`, `PUT`, `DELETE` mit gültiger Sitzung → **405** mit `allow: POST`; (b) kein `authorization`-Kopf, Schema `Basic`, `Bearer` ohne Token, `Bearer a b`, unbekanntes Token, abgelaufene Sitzung (`last_used_at` vor 91 Tagen), beendete Sitzung → jeweils **401**; (c) gültige Sitzung mit fehlendem `X-Device` und mit falschem (`"gerät"`, UUID ohne Bindestriche, 35 Zeichen) → **400**; (d) `content-type: text/plain` und ohne → **415**; (e) Körper von genau 256 KiB (Füllfeld, danach 400 aus der Formprüfung, nicht 413) angenommen, 256 KiB + 1 Byte → **413**; (f) nicht lesbares JSON (`{`) und ein Körper, der `checkDevice` verletzt (zusätzlicher Schlüssel, Token der Länge 63, falsche Umgebung) → **400**; (g) unbekanntes Token **und** fehlendes `X-Device` → 401 (die Anmeldung geht der Geräteprüfung voraus), unbekanntes Token mit falschem Inhaltstyp → 401. In jedem Fall: Status wie genannt, `await response.text()` leer, `cache-control: no-store` (bei 405 zusätzlich `allow`), und `device_tokens` ist unverändert (Zeilenzahl und Inhalt). Ein Spion auf `console.error` bleibt über den ganzen Lauf leer. Test: „devices: weg jede ablehnung“.
- [x] **AC-8:** Konto löschen: GIVEN zwei Konten mit je zwei Zeilen in `device_tokens` WHEN `deleteAccount` für Konto A läuft THEN sind beide Zeilen von A weg und beide von B unverändert; `accounts.ts` ist dafür nicht geändert (Kaskade). Test: „devices: konto loeschen entfernt tokens“.
- [x] **AC-9:** Einhängen und Abmelden: (a) Vor `migrate` (Datenbank unerreichbar, wie in `main.test.ts` und S1 AC-14) antwortet `POST /app/device` über die echte Routentabelle von `start()` **503** ohne Körper und ruft die Datenbank nicht; nach `ready` läuft der Weg, **ohne** Option `auth`. (b) `endSession` (Abmelden) lässt die Zeile des Geräts in `device_tokens` stehen. Test: „devices: einhaengen vor migrate und abmelden“.
- [x] **AC-10:** Vertrag und Doku: `docs/reference/claude-abschrift-vertrag.md`, Abschnitt „Wege der App“, nennt den vierten Weg `POST /app/device` (Körper mit `token` und `environment`, Beispiel als ```http oder ```text, **kein** weiterer ```json-Block: mehrere bestehende Tests in `server/test/` zählen oder lesen genau die drei vorhandenen), die Antworten (204, 400, 401, 405, 413, 415, mit `X-Device` Pflicht), den Umzug des Tokens, die Grenze von 10 Geräten je Konto, „Abmelden entfernt den Eintrag nicht, Konto löschen schon“ und „von außen erst ab S5b“; der Einleitungssatz („drei Wege“) und die Zeile „Mengengrenze“ nennen vier Wege. Alle Wörter, die `app: vertrag und doku` aus S1 prüft (`/app/transcript`, `/app/orders/claim`, `/app/orders/result`, `X-Device`, `Authorization: Bearer`, `10 Minuten`, `Rückholen`, `mindestens einmal`), bleiben im Abschnitt stehen. `CLAUDE.md`, Abschnitt `server/`, bekommt eine **eigene** knappe Zeile zu `src/devices.ts`, Migration 008 und `/app/device` (ohne die Zeichenfolge `src/app-routes.ts`, damit die Suche von `app: vertrag und doku` weiter die bestehende Zeile findet). Test: „devices: vertrag und doku“ (Prüfung per `readFileSync` und Regex: der Pfad `/app/device`, `device_tokens`/`environment` im Vertragsabschnitt, `10 Geräte` oder `zehn Geräte`, genau drei ```json-Blöcke, `devices.ts` in `CLAUDE.md`).
- [x] **AC-11:** Grenze und Länge: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/migrations/008_device_tokens.sql`, `server/src/devices.ts`, `server/src/app-routes.ts`, `server/test/devices.test.ts`, `server/test/app-routes.test.ts` (nur die Pfadliste), `server/test/accounts.test.ts` und `server/test/schema.test.ts` (nur die Migrationsliste und die Zahl) und `CLAUDE.md`; `main.ts`, `orders.ts`, `accounts.ts`, `transcripts.ts`, `mcp.ts`, `auth.ts`, `.github/`, `project.yml` und jede Swift-Datei sind unverändert; jede Funktion hat höchstens 50 Zeilen. **Kein dauerhafter Test** (ein Test gegen `origin/main` scheitert im flachen CI-Checkout): Beleg einmalig in `/60-validate`, Befehl, Ausgabe und Funktionslängen im Validierungsprotokoll. Ausnahme von „jede AC hat einen Test“ vom Tech Lead bestätigt (festes Vorgehen seit S1 AC-17: die Dateigrenze wird nur in `/60-validate` geprüft, nie als Test gegen `main`).

## Dialog

### Runde 1
**Adversary:** Suite selbst gefahren: `./server/scripts/test-local.sh` (typecheck + 418 Tests, 0 Fehler, 0 uebersprungen), Ausgabe in `docs/artifacts/feat-795-s5-weckruf/adversary-test-output.txt`. Danach Code gelesen und je AC einen Beleg gesucht.

Confirmation:
  AC: AC-1
  Code reference: server/migrations/008_device_tokens.sql:6
  Evidence: PRIMARY KEY (account_id, device), UNIQUE (token), CHECK environment IN ('sandbox','production'), FK auf accounts ON DELETE CASCADE (Zeilen 6-11); Test devices.test.ts "migration 008" prueft Constraint-Definitionen, 'staging' wird abgelehnt, zweiter migrate wendet nichts an.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/src/devices.ts:11
  Evidence: token-Check: Text, Hex, gerade Laenge, 64..200; environment exakt zwei Werte; shape() lehnt Zusatz-/fehlende Schluessel ab; Meldungen "kein Geraetetoken"/"unbekannte Umgebung" ohne Wert. Test server/test/devices.test.ts:54 prueft 17 Ablehnungen und dass die Meldung den Token nie enthaelt.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/devices.ts:30
  Evidence: INSERT ... ON CONFLICT (account_id, device) DO UPDATE mit updated_at = now(); Token wird in Zeile 25 klein geschrieben. Test devices.test.ts:69.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/devices.ts:29
  Evidence: DELETE ... WHERE token = $1 AND (account_id, device) ungleich ($2, $3) vor dem Insert, Token klein geschrieben, also Umzug unabhaengig von Schreibweise, auch innerhalb eines Kontos; andere Zeilen bleiben. Test devices.test.ts:82.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/src/devices.ts:36
  Evidence: Kuerzung waehlt nur Zeilen mit device ungleich geschriebenes Geraet, ORDER BY updated_at DESC, device DESC OFFSET 9; die eben geschriebene Zeile ist so nie betroffen, bei Gleichstand faellt die kleinere Kennung, account_id = $1 laesst fremde Konten unberuehrt, ein bekanntes Geraet (UPDATE) ergibt weiter 10 Zeilen. Test devices.test.ts:93 deckt alle vier Faelle ab (Gleichstand bei Konto b mit identischem updated_at).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/app-routes.ts:107
  Evidence: register(): admitted(device:true), dann jsonBody(checkDevice), dann putDevice, dann status(204) mit no-store ohne Koerper; device() legt X-Device klein (Zeilen 47-50). Test server/test/devices.test.ts:109 mit grossgeschriebenem X-Device, charset-Typ und Ersetzung.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/src/app-routes.ts:57
  Evidence: admitted(): 405 vor 401 vor 400 (Geraet); jsonBody(): 415 vor 413 vor 400; unbekanntes Token mit fehlendem X-Device oder falschem Typ endet in 401, weil resolveSession vor device() und vor jsonBody laeuft. Kein Wert verlaesst den Dienst: der catch gibt nur status(400). Test server/test/devices.test.ts:119 (26 Faelle, je Status, leerer Koerper, no-store, allow, Tabelle unveraendert, console.error-Spion leer).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/test/devices.test.ts:155
  Evidence: deleteAccount(A) entfernt beide Zeilen von A, B bleibt gleich; accounts.ts ist im Diff nicht enthalten (Kaskade, Migration Zeile 6).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/test/devices.test.ts:165
  Code reference: server/test/app-routes.test.ts:407
  Evidence: Vor migrate 503 ohne Koerper ueber die echte Routentabelle (Pfadliste in server/test/app-routes.test.ts um /app/device ergaenzt), danach 204 ohne auth-Option; endSession laesst die Zeile stehen.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: server/test/devices.test.ts:183
  Evidence: Test liest den Vertragsabschnitt, zaehlt genau drei json-Bloecke, prueft "vier Wege", "10 Geraete" und die eigene CLAUDE.md-Zeile (ohne src/app-routes.ts). Diff von docs/reference/claude-abschrift-vertrag.md gelesen: der vierte Weg steht als http-Block.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: server/test/schema.test.ts:1
  Code reference: server/test/accounts.test.ts:66
  Evidence: Der Diff-Befehl aus AC-11 nennt CLAUDE.md, server/src/app-routes.ts, server/test/accounts.test.ts, server/test/app-routes.test.ts, server/test/devices.test.ts, server/test/schema.test.ts; laut Status des Arbeitsbaums kommen untracked server/migrations/008_device_tokens.sql und server/src/devices.ts dazu (Test-Dateien sind schon im RED-Stand eingecheckt, daher fehlen sie im Vergleich HEAD gegen origin/main nicht, sondern stehen dort). Genau die acht Soll-Dateien, nichts sonst (kein main.ts, orders.ts, accounts.ts, transcripts.ts, mcp.ts, auth.ts, .github, project.yml, keine Swift-Datei). In accounts.test.ts (Code reference server/test/accounts.test.ts:1) und schema.test.ts nur die Migrationsliste und die Zahl 8 geaendert. Funktionslaengen: putDevice 26 Zeilen, register 8, admitted 11, jsonBody 12, checkDevice 3. Zeilen ohne docs: 1+12+1+1+193+2+2 (und 2+1+1 Loeschungen) plus Migration 12 und devices.ts 49, innerhalb der vom PO freigegebenen Obergrenze.
  Status: CONFIRMED

**Implementierer:** (nicht beteiligt, isolierter Adversary-Lauf)

### Runde 2
**Adversary:** Gezielte Angriffe mit Wegwerf-Pruefung im Scratchpad (probe.test.ts, eigenes Postgres):
1. Gleichzeitige Meldungen: 12 parallele putDevice mit verschiedenen Geraeten fuer ein Konto ergaben 10 Zeilen. Es gibt aber keine Sperre auf dem Konto (server/src/devices.ts:26-42, READ COMMITTED), ein Ueberlauf ist theoretisch moeglich und heilt sich bei der naechsten Meldung.
2. Gleiches Token gleichzeitig von zwei Konten und Geraeten (20 Aufrufe): Ergebnisse ok, 23505 (unique violation) und 40P01 (Deadlock); die Datenbank blieb konsistent (1 Zeile). Die Ausnahme wird in app-routes.ts nicht gefangen, dispatch in main.ts macht daraus 500 ohne Koerper (Kommentar app-routes.ts Zeile 120). Die App kann wiederholen.
3. Rollback und Client-Freigabe: catch fuehrt ROLLBACK aus, finally gibt den Client frei, gleiches Muster wie accounts.ts:128-131; schlaegt ROLLBACK selbst fehl, wird der Client wie im bestehenden Code ohne release(true) zurueckgegeben, kein neuer Befund.
4. Schreibweise: Token wird vor Delete und Insert klein geschrieben (devices.ts:25), UNIQUE(token) kann Gross/Klein nicht umgehen; getestet in "token zieht um" (AB.. gegen ab..).
5. Token-Werte in Fehlern und Logs: checkDevice-Meldungen ohne Wert, Antworten haben immer leeren Koerper, der neue Code hat keine Logzeile, der console.error-Spion in "weg jede ablehnung" bleibt leer.
6. Reihenfolge der Pruefungen: admitted() prueft Methode, Bearer, resolveSession, dann X-Device; jsonBody() Typ, dann Groesse (beim Lesen gezaehlt), dann JSON und Form. Entspricht 405/401/400/415/413/400.
7. Gleichstand der Kuerzung: ORDER BY updated_at DESC, device DESC OFFSET 9 verwirft die kleinste Kennung zuerst; die frische Zeile ist per device-Ausschluss ohnehin geschuetzt.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: server/src/devices.ts:28
  Description: putDevice sperrt weder das Konto noch das Token. Bei gleichzeitigen Meldungen desselben Tokens enden Transaktionen mit 23505 oder 40P01 (im Probelauf 11 von 20 Aufrufen), im Weg als 500 ohne Koerper; parallele Meldungen verschiedener Geraete koennten kurzzeitig mehr als 10 Zeilen hinterlassen.
  Spec requirement: AC-3, AC-4, AC-5 (die Spec verlangt kein Verhalten unter Gleichzeitigkeit)
  Conflict: Kein Widerspruch zur Spec, nur eine nicht spezifizierte Randerscheinung. Daten bleiben konsistent, die naechste Meldung stellt die Grenze wieder her.
  Remediation: Optional spaeter: SELECT ... FOR UPDATE auf der Kontozeile am Anfang der Transaktion und Wiederholung bei 23505.

**Implementierer:** (nicht beteiligt, isolierter Adversary-Lauf)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Implementierung hat den Adversary-Tests standgehalten.
Tests: 418 passed, 0 failed, 0 uebersprungen (docs/artifacts/feat-795-s5-weckruf/adversary-test-output.txt)
Edge cases: geprueft; nur F001 (LOW, Gleichzeitigkeit, ausserhalb der Spec)
Regressions: keine gefunden (app-routes.test.ts, accounts.test.ts, schema.test.ts gruen)
Checklist: 11/11 points proven

## Geprüfte Dateien

- sha256:af69128aaebba41484eaed69091339b9f423ad5030e970ffd3273399d3485698  server/migrations/008_device_tokens.sql
- sha256:f913c1c91466e1a5c25ba0d31d8ab88ab329ce508c4240ebc2ce192268d9400f  server/src/app-routes.ts
- sha256:eed9af8952babc6490ef6b4c36685f7b05df87a9d7fbe392d89d82057e67e84d  server/src/devices.ts
- sha256:b76caedb575b6174cc579a8122af8a3d4318674aba02caf587ec7b7401c9493a  server/test/accounts.test.ts
- sha256:fb186ebf18896b8712c541ce87503dc5d2bfcca763f9666cdba192620a6e55ab  server/test/app-routes.test.ts
- sha256:c89fa4ff500d94d4539e63b2ad5b357d6e4a69cb9101c2fa11b452d9df70b1cb  server/test/devices.test.ts
- sha256:aeb0ea0c426aa8b817b373275c5f4d6b2ebedd6ea81f1708e448c7f730ee99d8  server/test/schema.test.ts

## Prüfbasis

- base: 82c5e318db29407709de8173327e61b39d4eaa00
- blob:b58a33f943708b95bdafe542ed898fd752f23c1b  server/migrations/008_device_tokens.sql
- blob:0aeee44d1d4aabb7c2fb2b0302c9f89f769e52af  server/src/app-routes.ts
- blob:0fdad54923e4c82cb9a4acbf393a18a68daddd66  server/src/devices.ts
- blob:864a142e825ceb7b6d6f9c271063503cbe6af406  server/test/accounts.test.ts
- blob:e92e2000f50bd1fe2c3b857bdbfe9e2aa98a79a8  server/test/app-routes.test.ts
- blob:f2f508c67a751515ad0ed0ef313728b3da1c7709  server/test/devices.test.ts
- blob:d211e8a1c12f9fbc7171f485054a6abbcff63f9e  server/test/schema.test.ts
