# Context: feat-960-weckruf-sendeergebnis

## Request Summary
Gerätetest 2026-11-19 (TestFlight mit Konto): Aufträge von Claude werden erst ausgeführt, wenn Henning die App öffnet
(„ohne dass ich an einem Gerät die App öffne, funktioniert es nicht“). Ob der Dienst den stillen Weckruf überhaupt
abschickt und Apple ihn annimmt, ist nicht belegt, weil der Sender Erfolg nicht loggt. #960 soll das belegen, die
Ursache klären und – falls der stille Push systembedingt nicht reicht – einen Weg entscheiden.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/apns.ts` | `createWaker().wake` → `deliver`: loggt nur `apns send failed`/`apns token dropped`/`apns jwt failed`; 2xx kehrt still zurück. Hier entsteht der Sendebeleg (Status, `apns-id`, Umgebung). `sendHttp2` liest die Antwort-Header nur für `:status`; `apns-id`/`apns-unique-id` gehen verloren. |
| `server/src/mcp.ts:114-125` | `storeOrder` ruft `wake(owner)` losgelöst, nur bei neu gespeichertem Auftrag; Fehler werden geschluckt. Ob `wake` überhaupt läuft, ist heute unsichtbar. |
| `server/src/main.ts:150-155` | `wakeFor`: ein Waker je Prozess, `log: logError`. |
| `server/src/devices.ts` | `listTokens`, `dropToken`. |
| `server/test/apns.test.ts` | Bestehende Tests des Senders (send injiziert, log abgefangen) – Muster für neue Tests. |
| `LooseEnds/Claude/PushWakeUp.swift` | App-Seite: `isWake` (Schlüssel `looseends`), `handle` mit 20-s-Frist, Log `wake-up ended: …` (Kategorie `push-wake-up`). |
| `LooseEnds/Notifications/IOSAppDelegate.swift`, `LooseEnds/Mac/MenuBarCapture.swift` | Delegates für Token und `didReceiveRemoteNotification`. |
| `LooseEnds/Claude/ClaudeSyncTrigger.swift` | `wake()` sendet, dann holt ab. |
| `project.yml:99-101,167` | `UIBackgroundModes: [remote-notification, fetch]` (iOS), Watch/anderes Target `[remote-notification]`. |

## Existing Patterns
- Dienst-Logs nennen nur Ereignisnamen, nie Token oder Inhalte (Datenschutz-Muster aller `src/*`), z. B. `oauth return refused`.
- `log`-Callback wird injiziert und in Tests abgefangen; `send` ist injizierbar (`ApnsRequest` → `ApnsResponse`).
- App-Log nur Fallnamen, `privacy: .public` nur für Enum-Beschreibungen.

## Dependencies
- Upstream: Apple APNs HTTP/2 (`api.push.apple.com`), `device_tokens` (eine Zeile, `production`, 64 Zeichen).
- Downstream: `storeOrder` in `mcp.ts` (alle Auftrags-Werkzeuge), Betrieb auf `rennwienix` (Deploy per `scripts/deploy-loose-ends.sh`, `docker logs`).

## Existing Specs
- `docs/specs/` Schnitte #795 S5a-2a (Sender), S5a-2b (Verdrahtung), S5c-1/S5c-2a (App-Kern, Empfang).
- Memory: Simulator kann `didReceiveRemoteNotification` nicht belegen (simctl push → nur Banner/1401); nur das Gerät belegt.

## Befund bisher
- Kein `apns send failed` seit 3 h → entweder Apple antwortete 2xx, oder `wake` lief gar nicht (z. B. Waker fehlt im Prozess).
  Beides ist heute nicht unterscheidbar.
- Nur **eine** Gerätezeile (`production`): der Mac hat (noch) kein Token gemeldet – eigener Punkt, nicht Teil des iPhone-Symptoms.
- Recherche (im Issue): stille Pushes sind best effort, gedrosselt (Priorität 5, Energie-Budget, Hintergrundaktualisierung
  aus, Stromsparmodus, weggewischte App = keine Zustellung bis zum nächsten Start).

## Risks & Considerations
- Logging darf kein Token, keine Konto-Kennung ausgeben; `apns-id` ist eine von Apple vergebene Zufalls-UUID und unkritisch.
- Ein erfolgreicher Sendebeleg beweist nur Annahme durch Apple, nicht Zustellung; die Zustellung belegt nur das Gerät
  (xctrace-Log, nur nach Hennings „jetzt ist ein Test möglich“).
- Wenn stille Pushes systembedingt nicht reichen, ist das eine Produktentscheidung (Alternative: sichtbare Mitteilung
  mit `mutable-content`/Notification Service Extension, die den Abruf auslöst; oder nur BGAppRefresh; oder „Annahme beim
  nächsten Öffnen“ akzeptieren).
- Server-Änderung braucht Deploy auf `rennwienix`; Server-Arbeit ist Claude-Sache.

## Analysis

### Type
Feature (Diagnose-Schnitt): Sendebeleg am Dienst, Voraussetzung für die Ursachenklärung. Kein Eingriff in den Sendeweg.

### Befund (Code gelesen, 2026-11-19)
- `deliver` in `server/src/apns.ts` kehrt bei 2xx still zurück; `sendHttp2` liest aus den Antwort-Headern nur `:status`,
  `apns-id`/`apns-unique-id` gehen verloren. Ein `wake`, der gar nicht sendet (kein Gerät gelistet), und ein von Apple
  angenommener Push sind im Log heute ununterscheidbar.
- Aus den Daten ausgeschlossen: falsches Topic oder falsche Umgebung hätten `400 DeviceTokenNotForTopic`/`BadDeviceToken`
  geliefert → Zeile gelöscht + `apns token dropped`. Die Zeile steht, kein Log → Apple hat sehr wahrscheinlich 200
  geantwortet. Belegt ist das erst mit dem Sendelog.
- Recherche (Apple, „Sending notification requests to APNs“): „Record this UUID [apns-id] to assist with debugging.“
  Priorität 5 sendet „based on power considerations“; Pushes können „grouped and delivered in bursts … throttled … not
  delivered“ werden; APNs speichert nur **eine** Mitteilung je Bundle-ID. `apns-unique-id` aus der Antwort erlaubt die
  Suche im Delivery Log der Push Notifications Console (WWDC23 10025); ob das für production gilt, ist widersprüchlich.
  Quellen: https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns,
  https://developer.apple.com/videos/play/wwdc2023/10025/, https://developer.apple.com/forums/thread/839448.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apns.ts` | MODIFY | `ApnsResponse` um `apnsId?`/`uniqueId?` (aus Antwort-Headern, nur kanonische UUID-Form übernommen); `deliver` loggt jeden Ausgang mit festem Namen + Status + Umgebung + IDs, z. B. `apns sent 200 production <apns-id> [<unique-id>]`, `apns send failed 403 production <apns-id>`; je `wake` eine Zeile `apns wake devices=<n>`. Nie Token, Konto, Reason-Freitext. |
| `server/test/apns.test.ts` | MODIFY | Fälle: 200 mit/ohne IDs, Fehler mit Status, 0 Geräte, Nicht-UUID-Header wird nicht geloggt; Test „log nur feste namen“ auf das neue Format (Regex) umstellen, Token/Konto weiter nie im Log. |

### Scope Assessment
- Files: 2 (+ Deploy auf rennwienix, kein App-Code)
- Estimated LoC: ~+70/-10
- Risk Level: LOW — nur Log-Ausgabe; Sendeweg, Payload und Token-Löschregel bleiben gleich.

### Technical Approach
1. Sendelog wie oben (feste Ereignisnamen, Zahlen, Umgebung, UUIDs; kein Freitext von Apple).
2. Deploy auf `rennwienix`; beim nächsten Auftrag Sendelog lesen: `apns wake devices=1` + `apns sent 200 production …`
   = Apple hat angenommen.
3. Danach Ursache am Gerät (Gerätelog per xctrace: `pushDisallowed`, Hintergrundstart, `wake-up ended`), nur nach
   Hennings „jetzt ist ein Test möglich“ — eigener Schnitt.
4. Produktentscheidung, falls Apple annimmt und das Gerät drosselt (Alternativen unten).

### Alternativen (nach dem Beleg zu entscheiden)
- **A, heutiger Weg (#795 S5 „stiller Weckruf“):** akzeptieren als „meist binnen Minuten, nicht garantiert“; Rückfall
  Öffnen + täglicher BGAppRefresh.
- **B, sichtbare Mitteilung + Notification Service Extension:** wird zuverlässiger zugestellt, die Extension stößt den
  Abruf an. Kippt die Entscheidung „still“ aus #795 S5, braucht ein neues Target mit Store-Zugriff über die App-Gruppe
  und eine Produktentscheidung (Henning sieht je Claude-Auftrag eine Mitteilung).
- **C, kein Push:** Aufträge nur beim Öffnen/BGAppRefresh; Claude sagt ehrlich „wird beim nächsten Öffnen ausgeführt“.
- Nebenbefunde, nicht Teil hier: Mac hat kein Gerätetoken gemeldet; neue HTTP/2-Sitzung je Push widerspricht Apples
  Empfehlung zur Verbindungs-Wiederverwendung, erklärt aber keine Nichtzustellung.

### Dependencies
- `mcp.ts` `storeOrder` (ruft `wake`, unverändert), `main.ts` `wakeFor` (`log: logError`, unverändert), `devices.ts`.

### Open Questions
- [ ] Live-Beleg nach dem Deploy: auf einen natürlichen Auftrag warten oder eine Probe-Aufgabe per Claude erfassen
      (landet in Hennings Daten)? Klärt die Spec; Empfehlung: natürlicher Auftrag, Probe nur nach seinem Ja.
