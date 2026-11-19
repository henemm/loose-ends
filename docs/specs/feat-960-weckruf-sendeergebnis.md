---
entity_id: feat-960-weckruf-sendeergebnis
type: feature
created: 2026-11-19
updated: 2026-11-19
status: draft
workflow: feat-960-weckruf-sendeergebnis
---

# Spec: Weckruf-Sendeergebnis belegen (#960, Teil von #795)

## Approval

- [ ] Approved

## GitHub Issue

#960 (Teil von #795, Epic #612). Analyse: `docs/context/feat-960-weckruf-sendeergebnis.md` (Abschnitt „Analysis“: Befund, Recherche mit Quellen, Alternativen; verbindlich).
Vorgänger: S5a-2a (`docs/specs/feat-795-schnitt-5a2a-apns-absender.md`, Absender), S5a-2b (Verdrahtung in `storeOrder`), S5b (`docs/specs/feat-795-schnitt-5b-weckruf-betrieb.md`, Betrieb, Schlüssel), S5c-2a (App-Empfang).
Dies ist ein Diagnose-Schnitt am Dienst: nur Log-Ausgabe, **kein Eingriff in den Sendeweg**, keine App-Änderung.

## Für den PO

Beim Gerätetest am 2026-11-19 wurden Aufträge von Claude erst ausgeführt, wenn die App geöffnet wurde. Ob der Dienst das Anstupsen überhaupt abschickt und Apple es annimmt, lässt sich heute nicht sagen, weil der Dienst Erfolge nicht aufschreibt. Dieser Schnitt lässt den Dienst jeden Anstoß mit Ergebnis aufschreiben (ohne Geheimnisse). Danach ist belegt, ob das Problem beim Dienst, bei Apple oder erst am Gerät liegt. Sichtbar ändert sich in der App nichts, und auf deinen Geräten läuft nichts.

## Purpose

`createWaker().wake` in `server/src/apns.ts` kehrt bei einer 2xx-Antwort von Apple still zurück, und `sendHttp2` verwirft die Antwort-Header `apns-id` und `apns-unique-id`. Ein `wake` ohne Gerät und ein von Apple angenommener Push sind im Dienstlog ununterscheidbar. Der Schnitt macht jeden `wake` und jeden Sendeausgang als eine Logzeile mit festem Namen, Status, Umgebung und Apples IDs sichtbar. Damit ist die Annahme durch Apple belegbar (Voraussetzung für die Ursachenklärung); die Zustellung am Gerät belegt es nicht.

**Regeln vor Modell:** reine Protokollierung ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Logzeilen ergänzen den bestehenden Sender (S5a-2a) um Beobachtbarkeit; kein neues Verfahren, keine Abhängigkeit, keine Migration. Die Entscheidung „stiller Weckruf“ aus #795 S5 bleibt unberührt und wird erst nach dem Beleg neu bewertet (siehe Alternativen).

## Source

- **File:** `server/src/apns.ts`
- **Identifier:** `sendHttp2`, `ApnsResponse`, `createWaker` (`deliver`, `wake`); neue reine Hilfsfunktionen `apnsIds` und `describe` (siehe unten)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `server/src/mcp.ts` `storeOrder` | module | ruft `wake(owner)` losgelöst nach einem neu gespeicherten Auftrag, unverändert |
| `server/src/main.ts` `wakeFor` | module | baut den Waker mit `log: logError`, unverändert |
| `server/src/devices.ts` `listTokens`, `dropToken` | module | Geräteliste und Löschregel, unverändert |
| `node:http2` | extern | Antwort-Header `apns-id`, `apns-unique-id` |
| Apple APNs (`api.push.apple.com`) | extern | Quelle der IDs; unverändert |

## Schnittstelle und Festlegungen

**`ApnsResponse`** erhält optional `apnsId?: string` und `uniqueId?: string`. Sie fehlen als Schlüssel (nicht `undefined`), wenn Apple sie nicht oder nicht in kanonischer Form sendet; `deepEqual` der bestehenden Tests bleibt damit gültig.

**`apnsIds(headers)`** (reine, exportierte Funktion): nimmt die Antwort-Header (`IncomingHttpHeaders`) und gibt `{ apnsId?, uniqueId? }` zurück. Ein Wert wird nur übernommen, wenn er ein einzelner String in kanonischer UUID-Form ist (`8-4-4-4-12` Hexzeichen, beide Schreibweisen); Arrays, andere Formen und Fehlendes werden weggelassen, nie als Text weitergereicht. `sendHttp2` setzt sie in die Antwort ein. Das Header-Lesen wird so ohne echtes HTTP/2 testbar.

**Logformat (exakt, je Zeile ein Ereignis).** `UUID` steht für `[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}`, `ENV` für `sandbox|production`, `STATUS` für die dreistellige HTTP-Zahl der letzten Antwort:

| Zeile | Wann |
|---|---|
| `apns wake devices=N` | genau einmal je `wake`, nach erfolgreichem `listTokens`, auch bei N = 0 |
| `apns sent STATUS ENV[ id=UUID][ unique=UUID]` | Antwort 2xx |
| `apns send failed STATUS ENV[ id=UUID][ unique=UUID]` | Antwort ≠ 2xx, Token bleibt |
| `apns token dropped STATUS ENV[ id=UUID][ unique=UUID]` | Löschregel greift (410 Unregistered, 400 BadDeviceToken, 400 DeviceTokenNotForTopic) |
| `apns send failed error ENV` | Netzfehler, Timeout oder Ausnahme ohne Antwort |
| `apns send failed list` | `listTokens` schlägt fehl (kein Gerät erreichbar, kein `wake`-Zeile) |
| `apns jwt failed` | unverändert |

Die Gesamtprüfung je Zeile (Regex, in den Tests verbindlich):
`^apns (wake devices=\d+|jwt failed|send failed list|send failed error (sandbox|production)|(sent|send failed|token dropped) \d{3} (sandbox|production)( id=UUID)?( unique=UUID)?)$`

Die Wahl von `id=`/`unique=`-Marken statt Positionsfeldern hält die Zeile eindeutig, wenn nur eine der beiden IDs vorhanden ist. Bei der Wiederholung nach `ExpiredProviderToken` gilt die Zeile der **letzten** Antwort; es gibt je Gerät genau eine Ausgangszeile.

**Nie im Log:** Gerätetoken, Konto-Kennung, JWT, Body, der `reason`-Freitext von Apple, Fehlermeldungstexte. Status, Umgebung und von Apple vergebene Zufalls-UUIDs sind unkritisch (Analyse).

**Unverändert:** Anfrage (Kopfzeilen, Priorität 5, `background`, Payload), JWT-Cache und -Erneuerung, genau ein Wiederholversuch bei `ExpiredProviderToken`, Löschregel, Verhalten „`wake` wirft nie“, ein kaputter `log`-Callback stoppt nichts.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apns.ts` | MODIFY | `ApnsResponse` um `apnsId?`/`uniqueId?`; `apnsIds`; `sendHttp2` liest Header; `deliver` und `wake` loggen nach obigem Format; ≈ +35/−8 |
| `server/test/apns.test.ts` | MODIFY | neue Fälle, Format-Test auf Regex, bestehende Log-Erwartungen (`["apns send failed"]`, `["apns jwt failed"]`, `"apns token dropped"`) auf das neue Format; ≈ +60/−12 |

Kein App-Code, keine Migration, keine weitere Datei. Der `CLAUDE.md`-Absatz zu `src/apns.ts` bekommt einen Halbsatz („loggt jeden Sendeausgang mit Status, Umgebung und Apple-IDs, #960“) nur, wenn der Tech Lead ihn beim Abschluss für nötig hält; dann als dritte Datei (+1/−0).

### Estimated Changes

- Dateien: 2 (höchstens 3)
- LoC: ≈ +95/−20 (Test-Anteil überwiegt), innerhalb der Limits; Funktionen ≤ 50 LoC
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neue Abhängigkeit.
- Seiteneffekt nach außen: nach dem Deploy erscheinen zusätzliche Zeilen im Dienstlog (je Auftrag eine `wake`-Zeile und eine Zeile je Gerät); das Log trägt keine neuen sensiblen Daten.

## Implementation Details

1. `apnsIds(headers)` als reine Funktion mit der UUID-Prüfung; `sendHttp2` übernimmt im `response`-Handler neben `:status` die beiden IDs und gibt sie im `resolve` mit (`{ status, ...ids, ...reasonOf(...) }`).
2. `deliver` bestimmt aus der letzten Antwort die Ausgangszeile über eine kleine reine Hilfsfunktion `describe(response, env)` (Endung ` STATUS ENV[ id=…][ unique=…]`), die für die drei Ausgänge verwendet wird; der `catch`-Zweig loggt `apns send failed error ENV`.
3. `wake` loggt nach `listTokens` einmal `apns wake devices=N`; der `catch` dort loggt `apns send failed list`.
4. Reihenfolge je Gerät unverändert: JWT, senden, Wiederholung, Löschen, danach die eine Logzeile (bei Löschen nach dem erfolgreichen `dropToken`, wie heute).
5. Voraussetzung für AC-7 (Vorbestand #963): `server/test/migrate.test.ts` „AC-3: after a failed run the lock is free …“ war lokal auch auf `origin/main` rot, weil alle Testdateien eine Datenbank teilen und das Advisory-Lock datenbankweit gilt. Der Test bekommt eine eigene Wegwerf-Datenbank (`freshDatabase`); seine Aussage bleibt gleich. Damit sind es drei Dateien (+25/−6 im Test), innerhalb der Limits.

## Test Plan

### Automated Tests (TDD RED)

Server-Tests im bestehenden Stil (`node --test`, `send` injiziert, `log` abgefangen, Postgres über `./server/scripts/test-local.sh`). Die neuen Tests sind vor der Umsetzung rot.

- [ ] Test 1: GIVEN ein Gerät und Apple antwortet 200 mit `apnsId` und `uniqueId` WHEN `wake` THEN steht im Log genau `apns wake devices=1` und `apns sent 200 production id=<apnsId> unique=<uniqueId>`.
- [ ] Test 2: GIVEN 200 ohne IDs und 200 mit nur `apnsId` WHEN `wake` THEN lauten die Zeilen `apns sent 200 production` bzw. `apns sent 200 production id=<apnsId>` (Sandbox-Gerät: `sandbox`).
- [ ] Test 3: GIVEN Antwort-Header mit `apns-id: "kein-uuid GEHEIM"`, mit zwei Werten als Array und mit gültiger UUID WHEN `apnsIds` liest THEN werden nur gültige UUIDs übernommen, Ungültiges fehlt als Schlüssel, und kein Wert aus einem ungültigen Header erscheint je im Log.
- [ ] Test 4: GIVEN Fehlerstatus (500, 429, 403 `InvalidProviderToken`, 410 ohne reason, 403 `ExpiredProviderToken` ohne Wiederholungserlaubnis) WHEN `wake` THEN `apns send failed STATUS ENV` mit Status und Umgebung, Token bleiben, kein `reason`-Text im Log.
- [ ] Test 5: GIVEN 410 `Unregistered`, 400 `BadDeviceToken`, 400 `DeviceTokenNotForTopic` WHEN `wake` THEN `apns token dropped STATUS ENV`, die Zeilen sind gelöscht, fremde Konten unberührt.
- [ ] Test 6: GIVEN ein Konto ohne Gerät WHEN `wake` THEN genau eine Zeile `apns wake devices=0`, kein Sendeversuch.
- [ ] Test 7: GIVEN Netzfehler (`ECONNREFUSED`) und Timeout WHEN `wake` THEN `apns send failed error ENV`, der Fehlertext erscheint nicht.
- [ ] Test 8: GIVEN alle Ausgänge (Erfolg, Fehler, Löschen, Netzfehler, JWT-Fehler, Wiederholung nach Ablauf, 0 Geräte, Datenbankfehler bei `listTokens`) WHEN geloggt wird THEN passt jede Zeile auf den Regex aus „Logformat“, kein Token (`abcdef…`), keine Konto-Kennung, kein JWT, kein `reason`-Freitext und kein Fehlertext kommt vor, und nichts geht an `console.log`/`console.error`.
- [ ] Test 9: GIVEN ein lokaler HTTP/2-Server, der Header `apns-id` und `apns-unique-id` sendet WHEN `sendHttp2` läuft THEN enthält die Antwort beide IDs; ohne die Header bleibt `{ status: 200 }` bzw. `{ status: 410, reason }` unverändert.
- [ ] Test 10: GIVEN die bestehenden Tests zu Anfrage, JWT-Cache, Wiederholversuch, Löschregel und „wake wirft nie“ WHEN sie laufen THEN sind sie grün, nur ihre Log-Erwartungen folgen dem neuen Format (die Anfrage-Ausprägungen bleiben unberührt).

## Acceptance Criteria

- **AC-1:** GIVEN Apple antwortet 2xx WHEN `wake` für ein Konto mit Geräten läuft THEN schreibt der Waker genau eine Zeile `apns wake devices=N` und je Gerät genau eine Zeile `apns sent STATUS ENV` mit `id=`/`unique=` nur für vorhandene, kanonische UUIDs (Tests 1, 2).
- **AC-2:** GIVEN `apns-id` oder `apns-unique-id` ist keine einzelne kanonische UUID WHEN `sendHttp2` die Header liest THEN fehlt der Schlüssel in `ApnsResponse`, und der Wert erscheint nie im Log (Tests 3, 9).
- **AC-3:** GIVEN Apple antwortet mit Fehlerstatus, Löschstatus oder gar nicht WHEN `wake` läuft THEN lautet die Zeile `apns send failed STATUS ENV`, `apns token dropped STATUS ENV` bzw. `apns send failed error ENV`, ohne Freitext (Tests 4, 5, 7).
- **AC-4:** GIVEN ein Konto ohne Gerät WHEN `wake` läuft THEN steht genau `apns wake devices=0` im Log und es wird nichts gesendet (Test 6).
- **AC-5:** GIVEN beliebige Sendeausgänge WHEN alle Logzeilen gesammelt werden THEN passt jede auf den Regex des Abschnitts „Logformat“ und enthält weder Token, Konto-Kennung, JWT, Body, `reason`-Freitext noch Fehlertext (Test 8).
- **AC-6:** GIVEN die Änderung WHEN die bestehenden Tests zu Anfrage (Kopfzeilen, Priorität 5, Payload), JWT-Cache, Wiederholversuch, Löschregel und „wake wirft nie“ laufen THEN sind sie grün; Sendeweg, Payload, Priorität, Wiederholversuch und Löschregel sind in `apns.ts` unverändert (Test 10, Diff-Durchsicht).
- **AC-7:** GIVEN der Stand WHEN `./server/scripts/test-local.sh` läuft THEN sind `npm run typecheck` und `npm test` grün.

## Abgrenzung (Out of Scope)

- **Gerätelog per xctrace** (`pushDisallowed`, Hintergrundstart, `wake-up ended`): nur nach Hennings „jetzt ist ein Test möglich“, eigener Schnitt.
- **Produktentscheidung** (Alternativen unten): erst nach dem Sendebeleg.
- **Mac hat kein Gerätetoken gemeldet:** eigener Punkt, nicht Teil des iPhone-Symptoms.
- **HTTP/2-Verbindungswiederverwendung** (eine Sitzung je Push widerspricht Apples Empfehlung): erklärt keine Nichtzustellung, eigener Schnitt falls nötig.
- Änderungen an `mcp.ts`, `main.ts`, `devices.ts`, der App, Migrationen: keine.

## Alternativen

Nach dem Sendebeleg zu entscheiden; keine ist Teil dieses Schnitts. Die Entscheidung „stiller Weckruf“ stammt aus #795 S5.

| Weg | Was | Gekippt würde |
|---|---|---|
| **A: stiller Weckruf akzeptieren (heutiger Weg)** | „meist binnen Minuten, nicht garantiert“; Rückfall: Öffnen und täglicher BGAppRefresh | nichts |
| **B: sichtbare Mitteilung mit `mutable-content` und Notification Service Extension** | wird zuverlässiger zugestellt, die Extension stößt den Abruf an; je Claude-Auftrag sieht Henning eine Mitteilung; neues Target mit Zugriff auf den Speicher über die App-Gruppe | die Entscheidung „still“ aus #795 S5 (Produktentscheidung); Geräteliste: neues Target, Entitlements, `project.yml` |
| **C: kein Push** | Aufträge nur beim Öffnen und per BGAppRefresh; Claude sagt ehrlich „wird beim nächsten Öffnen ausgeführt“ | den Weckruf aus #795 S5 insgesamt (Sender, Registrierung, Empfang würden entfernt) |

## Abnahme

Der Schnitt berührt keinen Pfad der Geräteliste (`server/` ohne App, kein `project.yml`, keine Entitlements, keine `Info.plist`). Stufe 1 sind die Server-Tests, Stufe 2 die Dienst-Tests samt Typprüfung (`./server/scripts/test-local.sh`); ein Simulatorlauf der App entfällt, weil die App nicht geändert wird. Der Abschlussbericht sagt: „Kein Pfad der Geräteliste berührt.“ Gerätepunkte gibt es nicht.

## Definition of Done

- [ ] AC-1 bis AC-7 erfüllt, Server-Tests und Typprüfung grün
- [ ] PR mit `Refs #960` (Issue bleibt offen, bis der Sendebeleg vorliegt und die Ursache entschieden ist) gemergt
- [ ] Deploy auf `rennwienix` (`bash scripts/deploy-loose-ends.sh` mit `LE_COMMIT` des Merge-Stands, Muster wie S5b; `/health` 200, im Log kein `apns config invalid`); Beleg `docs/artifacts/feat-960-weckruf-sendeergebnis/deploy.txt`
- [ ] Live-Beleg im Dienstlog beim nächsten natürlichen Auftrag von Claude: `apns wake devices=1` gefolgt von `apns sent 200 production id=<uuid>` (ggf. mit `unique=<uuid>`), abgelegt in `docs/artifacts/feat-960-weckruf-sendeergebnis/dienstlog.txt` (nur diese Zeilen, keine Fremdzeilen). Eine Probe-Aufgabe in Hennings Daten nur nach seinem Ja; sonst wird gewartet, der Stand steht im Issue. Der Beleg ist bewusst Teil der Definition of Done und kein AC, weil er einen echten Auftrag voraussetzt, den Claude ohne Hennings Ja nicht auslösen darf.
- [ ] Befund im Issue #960 kommentiert (Apple nimmt an oder nicht; bei Annahme Folgeschritt Gerätelog und Entscheidung A/B/C per Auswahl an Henning), Board-Karte aktuell, Memory geschrieben

## Changelog

- 2026-11-19: Initial spec created
- 2026-11-19: migrate-Test isoliert (#963), Voraussetzung für AC-7
