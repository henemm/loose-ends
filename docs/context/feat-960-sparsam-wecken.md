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

## Analysis

### Type
Feature (Dienst-Verhalten, PO-Entscheidung 2026-11-20). Kein App-Code, keine Gerätestufe.

### Recherche
- Apple, „Pushing background updates to your App“: Hintergrund-Pushes haben niedrige Priorität, das System kann sie
  drosseln; „don't try to send more than two or three per hour“. Quelle:
  https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app
- `apns-collapse-id` fasst nur beim Speichern nicht zugestellter Mitteilungen zusammen; Apple speichert ohnehin nur eine je
  App. Es spart kein Budget beim Senden → keine Alternative (siehe Kontext).

### Befund (Code gelesen 2026-11-20)
- `createWaker().wake(account)` sendet bei **jedem** Aufruf sofort an jedes Gerät; `storeOrder` ruft es je neu gespeichertem
  Auftrag. Eine Serie von 9 Aufträgen = 9 Weckrufe je Gerät in Sekunden.
- Uhr (`now`) und Sender (`send`) sind schon injiziert; ein Waker je Prozess (`main.ts` `wakeFor`) → Zustand im Speicher reicht.
- Zwei bestehende Tests („jwt cache und erneuerung“, „expiredprovidertoken …“) wecken dasselbe Gerät mehrfach binnen
  15 min (49/50 min, 0/10 min); sie testen den JWT-Cache, nicht die Drossel → sie bekommen den Abstand 0 per Option.

### Entwurf (Empfehlung)
Drossel je Gerätetoken (+ Umgebung) im Waker, „vorne sofort, hinten einmal nachfassen“:
1. Erster Auftrag: Gerät sofort wecken (wie heute), Zeitpunkt merken.
2. Weitere Aufträge binnen 15 min: kein Weckruf, stattdessen genau **ein** Nachzügler am Fensterende (Zeitpunkt + 15 min),
   egal wie viele Aufträge noch kommen. Ohne den Nachzügler bliebe ein Auftrag liegen, den der erste Abruf nicht mehr
   erwischt hat, bis Henning die App öffnet.
3. Der Nachzügler liest die Geräte des Kontos neu (ein inzwischen gelöschtes Token wird nicht mehr geweckt) und eröffnet
   ein neues Fenster. Damit gilt streng: höchstens ein Weckruf je Gerät je Viertelstunde (≤ 4/h im Dauerfeuer, sonst 1).
4. Log, feste Namen, nie Token oder Konto: `apns wake throttled ENV` (Weckruf fällt ins Fenster, Nachzügler schon geplant
   oder neu geplant) bzw. `apns wake later ENV` beim Planen; die Sendezeile des Nachzüglers ist die gewohnte `apns sent …`.
5. Optionen für Tests: `minGapMs` (Standard 15 min, JWT-Tests 0), `schedule` (Standard `setTimeout` mit `unref`, damit ein
   geplanter Nachzügler das Beenden nicht aufhält); Neustart verliert den Plan (dann weckt der nächste Auftrag sofort).

### Alternativen
- **B, Sammelpause vorne (z. B. 10 s nach dem ersten Auftrag wecken):** fängt eine Serie in einem Weckruf, kostet aber
  jedem Einzelauftrag 10 s und macht `wake` zeitversetzt (alle Tests umbauen). Verworfen für diesen Schnitt; kann folgen,
  wenn der Log zeigt, dass Nachzügler häufig sind.
- **C, Zeitpunkt in Postgres (`device_tokens.woken_at`):** übersteht Neustart und mehrere Prozesse. Kippt nichts, aber
  Migration + Schemaänderung für einen Vorteil, den ein Prozess nicht braucht (ADR „ein Waker je Prozess“, #795 S5a-2b).
- **D, Nachzügler nur, wenn noch Aufträge warten:** spart einen Weckruf, wenn Henning die App inzwischen geöffnet hat;
  braucht eine neue Abfrage in `orders.ts` (dritte Code-Datei). Später möglich, wenn der Log unnötige Nachzügler zeigt.
- **E, Schlüssel Konto statt Gerät:** einfacher, aber ein Gerät mit frischem Budget (Mac) würde mitgedrosselt; PO hat „je Gerät“ entschieden.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apns.ts` | MODIFY | Drossel je Gerät in `createWaker` (Map Schlüssel `env:token` → letzter Weckruf, geplanter Nachzügler), Optionen `minGapMs`, `schedule`, zwei feste Logzeilen |
| `server/test/apns.test.ts` | MODIFY | Fälle: zweiter Auftrag binnen 15 min → kein Senden + ein Nachzügler; dritter → kein zweiter Nachzügler; nach 15 min wieder sofort; Nachzügler weckt nicht ein inzwischen gelöschtes Token; Geräte getrennt gedrosselt; Logzeilen-Regex erweitert; JWT-Tests mit `minGapMs: 0` |
| `CLAUDE.md` | MODIFY | Absatz `src/apns.ts`: Drossel und Logzeilen in einem Halbsatz |

### Scope Assessment
- Files: 3
- Estimated LoC: +50/-5 (Quelle), +70/-5 (Tests), +1 (Doku) ≈ 130
- Risk Level: LOW–MEDIUM — nur der Dienst; Fehler wären „zu wenig wecken“ (Auftrag wartet bis zum Öffnen, wie vor #795 S5), nie Datenverlust.

### Dependencies
- `mcp.ts` `storeOrder` und `main.ts` `wakeFor` bleiben unverändert (Waker-Schnittstelle gleich).
- Ausrollen: Merge, dann `scripts/deploy-loose-ends.sh` auf `rennwienix` (henemm-infra), Beleg im Dienstlog.

### Open Questions
- keine an den PO; Nachzügler ist die wörtliche Umsetzung von „Aufträge in dieser Zeit kommen mit dem einen Weckruf mit“.

## Umfang-Freigabe (2026-11-20, /60-validate)

Endstand nach dem Race-Fix (F003): 46/-2 Quelle, 248/-6 Tests, 9/-4 main.test.ts, 1/-1 CLAUDE.md ≈ 318 LoC statt ≈130.
Überhang aus den Nebenläufigkeitstests des Nachzüglers. Henning: „So übernehmen“.
