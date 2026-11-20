# Context: feat-960-sparsam-wecken

## Request Summary
PO-Entscheidung 2026-11-20 (#960): Der Dienst weckt ein Gerät höchstens einmal je Viertelstunde; Aufträge in dieser Zeit
kommen mit dem einen Weckruf mit. Grund: iOS drosselt stille Pushes (~3/h, Geräte-Budget), der Dienst weckte bisher je
Auftrag (9 Weckrufe in 5 s bei einer Auftragsserie am 2026-11-20 06:53Z).

## Befund (Gerätelog 2026-11-20, Issue #960)
- Apple nimmt jeden Weckruf an (`apns sent 200 production`).
- iPhone am Kabel: dasd `pushLaunch … DecisionToRun: 1`, App im Hintergrund gestartet, `wake-up ended: woken`, Auftrag nach 3 s abgeholt.
- iPhone auf Akku (06:41Z, 06:46Z): binnen 6+ min nicht abgeholt. Mac-App holt sofort ab, wenn sie läuft.
- App-Seite (`PushWakeUp`, `IOSAppDelegate`, `UIBackgroundModes remote-notification`) arbeitet korrekt; Änderung nur am Dienst.

## Related Files
| File | Relevance |
|------|-----------|
| server/src/apns.ts | `createWaker().wake(account)`: listet Geräte (`listTokens`), sendet je Gerät; hier kommt die Drossel je Gerät hin (`now` ist schon injizierbar) |
| server/src/mcp.ts:116-125 | `storeOrder` ruft `wake(owner)` losgelöst nach jedem neu gespeicherten Auftrag |
| server/src/main.ts:150-155 | `wakeFor`: ein Waker je Prozess, also reicht Zustand im Speicher |
| server/src/devices.ts | `DeviceDoc { token, environment }`, `listTokens`, `dropToken` |
| server/test/apns.test.ts | Tests mit `send`-Stub, `now`, `log`-Sammler; neue Tests für die Drossel hierhin |

## Existing Patterns
- Uhr injiziert (`now`), Sender injiziert (`send`), Log nur feste Ereignisnamen (Test „log nur feste namen“).
- `wake` wirft nie; Fehler nur als feste Logzeile.
- Ein Prozess, ein Waker (`main.ts`), kein geteilter Zustand über Prozesse.

## Dependencies
- Upstream: `listTokens`/`dropToken` (Postgres), `sendHttp2`, APNs.
- Downstream: `storeOrder` (alle Auftragswerkzeuge in `mcp.ts`), Dienstlog (#960 S1, `apns wake devices=N`).

## Offene Entwurfsfragen für /20-analyse
- Ohne Nachzügler bleibt ein Auftrag liegen, wenn das Gerät nach dem ersten Weckruf schon abgeholt hat und der nächste
  Auftrag innerhalb der 15 min kommt. Alternative: ein Nachzügler-Weckruf am Fensterende (höchstens einer), dann max. 4/h je Gerät.
- Schlüssel der Drossel: Gerätetoken (je Gerät, wie entschieden) statt Konto.
- Logzeile für einen gedrosselten Weckruf (fester Name, z. B. `apns wake skipped`), ohne Token.
- Alternative mit `apns-collapse-id` allein reicht nicht: sie fasst nur nicht zugestellte Pushes zusammen, spart kein Budget beim Senden.

## Risks & Considerations
- Dienst-Änderung, Ausrollen per `scripts/deploy-loose-ends.sh` in `henemm-infra` auf `rennwienix`; App unverändert, keine Gerätestufe nötig.
- Zustand im Speicher geht bei Neustart verloren (dann darf sofort geweckt werden, unkritisch).
- Testaufgaben aus dem Gerätelauf am 2026-11-20 per complete_task abgehakt.
