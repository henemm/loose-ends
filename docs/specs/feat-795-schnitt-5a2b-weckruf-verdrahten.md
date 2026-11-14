---
entity_id: feat-795-schnitt-5a2b-weckruf-verdrahten
type: feature
created: 2026-11-14
updated: 2026-11-14
status: draft
workflow: feat-795-s5a2b-weckruf-verdrahten
---

# Spec: Weckruf verdrahten, Schnitt S5a-2b (#795)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S5a-2b des Weckrufs; das Issue bleibt offen (`Refs #795`, nie `Closes #795`).
Analyse: `docs/context/feat-795-s5a2b-weckruf-verdrahten.md`; Gesamtplan und PO-Entscheidung (Variante A): `docs/context/feat-795-s5-weckruf.md`.
Vorgänger: `docs/specs/feat-795-schnitt-5a2a-apns-absender.md` (Absender `server/src/apns.ts`, PR #922); deren Abschnitt „Nicht im Umfang / Folgeschnitt“ legt den Umfang dieses Schnitts fest.

## Für den PO

Sobald Claude einen neuen Auftrag ablegt (eine Aufgabe erfassen, abhaken, verschieben), soll der Dienst die Geräte des Kontos mit einer stillen Mitteilung anstupsen, damit die App den Auftrag zeitnah holt. Dieser Schnitt hängt den fertigen Baustein dafür im Dienst ein. Solange auf dem Server kein Apple-Schlüssel eingetragen ist, geschieht nichts; der Schlüssel kommt erst im nächsten Schnitt. Für dich sichtbar ändert sich noch nichts.

## Purpose

`server/src/mcp.ts` ruft nach jedem **neu abgelegten** Auftrag (`putOrder` liefert `stored`) den Weckruf des Kontos auf, nebenläufig und fehlerfest; bei `duplicate` nie. `server/src/main.ts` baut den Waker aus `APNS_*`, alles oder nichts: keine Variable gesetzt → kein Weckruf, Verhalten wie heute; halb gesetzt oder ungültig → Start bricht mit Exit 1 ab, vor Pool und Port. **Regeln vor Modell:** Protokoll- und Betriebsarbeit, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — der Schnitt setzt den Zuschnitt der Vorgänger-Spec (S5a-2a) und die PO-Entscheidung vom 2026-11-13 (Variante A) um; ADR-21 (Weg B) bleibt unverändert, keine bestehende Entscheidung fiele.
- **Rationale:** (1) Ein gemeinsamer Helfer für alle Auftragswerkzeuge, damit kein künftiges Werkzeug den Weckruf vergisst. (2) Der Weckruf hängt nie an der Antwort an Claude: der Auftrag liegt schon, die App holt ihn notfalls beim nächsten Anlass selbst. (3) Konfiguration nach dem Muster von Apple und OAuth: alles oder nichts, nie ein halber Zustand im Betrieb.

## Source

**Files:** `server/src/mcp.ts`, `server/src/main.ts`, `server/test/mcp-wake.test.ts` (neu), `server/test/main.test.ts`, `docs/reference/claude-abschrift-vertrag.md`, `CLAUDE.md` (höchstens eine Zeile)
**Identifier:** `mcpHandler`, `storeOrder`, `StartOptions.apns`, `main`

### Festlegungen

1. **Ein Helfer:** `export async function storeOrder(pool, owner, doc, wake?)` in `mcp.ts`: `checkOrder` (die Meldung geht wie bisher unverändert zurück, `isError`), dann `putOrder`, bei `stored` der Weckruf, Antwort `{orderID, state: "waiting"}`. `capturing` und `storing` rufen nur noch ihn. Exportiert, weil `duplicate` über ein Werkzeug nicht erzeugbar ist (die ID vergibt der Dienst per `randomUUID`).
2. **Weckruf nebenläufig und fehlerfest:** `void Promise.resolve().then(() => wake(owner)).catch(() => {})`, ohne `await`. Ein synchroner Wurf, eine Ablehnung oder ein langsames `wake` ändern Antwort und Laufzeit nicht und erzeugen keine unbehandelte Ablehnung. Zwei Aufträge kurz hintereinander geben zwei Weckrufe (bewusst, kein Bündeln).
3. **`mcpHandler(pool, { wake? } = {})`:** `wake: (account: string) => Promise<void>`; ohne `wake` wie bisher.
4. **`StartOptions.apns?: { config?: ApnsConfig; send?: (request: ApnsRequest) => Promise<ApnsResponse>; wake?: (account: string) => Promise<void> }`:** `start()` nimmt `apns.wake`, sonst, nur mit `apns.config`, `createWaker({ config, pool, send, log: logError }).wake`; ohne beides kein Weckruf. Das Log des Absenders geht über `logError` (stderr), nur feste Ereignisnamen.
5. **`main()`:** `apnsConfigFromEnv(process.env)` nach den OAuth-Schlüsseln und vor `publicUrl`/Pool/Port; Fehler → `logError("apns config invalid: <Meldung>")` (die Meldung des Absenders nennt nur den Variablennamen, nie den Wert), `process.exit(1)`; das Ergebnis geht als `apns: { config }` an `start`.
6. **Herunterfahren:** ein laufender Weckruf kann an der geschlossenen Datenbank scheitern; der Waker fängt das selbst (`apns send failed`). Kein Warten auf offene Weckrufe in `close()`.
7. **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; keine neuen Pakete.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `createWaker`, `apnsConfigFromEnv`, `ApnsConfig`, Typ der Sendefunktion (`apns.ts`) | bestehend (S5a-2a), unverändert |
| `putOrder` (`orders.ts`), `checkOrder` | bestehend, unverändert |
| `listTokens`, `dropToken`, `putDevice` (`devices.ts`) | bestehend, unverändert |
| Muster `appleConfigFromEnv`, `oauthKeysFromEnv` (`main.ts`) | Vorlage |
| `server/test/db.ts` (`freshPool`), `mcp-write.test.ts`-Muster, `main.test.ts`-Spawn-Muster | Testgrundlage |
| `node:test`, `pg` | bestehend, keine neuen Pakete |
| Upstream (erst S5b) | APNs HTTP/2 und ein .p8-Schlüssel mit APNs-Recht |
| Downstream | S5b (nginx, Schlüssel, Ausrollen), S5c (App meldet Token, erkennt `looseends`) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| server/src/mcp.ts | MODIFY | `storeOrder`, `mcpHandler(pool, { wake? })`, `capturing`/`storing` darauf umgestellt |
| server/src/main.ts | MODIFY | `StartOptions.apns`, Waker in `start()`, `apnsConfigFromEnv` mit Exit 1 in `main()` |
| server/test/mcp-wake.test.ts | CREATE | Weckruf je Werkzeug, `duplicate`, Fehlerfestigkeit, Ablehnungen, ohne `wake` |
| server/test/main.test.ts | MODIFY | Startabbruch bei halber APNs-Konfiguration, Kette Werkzeug → Waker → Tabelle → `send` |
| docs/reference/claude-abschrift-vertrag.md | MODIFY | Absatz „Weckruf“ (kein neuer ```json-Block) |
| CLAUDE.md | MODIFY | Zeile zu `src/apns.ts`: „not wired yet“ → eingehängt (reine Doku, Hotspot) |

### Estimated Changes

- Dateien: 4 Code-Dateien (2 Produkt, 2 Test; `mcp-wake.test.ts` ist neu, `main.test.ts` erweitert) plus 2 Doku-Dateien; innerhalb von 4–5 Code-Dateien.
- LoC ≈ +170/−15: Produktcode ≈ +35/−12, Tests ≈ +130, Doku ≈ +10. **Tests getrennt gezählt wie in S5a-1 und S5a-2a** (Tech-Lead-Entscheidung, dort angenommen): ohne Tests liegt der Schnitt weit unter ±250, mit Tests ebenfalls.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Migration, keine Oberfläche, keine neuen Pakete, kein `generate`.

## Implementation Details

`storeOrder` ersetzt den Rumpf von `storing` (`checkOrder` mit Fehlerrückgabe, `putOrder`, Antwort) und den von `capturing` ab `checkOrder`; die Prüfungen vor der Ordnungsprüfung („kein Konto“, „Text fehlt“, `expected`) bleiben dort. `wake` wird durch `capturing(pool, wake)`, `completing(pool, wake)` usw. an die Werkzeugfabriken gereicht (ein weiteres Argument je Fabrik) und fließt aus `mcpHandler`. `putOrder` bleibt unverändert und liefert die Unterscheidung `stored | duplicate`. In `start()` entsteht der Waker einmal je Prozess, vor `mcpHandler(pool, { wake })`.

## Test Plan

Alle Tests mit `node:test` und `node:assert/strict`, gegen das Wegwerf-Postgres (`freshPool`, `migrate`, Konten mit `findOrCreate`); kein Netz außer dem lokalen Testserver, kein echter Apple-Aufruf. `main.test.ts` startet für Abbruchfälle den echten Prozess per `spawn`. Tabellengetrieben, ein Fall je Zeile.

### Automated Tests (TDD RED)

- [ ] GIVEN `storeOrder`, `mcpHandler(pool, { wake })` und `StartOptions.apns` existieren nicht WHEN die neuen Tests laufen THEN schlagen sie fehl (RED).
- [ ] Test „mcp-wake: jedes auftragswerkzeug weckt genau einmal“ (AC-1)
- [ ] Test „mcp-wake: duplicate weckt nicht“ (AC-2)
- [ ] Test „mcp-wake: weckfehler stoert nicht“ (AC-3)
- [ ] Test „mcp-wake: abgelehnte werkzeuge wecken nicht“ (AC-4)
- [ ] Test „mcp-wake: ohne wake wie bisher“ (AC-5)
- [ ] Test „main: halbe apns-konfiguration bricht ab“ (AC-6)
- [ ] Test „main: keine apns-variablen startet wie bisher“ (AC-7)
- [ ] Test „main: capture_task sendet ueber den waker“ (AC-8)
- [ ] AC-9, AC-10: kein dauerhafter Test, Beleg in `/60-validate`

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Acceptance Criteria

- **AC-1:** Jedes Auftragswerkzeug weckt genau einmal: GIVEN `mcpHandler(pool, { wake })` mit einem zählenden `wake` und ein Konto mit Abschrift WHEN `capture_task`, `complete_task`, `set_due`, `set_next`, `park_task` und `add_subtask` je einmal erfolgreich aufgerufen werden THEN antwortet jedes mit `state: "waiting"`, und `wake` wurde je Aufruf genau einmal mit der Konto-ID des Aufrufers aufgerufen (insgesamt sechsmal, nie mit einem anderen Konto). Test: „mcp-wake: jedes auftragswerkzeug weckt genau einmal“.
- **AC-2:** `duplicate` weckt nicht: GIVEN ein bereits abgelegter Auftrag WHEN `storeOrder` mit derselben ID und demselben Konto erneut aufgerufen wird THEN `putOrder` meldet `duplicate`, die Antwort entspricht der bisherigen für diesen Fall, und `wake` wird nicht aufgerufen; der erste Aufruf mit neuer ID hat genau einmal geweckt. Test: „mcp-wake: duplicate weckt nicht“.
- **AC-3:** Weckfehler stören den Auftrag nicht: GIVEN ein `wake`, das (a) synchron wirft, (b) ablehnt, (c) erst nach 200 ms auflöst WHEN `capture_task` aufgerufen wird THEN antwortet das Werkzeug in allen drei Fällen ohne `isError` mit `state: "waiting"` (bei (c) ohne auf `wake` zu warten, die Antwort trifft vor dem Auflösen ein), der Auftrag liegt in `orders`, und der Handler `process.on("unhandledRejection")` bleibt leer. Test: „mcp-wake: weckfehler stoert nicht“.
- **AC-4:** Abgelehnte Aufrufe wecken nicht: GIVEN `capture_task` mit leerem Text, `set_due` mit geänderter Abschrift (`generatedAt` stimmt nicht), `complete_task` mit unbekannter Aufgabe, ein Aufruf ohne Konto und ein Auftrag, den `checkOrder` ablehnt (über `storeOrder`) WHEN sie laufen THEN antwortet jeder mit seiner bisherigen Fehlermeldung und `isError`, nichts liegt in `orders`, und `wake` wird nie aufgerufen. Test: „mcp-wake: abgelehnte werkzeuge wecken nicht“.
- **AC-5:** Ohne `wake` wie bisher: GIVEN `mcpHandler(pool)` ohne zweites Argument WHEN die sechs Auftragswerkzeuge laufen THEN antworten sie wie vor diesem Schnitt, die Aufträge liegen in `orders`, es gibt keinen Fehler und keine unbehandelte Ablehnung; die bestehenden Tests in `mcp-write.test.ts` laufen unverändert grün. Test: „mcp-wake: ohne wake wie bisher“.
- **AC-6:** Halbe Konfiguration bricht den Start ab: GIVEN der echte Prozess (`spawn`) mit je genau drei der vier `APNS_*`-Variablen (je eine fehlt) und mit einem unlesbaren `APNS_PRIVATE_KEY` WHEN er startet THEN endet er mit Exit 1, schreibt auf stderr `apns config invalid: ` mit dem Namen der betroffenen Variable, bindet den Port nie, und weder der Wert des Schlüssels noch von Team, Schlüssel-ID oder Topic steht in der Ausgabe. Test: „main: halbe apns-konfiguration bricht ab“.
- **AC-7:** Ohne `APNS_*` startet der Dienst wie bisher: GIVEN der echte Prozess ohne `APNS_*` und mit sonst gültiger Umgebung WHEN er startet THEN beantwortet `/health` nach dem Migrieren 200, es gibt keine Zeile `apns config invalid`, und `capture_task` legt einen Auftrag ab, ohne dass ein Weckruf versucht wird (keine Zeile `apns …` auf stderr). Test: „main: keine apns-variablen startet wie bisher“.
- **AC-8:** Kette Werkzeug → Waker → Tabelle → Senden: GIVEN `start({ apns: { config, send } })` mit gültiger Config, Stellvertreter-`send` und einem Konto mit einem per `putDevice` gemeldeten Gerät WHEN `capture_task` über `/mcp` aufgerufen wird THEN erhält der Stellvertreter genau einen Aufruf mit dem Token des Geräts und dem Topic der Config; ein zweites Konto mit Gerät bekommt keinen Aufruf; mit einem `send`, das 410 `Unregistered` meldet, ist die Zeile danach aus `device_tokens` weg. Kein echter Apple-Aufruf. Test: „main: capture_task sendet ueber den waker“.
- **AC-9:** Grenze und Länge: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/mcp.ts`, `server/src/main.ts`, `server/test/mcp-wake.test.ts`, `server/test/main.test.ts` und höchstens `CLAUDE.md`; `apns.ts`, `devices.ts`, `orders.ts`, `app-routes.ts`, `.github/`, `project.yml`, `server/package.json` und jede Swift-Datei sind unverändert (keine neue Abhängigkeit); jede Funktion hat höchstens 50 Zeilen. **Kein dauerhafter Test** (ein Test gegen `origin/main` scheitert im flachen CI-Checkout): Beleg einmalig in `/60-validate`, Befehl, Ausgabe und Funktionslängen im Validierungsprotokoll.
- **AC-10:** Doku: `docs/reference/claude-abschrift-vertrag.md` enthält einen Absatz „Weckruf“ (nach jedem neu abgelegten Auftrag stille Mitteilung `content-available`, Schlüssel `looseends`, an alle Geräte des Kontos; kein Weckruf bei bekannter ID; ohne Schlüssel im Dienst keiner; die App holt wie bisher selbst) und **keinen neuen** ```json-Block (`grep -c '```json'` gleich dem Stand auf `origin/main`); `CLAUDE.md` nennt `src/apns.ts` nicht mehr als „not wired yet“, sondern als in `mcp.ts`/`main.ts` eingehängt mit `APNS_*` alles oder nichts. **Kein dauerhafter Test**: Beleg einmalig in `/60-validate`.

## Alternativen

- **Weckruf in `putOrder` (`orders.ts`):** eine Stelle, aber die Datenschicht bekäme eine Netzwirkung, und jeder Test von `putOrder` bräuchte einen Waker. Verworfen, wie in der Vorgänger-Spec festgelegt; es fiele keine ADR.
- **Datenbank-Auslöser (`LISTEN/NOTIFY` auf `orders`):** weckt auch bei Aufträgen aus anderen Wegen, braucht aber eine dauerhafte Hörverbindung je Prozess, Wiederverbinden und eine Migration; für einen einzigen Schreibweg zu schwer. Nicht gebaut; keine ADR.
- **Kein Push, die App fragt häufiger nach (Hintergrundabruf):** ohne Apple-Schlüssel, aber iOS bestimmt den Takt selbst (oft Stunden), Aufträge von Claude kämen spät an. Dafür fiele die S5-Entscheidung „Weckruf per stiller Mitteilung“ (PO, Variante A, #795) und mit ihr der Zuschnitt aus der Spec von S5a-1; ADR-21 bliebe unberührt.
- **Auf offene Weckrufe in `close()` warten:** sauberer beim Herunterfahren, aber ein hängender Apple-Aufruf würde den Stopp verzögern; der Waker fängt Fehler selbst, der Auftrag liegt schon. Nicht gebaut.

## Risiken

- **Teilweise gesetzte `APNS_*` stoppen den Start** (bewusst). Beim Ausrollen nichts halb setzen; der Live-Dienst hat keine `APNS_*`, dort bleibt alles wie heute.
- **Offene Prozess-Handles im Test** (http2-Sitzungen): Tests nutzen Stellvertreter-`send`, nie den echten Transport.
- **Hotspot:** `CLAUDE.md` wird von parallelen Sitzungen berührt; vor dem PR `origin/main` einmischen.
- **Lokale Flake** `migrate.test.ts` AC-3 (#869) ist bekannt und keine Regression dieses Schnitts.
- **Zwei Aufträge kurz hintereinander = zwei Weckrufe;** harmlos, kein Bündeln.

## Nicht im Umfang / Folgeschnitt

- **S5b:** nginx, neuer APNs-Schlüssel im Portal (Henning meldet sich nur an), Geheimnisse auf `rennwienix`, Ausrollen mit gesetzten `APNS_*`, erster echter Apple-Aufruf.
- **S5c:** App meldet Token samt Umgebung, erkennt den Weckruf am Schlüssel `looseends`; Vorbedingung Datenschutztext.
- Keine Änderung an `apns.ts`, `devices.ts`, `orders.ts`, `app-routes.ts`, an der Swift-App und an den Migrationen.

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulator nötig. Nachweis: `./server/scripts/test-local.sh` grün (Wegwerf-Postgres, `npm run typecheck` und `npm test`) und `server.yml` auf dem PR grün. Kein echter Apple-Aufruf.
- Ausrollen ist unschädlich (ohne `APNS_*` bleibt der Weckruf aus) und folgt mit S5b.
- Stufe 3 entfällt. **Kein Pfad der Geräteliste berührt.**

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] #795 kommentiert (Stand S5a-2b, Folge S5b), Board-Karte aktuell

## Changelog

- 2026-11-14: Initial spec created (Schnitt S5a-2b von #795, Einhängen des Absenders aus S5a-2a)
