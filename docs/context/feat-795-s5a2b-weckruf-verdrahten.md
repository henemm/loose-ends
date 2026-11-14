# Context: feat-795-s5a2b-weckruf-verdrahten

## Request Summary
#795 Schnitt S5a-2b: Den fertigen, bisher unverdrahteten APNs-Absender (`server/src/apns.ts`, S5a-2a, PR #922) im Dienst
einhängen, so dass ein neu abgelegter Auftrag von Claude die Geräte des Kontos per stiller Mitteilung weckt. Umfang ist in
`docs/specs/feat-795-schnitt-5a2a-apns-absender.md` (Abschnitt „Nicht im Umfang / Folgeschnitt“, Zeile 151) festgelegt.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/mcp.ts` (294 Z.) | `mcpHandler(pool)` (Z. 192); `putOrder` an zwei Stellen: `capturing` (Z. 87) und `storing` (Z. 118, alle übrigen Auftragswerkzeuge). Hier kommt `{ wake? }` hinein, ein gemeinsamer Helfer statt zwei `putOrder`-Aufrufen, `void wake(owner)` nur bei `stored`. |
| `server/src/orders.ts` | `putOrder(pool, account, doc): "stored" \| "duplicate"` (Z. 69) — bleibt unverändert, liefert die Unterscheidung. |
| `server/src/apns.ts` (128 Z.) | `apnsConfigFromEnv(env)` (undefined / Config / Error mit Variablennamen), `createWaker({ config, pool, send?, now?, log?, origins? }).wake(account)` wirft nie. |
| `server/src/main.ts` (311 Z.) | `StartOptions` (Z. 27), `start()` erzeugt `mcpHandler(pool)` (Z. 205), `main()` liest Konfigurationen mit Exit 1 vor Pool und Port (Muster `apple config invalid:`, `oauth config invalid:`, Z. 270–292). |
| `server/test/mcp-write.test.ts` | Muster für Auftragswerkzeuge gegen `mcpHandler(pool)` (Z. 30). Ort für „stored weckt, duplicate nicht, Weckfehler stört nicht“. |
| `server/test/main.test.ts` | Startabbruch per `spawn` des echten Prozesses (Z. 446, Fälle Z. 468ff., 540). Ort für „halbe APNs-Konfiguration bricht ab“. |
| `docs/reference/claude-abschrift-vertrag.md` | Absatz zu `POST /app/device` (Z. 184–187) nennt den „späteren Weckruf“; der Weckruf-Absatz kommt dazu, ohne neuen ```json-Block. |
| `CLAUDE.md` | Zeile zu `src/apns.ts` sagt „not wired yet“ — wird endgültig. |

## Existing Patterns
- Konfiguration aus der Umgebung: keine Variable → Funktion aus; teilweise/ungültig → `main()` loggt `<x> config invalid: <VAR>` und `process.exit(1)` vor Pool und Port; nie den Wert.
- Optionale Abhängigkeiten als Feld in `StartOptions` (z. B. `auth.config`, `oauth.keys`), Tests geben eigene Stellvertreter hinein.
- Log nur feste Ereignisnamen, nie Token, Konto, Text.
- Fire-and-forget: `void promise`, der Absender wirft nie (eigene Fänger für Log und Senden).

## Dependencies
- Upstream: `createWaker` / `apnsConfigFromEnv` (`apns.ts`), `listTokens`/`dropToken` (`devices.ts`), `putOrder` (`orders.ts`).
- Downstream: alle Auftragswerkzeuge des MCP (`capture_task`, `complete_task`, `set_due`, `set_next`, `park_task`, `add_subtask`); `main.ts`-Prozessstart auf `rennwienix`.

## Existing Specs
- `docs/specs/feat-795-schnitt-5a2a-apns-absender.md` — Absender, legt 2b-Umfang fest.
- `docs/specs/feat-795-schnitt-5a1-geraet-anmelden.md` — `device_tokens`, `POST /app/device`.

## Risks & Considerations
- Der Weckruf darf die Antwort an Claude nicht verzögern oder scheitern lassen (nicht `await`en; ein abgelehntes Promise darf keine unbehandelte Ablehnung erzeugen — `wake` wirft laut Vertrag nie, trotzdem absichern).
- `duplicate` (gleiche Auftrags-ID zweimal) darf nicht erneut wecken.
- Live-Dienst hat keine `APNS_*` gesetzt → Weckruf aus, Verhalten unverändert; erst S5b setzt Schlüssel. Ein Ausrollen von 2b ist damit unschädlich.
- Teilweise gesetzte `APNS_*` stoppen den Start (bewusst) — beim Ausrollen nichts halb setzen.
- Offene Prozess-Handles im Test (http2-Sitzungen) — Tests mit Stellvertreter-`send`.
- Lokale Flake `migrate.test.ts` AC-3 (#869), keine Regression.
- Alternative: Weckruf statt im MCP-Teil in `putOrder` (orders.ts) einhängen — einfacher an einer Stelle, aber `orders.ts` bliebe dann nicht rein datenbanknah; Vorgänger-Spec entscheidet für `mcp.ts`.

## Analysis

### Type
Feature (Schnitt S5a-2b von #795): den fertigen APNs-Absender einhängen. Kein Fehler, nichts zu reproduzieren.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/mcp.ts` | MODIFY | `mcpHandler(pool, { wake? } = {})`; `capturing` und `storing` gehen über einen gemeinsamen Helfer `storeOrder(pool, owner, doc, wake)` (checkOrder → putOrder → bei `stored` Weckruf, nie bei `duplicate`). Weckruf ohne `await`, synchroner Wurf und abgelehntes Promise abgefangen (`Promise.resolve().then(() => wake(owner)).catch(() => {})`), damit die Antwort an Claude weder wartet noch scheitert. Helfer exportiert, weil `duplicate` über ein Werkzeug nicht erzeugbar ist (die ID vergibt der Dienst per `randomUUID`). ~+20/−12 |
| `server/src/main.ts` | MODIFY | `StartOptions.apns?: { config?: ApnsConfig; send?: …; wake?: (account) => Promise<void> }`; `start()` baut `createWaker({ config, pool, send, log: logError })` nur mit `config` und reicht `wake` an `mcpHandler`; ohne Konfiguration kein Weckruf, Verhalten wie heute. `main()` ruft `apnsConfigFromEnv()` nach den OAuth-Schlüsseln, Fehler → `apns config invalid: <Meldung des Absenders, nennt nur die Variable>`, Exit 1 vor Pool und Port. ~+15 |
| `server/test/mcp-write.test.ts` (oder neue `mcp-wake.test.ts`) | MODIFY/CREATE | (a) jedes Auftragswerkzeug (`capture_task`, `complete_task`, `set_due`, `set_next`, `park_task`, `add_subtask`) ruft `wake` genau einmal mit dem Konto; (b) Helfer mit vorhandener ID → `duplicate`, kein Weckruf; (c) `wake` wirft synchron oder lehnt ab → Werkzeug antwortet trotzdem `waiting`, Auftrag liegt in der Tabelle, keine unbehandelte Ablehnung; (d) abgelehnte Werkzeuge (Text fehlt, Abschrift geändert, `checkOrder` lehnt ab) wecken nicht; (e) ohne `wake` wie bisher. ~+90 |
| `server/test/main.test.ts` | MODIFY | Echter Prozess per `spawn`: je eine fehlende `APNS_*`-Variable und ein unlesbarer Schlüssel → Exit 1 mit `apns config invalid: APNS_…`, Wert nie im Log; keine `APNS_*` → Start wie bisher. Dazu `start({ apns: { config, send } })` mit Stellvertreter-`send`: `capture_task` über `/mcp` löst einen Sendeaufruf an das gemeldete Gerät aus (Kette Werkzeug → Waker → Token-Tabelle → send). ~+40 |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Absatz „Weckruf“: nach jedem neu abgelegten Auftrag stille Mitteilung (`content-available`, Schlüssel `looseends`) an alle Geräte des Kontos; kein Weckruf bei bekannter ID; ohne Schlüssel im Dienst keiner; die App holt wie bisher selbst. Kein neuer json-Codeblock (der erste Block ist das Testbeispiel von `mcp-write.test.ts`). |
| `CLAUDE.md` | MODIFY | Zeile zu `src/apns.ts`: „not wired yet“ → eingehängt in `mcp.ts`/`main.ts`, `APNS_*` all-or-nothing, halbe Konfiguration stoppt den Start. Hotspot, vor dem PR `origin/main` einmischen. |

### Scope Assessment
- Files: 6 (davon 2 nur Doku); Code und Tests 4, im Rahmen.
- Estimated LoC: ≈ +170/−15 (Produktcode ≈ +35, Tests ≈ +130).
- Risk Level: LOW — der Live-Dienst hat keine `APNS_*`, dort bleibt alles wie heute; der Weckruf hängt nur an `stored`, und der Absender wirft laut Vertrag nie.

### Technical Approach
Wie in der Vorgänger-Spec festgelegt: Weckruf in `mcp.ts`, Verdrahtung in `main.ts`, Konfiguration all-or-nothing nach dem Muster von Apple und OAuth.

Festlegungen für die Spec:
1. Ein Helfer für alle Auftragswerkzeuge statt zwei `putOrder`-Stellen, damit kein künftiges Werkzeug den Weckruf vergisst.
2. Weckruf strikt nebenläufig (`void`, doppelt abgesichert); die MCP-Antwort hängt nie daran. Zwei Aufträge kurz hintereinander = zwei Weckrufe (bewusst, kein Bündeln).
3. Log des Absenders über `logError` (stderr), nur feste Ereignisnamen.
4. Beim Herunterfahren kann ein laufender Weckruf an der geschlossenen Datenbank scheitern; er fängt das selbst (`apns send failed`). Der Auftrag liegt dann schon, die App holt ihn beim nächsten Anlass. Kein Warten auf offene Weckrufe in `close()`.
5. Abnahme: `./server/scripts/test-local.sh` und `server.yml` grün; kein echter Apple-Aufruf (S5b). Ausrollen auf `rennwienix` ist unschädlich (keine `APNS_*` gesetzt) und folgt mit S5b. Kein Pfad der Geräteliste berührt.

### Alternatives
- **Weckruf in `putOrder` (`orders.ts`):** eine Stelle, aber die Datenschicht bekäme eine Netzwirkung, und jeder Test von `putOrder` bräuchte einen Waker. Verworfen (Vorgänger-Spec S5a-2a).
- **Datenbank-Auslöser (`LISTEN/NOTIFY` auf `orders`):** weckt auch bei Aufträgen aus anderen Wegen, braucht aber eine dauerhafte Hörverbindung je Prozess und eine Migration; für einen einzigen Schreibweg zu schwer.
- **Kein Push, App fragt häufiger nach (Hintergrundabruf):** ohne Apple-Schlüssel, aber iOS bestimmt den Takt selbst (oft Stunden), Aufträge von Claude kämen spät an. Dafür fiele die S5-Entscheidung „Weckruf per stiller Mitteilung“ in #795.

### Open Questions
- keine (Umfang durch die Vorgänger-Spec festgelegt; reine Dienständerung ohne Produktentscheidung).
