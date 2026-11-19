# Simulator-Beleg Weckruf (#795 S5c-2a, AC-12)

Stand: Commit `d4b2611` (RED), **Arbeitsstand ungesichert**: die GREEN-Änderungen (`PushWakeUp.swift`,
`IOSAppDelegate.swift`, `MenuBarCapture.swift`, `LooseEndsApp.swift`) lagen nur im Worktree, nicht committet.
Datum 2026-11-19, Simulator „iPhone 17“ `D553352F-E7E6-4A9A-B1F5-190001E01113`, iOS 27.2. Kein echtes Gerät berührt.
Bau: `LOOSEENDS_SIM_SIGN=1 ./scripts/sim.sh build` → `Build Succeeded`. Wegwerf-Dienst `server/scripts/local-service.sh`
(Bash mit `set -m`, Hintergrund, STATE-Datei gelesen), App vorher deinstalliert, Start mit
`-LEDebugService http://localhost:<port> -LEDebugSession <Token des Wegwerf-Dienstes> -onboardingDone YES`.
`fx` = `DATABASE_URL=… node server/scripts/local-fixture.ts` (nur 127.0.0.1). Ausgaben unverändert, Farbcodes entfernt.

## Ergebnis

| Teil | Stand | Beleg |
|---|---|---|
| Knoten im Debug-Weg gebaut, Token gemeldet | **erfüllt** | 18 s nach dem Start `device_tokens=1` im Wegwerf-Dienst: `observeSignIn` → `registerForRemoteNotifications` → `IOSAppDelegate` → `DeviceRegistration` → `POST /app/device` |
| Lauf 1: stiller Weckruf mit `looseends` holt den Auftrag | **nicht belegbar im Simulator** | `simctl push` lehnt ab: `UNErrorDomain 1401 „Notification has no user visible content“`; der Rückruf der App wird nie aufgerufen, Auftrag bleibt `waiting` |
| Lauf 2: Gegenprobe ohne `looseends` holt nichts | erfüllt, aber ohne Aussagekraft | dieselbe Ablehnung 1401; Auftrag bleibt `waiting`, kein „wake-up ended“ im Log |
| Variante (Abweichung): `alert` + `content-available` | nicht belegbar | `UNErrorDomain 2003 „Repository could not save notification. Source is not authorized.“` (Mitteilungsdialog nicht beantwortet) |

Befund: Im iOS-27.2-Simulator läuft `simctl push` über die Mitteilungsablage (UNErrorDomain). Ein Inhalt ohne sichtbaren
Teil wird mit 1401 abgewiesen, ein sichtbarer ohne Mitteilungserlaubnis mit 2003 (dieselbe Ablehnung wie bei `add` aus der
App, siehe #311). Der stille Weckruf erreicht `application(_:didReceiveRemoteNotification:)` im Simulator damit gar nicht. Das
deckt sich mit dem in der Spec genannten Vorbehalt (Forum 725200, Simulator-Rückruf unzuverlässig). Eine Internetsuche zu 1401
war in dieser Sitzung nicht möglich (kein Suchwerkzeug für den ausführenden Agenten); die Einordnung stützt sich auf den
Fehlertext und den eigenen Befund 2003 aus #311. Der Gerätebeweis bleibt in der Definition of Done (Stufe 3, TestFlight-Konto-Bau).

## Protokoll Lauf A (stille Weckrufe, wie in der Spec)

```
$ server/scripts/local-service.sh > svc.log 2>&1 &   (12:06:06Z)
Postgres on 127.0.0.1:60883, data in /var/folders/…/tmp.pK4cpxo7FY
Dienst auf http://localhost:60884 (pid 95279)
STATE=/var/folders/…/tmp.pK4cpxo7FY/state.env
$ xcrun simctl uninstall D553352F-E7E6-4A9A-B1F5-190001E01113 com.henning.looseends   (12:06:10Z)
(Ausgang 0)
$ LOOSEENDS_SIM_SIGN=1 ./scripts/sim.sh launch -LEDebugService "$SERVICE_URL" -LEDebugSession "$SESSION_TOKEN" -onboardingDone YES   (12:06:11Z)
[sim] Simulator bereit (iPhone 17).
com.henning.looseends: 95523
[sim] App gestartet (com.henning.looseends).
$ fx transcript   (12:06:29Z)
tasks=0
$ fx rows   (12:06:29Z)
accounts=1  sessions=1  transcripts=1  orders=0  order_results=0  apple_tokens=0  oauth_records=0  device_tokens=1
$ xcrun simctl launch D553352F-… com.apple.Preferences   # Loose Ends in den Hintergrund   (12:06:29Z)
com.apple.Preferences: 95684

## Lauf 1: Weckruf mit Schlüssel looseends
$ ID1=$(fx order "Weckruf Lauf 1")   (12:06:40Z)
2af164a0-2bc8-44da-a008-5ee581c1ff5a
$ fx result 2af164a0-…   # vor dem Push, App im Hintergrund   (12:06:46Z)
waiting
$ cat wake.apns
{"Simulator Target Bundle":"com.henning.looseends","aps":{"content-available":1},"looseends":{"v":1}}
$ xcrun simctl push D553352F-… com.henning.looseends wake.apns   (12:06:46Z)
An error was encountered processing the command (domain=UNErrorDomain, code=1401):
Simulator device failed to complete the requested operation.
Underlying error (domain=UNErrorDomain, code=1401):
	Notification has no user visible content
(Ausgang 121)
$ fx result 2af164a0-…   # alle 2 s, höchstens 40 s   (12:06:47Z)
waiting
(nach 40 s weiterhin ungeholt, 12:07:30Z)

## Lauf 2: Gegenprobe ohne Schlüssel looseends
$ ID2=$(fx order "Gegenprobe Lauf 2")   (12:07:33Z)
ab892ba3-a99a-4642-a9e6-d40952086519
$ cat foreign.apns
{"Simulator Target Bundle":"com.henning.looseends","aps":{"content-available":1}}
$ xcrun simctl push D553352F-… com.henning.looseends foreign.apns   (12:07:34Z)
… (domain=UNErrorDomain, code=1401): Notification has no user visible content
(Ausgang 121)
$ fx result ab892ba3-…   # alle 2 s, höchstens 30 s   (12:07:34Z)
waiting
(nach 30 s weiterhin ungeholt, 12:08:07Z)
$ fx rows   (12:08:07Z)
… orders=2  order_results=0  device_tokens=1

## Abschluss
$ xcrun simctl launch D553352F-… com.henning.looseends   (12:08:07Z)
com.henning.looseends: 95523
$ fx result ab892ba3-…   # alle 2 s, höchstens 30 s   (12:08:08Z)
waiting
(nach 30 s weiterhin ungeholt, 12:08:41Z)
$ ./scripts/sim.sh screenshot …/simulator-push.png   (12:08:45Z)
$ xcrun simctl terminate D553352F-… com.henning.looseends   (12:08:46Z)
(Ausgang 0)
$ kill -INT <local-service>   (12:08:46Z)
(Dienst beendet, Ausgang 130)
```

App-Log (`xcrun simctl spawn <udid> log stream --level info`, Kategorien `push-wake-up`, `claude-sync`,
`device-registration`, während des ganzen Laufs):

```
13:06:21.794889+0100 [claude-sync] send ended: done
13:06:21.877035+0100 [claude-sync] pull ended: done
13:06:21.908759+0100 [claude-sync] send ended: done
13:06:21.915627+0100 [claude-sync] pull ended: done
13:06:23.906259+0100 [claude-sync] send ended: done
```

Kein Eintrag `push-wake-up` (weder „wake-up ended: woken“ noch „deadline“): der Rückruf kam in beiden Läufen nicht an.
Kein Eintrag `device-registration`: der Registrierer loggt nur Fehlschläge, die Meldung gelang (`device_tokens=1`).

## Protokoll Lauf B (Abweichung: sichtbarer Inhalt, um die 1401-Sperre zu umgehen)

Gleicher Ablauf, frischer Dienst (12:09Z), App neu installiert; Inhalt jeweils mit `"alert":{"title":"Simulator-Probe"}`.

```
$ fx result 7b2ec5ab-…   # vor dem Push   (12:09:59Z)
waiting
$ xcrun simctl push D553352F-… com.henning.looseends wake.apns   (12:09:59Z)
An error was encountered processing the command (domain=UNErrorDomain, code=2003):
Underlying error (domain=UNErrorDomain, code=2003):
	Repository could not save notification. Source is not authorized.
(Ausgang 211)
$ fx result 7b2ec5ab-…   # 40 s   → waiting (12:10:43Z)
$ xcrun simctl push … foreign.apns   (12:10:47Z)  → dieselbe Ablehnung 2003
$ fx result 5621556c-…   # 30 s   → waiting (12:11:20Z)
$ fx rows → orders=2  order_results=0  device_tokens=1
$ kill -INT <local-service>   (12:11:59Z)  (Dienst beendet, Ausgang 130)
```

Log: wieder nur `claude-sync` beim Start (13:09:34–36), kein `push-wake-up`. Eine Mitteilungserlaubnis lässt sich per
`simctl privacy` nicht erteilen (kein Dienst `notifications`); den Systemdialog zu beantworten hätte eine UI-Automatisierung
gebraucht, die nicht Teil des Auftrags war.

## Bild

`simulator-push.png` (12:08 UTC, nach dem Zurückholen in den Vordergrund), geöffnet und angesehen: die Startseite
„Alles verknotet.“, Donnerstag 19. Nov., „Jetzt 0“, oben links „◀ Einstellungen“ (die App kam aus der Einstellungen-App
zurück). Darüber der Systemdialog „„Loose Ends“ möchte dir Mitteilungen senden“ mit „Nicht erlauben“ / „Erlauben“.

## Abweichungen und Nebenbefund

- **AC-12 ist im Simulator nicht erfüllbar**: Der stille Weckruf wird schon von `simctl push` abgewiesen (1401), bevor die
  App ihn sieht. Gezeigt ist: Knoten im Debug-Weg aktiv, Token beim Dienst gemeldet, ohne Weckruf bleibt ein Auftrag im
  Hintergrund ungeholt. Der eigentliche Weckruf-Pfad (`handle` → `wake()` → Holen) ist nur durch die Unit-Tests und am Gerät
  belegbar.
- **Nebenbefund Vordergrund**: Auch das Zurückholen in den Vordergrund holte Lauf 2 nicht (30 s `waiting`, kein
  `pull ended` im Log). Wahrscheinliche Ursache: Der offene Mitteilungsdialog hält die App inaktiv, deshalb kommt kein
  `didBecomeActive`. Das ist nicht weiter untersucht und betrifft den Auslöser aus S3b-1, nicht diesen Schnitt.
- Lauf B weicht mit sichtbarem Inhalt von der Spec ab; er war nur ein Versuch, die Simulator-Sperre zu umgehen.
- Dienste beendet (SIGINT, Ausgang 130, keine Restprozesse), App beendet.
