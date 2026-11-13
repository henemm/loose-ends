# Spike: Signatur im Simulator, damit DeviceIdentity den Schlüsselbund nutzen kann (#795 S3b-2)

2026-11-13, nur Simulator „iPhone 17“ (D553352F-…, iOS 27.2), kein echtes Gerät, kein Produktcode geändert.

## Ergebnis

- **Weg 1 (Nachsignieren der fertigen .app mit `codesign --entitlements`) scheitert.** Die App startet nicht mehr:
  runningboardd meldet `spawn failed, error=163: Security policy issue`. Ad-hoc-signierte Berechtigungen wie
  `application-identifier`/`keychain-access-groups` in der Code-Signatur ohne Profil lehnt die Sicherheitsrichtlinie des Hosts ab.
- **Weg 2 (Bau mit Ad-hoc-Signatur statt `CODE_SIGNING_ALLOWED=NO`) gelingt.** Xcode schreibt die Berechtigungen dann als
  *simulierte Berechtigungen* in den Abschnitt `__TEXT,__entitlements` der ausführbaren Datei (`LooseEnds.app-Simulated.xcent`,
  mit `application-identifier = XK87E2B3VR.com.henning.looseends`); die Code-Signatur selbst bleibt leer (`codesign -d --entitlements -` → `[Dict]`).
  Auftrag „Spike“ nach **5 s** `outcome=done`, Abschrift `tasks=1 / Spike`, kein `-34018`, kein `deviceIdentity` im Log.

## Weg 1: Nachsignieren (gescheitert)

```
$ cp -R <DerivedData session>/Debug-iphonesimulator/LooseEnds.app spike-LooseEnds.app
$ codesign -d --entitlements - spike-LooseEnds.app          # vorher
CodeDirectory v=20400 size=418 flags=0x20002(adhoc,linker-signed)   (keine Berechtigungen)
$ codesign --force --sign - --entitlements spike-min.entitlements spike-LooseEnds.app
    # spike-min.entitlements: application-identifier + keychain-access-groups = XK87E2B3VR.com.henning.looseends
$ codesign -d --entitlements - spike-LooseEnds.app          # nachher
[Key] application-identifier  [String] XK87E2B3VR.com.henning.looseends
[Key] keychain-access-groups  [Array] [String] XK87E2B3VR.com.henning.looseends
CodeDirectory v=20400 size=430 flags=0x2(adhoc)
$ xcrun simctl install <udid> spike-LooseEnds.app && xcrun simctl launch <udid> com.henning.looseends -LEDebugService … -LEDebugSession … -onboardingDone YES
Simulator device failed to launch com.henning.looseends. No such process
runningboardd: submitAndStart completed, info=spawn failed, error=163: Security policy issue
runningboardd: Launch failed with Error Domain=NSPOSIXErrorDomain Code=163 "Launchd job spawn failed"
```

## Weg 2: Bau mit Ad-hoc-Signatur (gelungen)

Wegwerf-Kopie von `scripts/sim.sh` im Scratch-Ordner, darin nur `CODE_SIGNING_ALLOWED=NO` ersetzt durch
`CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER=`; eigener DerivedData-Schlüssel, damit der
Sitzungsbau unberührt bleibt:

```
$ cp scripts/sim.sh <scratch>/sim-spike.sh
$ sed -i '' 's/CODE_SIGNING_ALLOWED=NO/CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER= /g' <scratch>/sim-spike.sh
$ CLAUDE_PROJECT_DIR=<worktree> CLAUDE_SESSION_ID=spike-signatur <scratch>/sim-spike.sh build
… Write Auxiliary File Entitlements-Simulated.plist … Build Succeeded
$ plutil -p …/LooseEnds.build/LooseEnds.app-Simulated.xcent
application-identifier => XK87E2B3VR.com.henning.looseends, aps-environment, applesignin, icloud-container-identifiers,
icloud-services CloudKit, siri, ubiquity-kvstore-identifier, application-groups => group.com.henning.looseends
$ otool -s __TEXT __entitlements …/LooseEnds.app/LooseEnds
Contents of (__TEXT,__entitlements) section     (Inhalt vorhanden)
$ git diff --stat scripts/sim.sh
(leer — die echte sim.sh ist unverändert)
```

Danach Dienst, Auftrag und Start wie unten (Installation per `xcrun simctl install`, Start wie `sim.sh launch`).

### Log des gelungenen Laufs (Auszug, claude-sync)

```
[claude-sync] send ended: done
[claude-sync] send ended: done
[claude-sync] pull ended: busy
[claude-sync] pull ended: done
[claude-sync] send ended: done
```

Suche nach `-34018` im Zeitfenster: einziger Treffer ist die Befehlszeile des `log`-Aufrufs selbst; kein Eintrag von securityd
für LooseEnds. `deviceIdentity`: 0 Treffer. Kategorie `Persistence`: keine Meldung („App-group entitlement unavailable“ fehlt),
der Store liegt jetzt im App-Group-Container (`…/Containers/Shared/AppGroup/D14B25A4-…/Library/Application Support/LooseEnds.store`).

### Was App-Gruppe und iCloud beim Start tun

- **App-Gruppe:** funktioniert, der Store wandert vom Datencontainer in den App-Group-Container. Folge: ein anderer, frischer
  Bestand als beim unsignierten Bau (für Spec Teil 3, Schritt 5 egal, er sucht zuerst dort).
- **CloudKit:** die Spiegelung startet jetzt und scheitert harmlos mit `134400 Unable to initialize without an iCloud account
  (CKAccountStatusNoAccount)`; das App-Log meldet `CloudKit event setup succeeded=false ended=true`. Kein Absturz, kein Einfluss auf den Durchgang.
- **iCloud-Schlüsselwertspeicher:** `Error synchronizing with cloud for store <(XK87E2B3VR.com.henning.looseends)>` (kein Konto), harmlos;
  vorher kam stattdessen `BUG IN CLIENT OF KVS … without a store identifier`.
- **Apple Intelligence:** `InferenceError::operationNotAllowed::Simulator is not supported`, wie immer im Simulator.
- **Neu im Bild:** Nach `-onboardingDone YES` steht die Startseite da („Neu 1 zum Durchsehen“, das ist die Aufgabe „Spike“),
  aber der System-Dialog „„Loose Ends“ möchte dir Mitteilungen senden“ liegt darüber (`spike-start.png`, geöffnet und angesehen).
  Für den Screenshot von AC-15 braucht es also noch einen Weg an diesem Dialog vorbei.

## Protokoll Weg 1 (Lauf mit der nachsignierten App)

```
UDID iPhone 17 = D553352F-E7E6-4A9A-B1F5-190001E01113

$ ls -la /tmp/loose-ends-testlauf.lock 2>/dev/null && cat /tmp/loose-ends-testlauf.lock/pid 2>/dev/null || echo "Testsperre frei"
Testsperre frei
(Ausgang 0)

$ server/scripts/local-service.sh > svc.log 2>&1 &   (09:06:06Z)
Postgres on 127.0.0.1:60720, data in /var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.rTcZHtY5wy
Dienst auf http://localhost:60721 (pid 46169)
STATE=/var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.rTcZHtY5wy/state.env

$ ID=$(fx order "Spike")
18aeb165-9301-4b1d-ad3e-bc7b40eb3c03

$ xcrun simctl boot "$udid" 2>/dev/null; xcrun simctl bootstatus "$udid" -b >/dev/null; echo gebootet
gebootet
(Ausgang 0)

$ xcrun simctl terminate "$udid" com.henning.looseends 2>/dev/null; xcrun simctl install "$udid" "$app" && echo installiert
installiert
(Ausgang 0)

$ xcrun simctl launch "$udid" com.henning.looseends -LEDebugService "$SERVICE_URL" -LEDebugSession "$SESSION_TOKEN" -onboardingDone YES   (09:06:21Z)
An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=3):
Simulator device failed to launch com.henning.looseends.
No such process
Underlying error (domain=NSPOSIXErrorDomain, code=3):
	Application launch for 'com.henning.looseends' did not return a process handle nor launch error.
	No such process

$ fx result "$ID"   # alle 2 s, höchstens 60 s, bis outcome=done
waiting
(FRIST ABGELAUFEN)

$ fx transcript
none
(Ausgang 0)

$ xcrun simctl spawn "$udid" log show --start "2026-11-13 10:06:21" --info --predicate <claude-sync, Persistence, securityd -34018 von LooseEnds>
Timestamp                       Thread     Type        Activity             PID    TTL  

$ grep-Zähler
-34018 von LooseEnds: 1
deviceIdentity: 0

$ xcrun simctl terminate "$udid" com.henning.looseends
An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=3):
Simulator device failed to terminate com.henning.looseends.
found nothing to terminate
Underlying error (domain=NSPOSIXErrorDomain, code=3):
	The request to terminate "com.henning.looseends" failed. found nothing to terminate
	found nothing to terminate
(Ausgang 3)

$ kill -TERM 46120
Dienst-Skript beendet, Ausgang 143

$ test -e "$work_dir" && echo "Temp-Ordner DA" || echo "Temp-Ordner fehlt"
Temp-Ordner fehlt
(Ausgang 0)

$ lsof -nP -iTCP:"$PORT" -sTCP:LISTEN || echo "Port $PORT frei"
Port 60721 frei
(Ausgang 0)
```
ERGEBNIS: GESCHEITERT

## Protokoll Weg 2 (Lauf mit dem ad-hoc gebauten Stand)

```
UDID iPhone 17 = D553352F-E7E6-4A9A-B1F5-190001E01113

$ ls -la /tmp/loose-ends-testlauf.lock 2>/dev/null && cat /tmp/loose-ends-testlauf.lock/pid 2>/dev/null || echo "Testsperre frei"
Testsperre frei
(Ausgang 0)

$ server/scripts/local-service.sh > svc.log 2>&1 &   (09:09:40Z)
Postgres on 127.0.0.1:60947, data in /var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.i04RVui5SU
Dienst auf http://localhost:60948 (pid 50207)
STATE=/var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.i04RVui5SU/state.env

$ ID=$(fx order "Spike")
427c750a-9e81-405b-afd9-2a8429cd8a20

$ xcrun simctl boot "$udid" 2>/dev/null; xcrun simctl bootstatus "$udid" -b >/dev/null; echo gebootet
gebootet
(Ausgang 0)

$ xcrun simctl terminate "$udid" com.henning.looseends 2>/dev/null; xcrun simctl install "$udid" "$app" && echo installiert
installiert
(Ausgang 0)

$ xcrun simctl launch "$udid" com.henning.looseends -LEDebugService "$SERVICE_URL" -LEDebugSession "$SESSION_TOKEN" -onboardingDone YES   (09:09:44Z)
com.henning.looseends: 50327

$ fx result "$ID"   # alle 2 s, höchstens 60 s, bis outcome=done
result
outcome=done
taskID=1540C611-C45A-4511-A6BD-54A1D842DA77
(erreicht nach 5 s)

$ fx transcript
tasks=1
Spike
(Ausgang 0)

$ xcrun simctl spawn "$udid" log show --start "2026-11-13 10:09:44" --info --predicate <claude-sync, Persistence, securityd -34018 von LooseEnds>
Timestamp                       Thread     Type        Activity             PID    TTL  
2026-11-13 10:09:47.322988+0100 0x3ec81b   Info        0x0                  50327  0    LooseEnds: (LooseEnds.debug.dylib) [com.henning.looseends:Sync] Listening for CloudKit mirroring events
2026-11-13 10:09:47.409294+0100 0x3ec8d3   Info        0x0                  50327  0    LooseEnds: (CoreData) [com.apple.coredata:CloudKit] CoreData+CloudKit: -[NSCloudKitMirroringDelegate _setUpCloudKitIntegration:](574): <NSCloudKitMirroringDelegate: 0x102fb79f0>: Successfully enqueued setup reque
2026-11-13 10:09:47.410495+0100 0x3ec8d3   Info        0x0                  50327  0    LooseEnds: (CoreData) [com.apple.coredata:CloudKit] CoreData+CloudKit: -[NSCloudKitMirroringDelegate checkAndExecuteNextRequest](3616): <NSCloudKitMirroringDelegate: 0x102fb79f0>: Checking for pending requests.
2026-11-13 10:09:47.411895+0100 0x3ec8d3   Info        0x0                  50327  0    LooseEnds: (CoreData) [com.apple.coredata:CloudKit] CoreData+CloudKit: -[NSCloudKitMirroringDelegate checkAndExecuteNextRequest]_block_invoke(3629): <NSCloudKitMirroringDelegate: 0x102fb79f0>: Executing: <NSCloud
2026-11-13 10:09:47.660530+0100 0x3ec81b   Info        0x0                  50327  0    LooseEnds: (LooseEnds.debug.dylib) [com.henning.looseends:Sync] CloudKit event setup succeeded=false ended=false error=Unbekannter Fehler
2026-11-13 10:09:48.723633+0100 0x3ec81b   Info        0x0                  50327  0    LooseEnds: (LooseEnds.debug.dylib) [com.henning.looseends:claude-sync] send ended: done
2026-11-13 10:09:48.731971+0100 0x3ec8d3   Default     0x0                  50327  14   LooseEnds: (CoreData) [com.apple.coredata:CloudKit] CoreData+CloudKit: -[PFCloudKitSetupAssistant _checkAccountStatus:](439): Waiting on accountInfoWithCompletionHandler for store D0822DCF-8449-4FCE-90EA-9788C253
2026-11-13 10:09:48.761398+0100 0x3ec8e0   Default     0xa69d64             50327  14   LooseEnds: (CoreData) [com.apple.coredata:CloudKit] CoreData+CloudKit: -[PFCloudKitSetupAssistant _checkAccountStatus:]_block_invoke(346): Fetched account info for store D0822DCF-8449-4FCE-90EA-9788C253A0DB: <CKA
(null)
2026-11-13 10:09:48.767640+0100 0x3ec8d3   Error       0x0                  50327  14   LooseEnds: (CoreData) [com.apple.coredata:CloudKit] CoreData+CloudKit: -[NSCloudKitMirroringDelegate _performSetupRequest:]_block_invoke(1236): <NSCloudKitMirroringDelegate: 0x102fb79f0>: Failed to set up CloudKi
Error Domain=NSCocoaErrorDomain Code=134400 "Unable to initialize without an iCloud account (CKAccountStatusNoAccount)." UserInfo={NSLocalizedFailureReason=Unable to initialize without an iCloud account (CKAccountStatusNoAccount).}
2026-11-13 10:09:48.767730+0100 0x3ec8d3   Error       0x0                  50327  14   LooseEnds: (CoreData) [com.apple.coredata:CloudKit] CoreData+CloudKit: -[NSCloudKitMirroringDelegate recoverFromError:](2310): <NSCloudKitMirroringDelegate: 0x102fb79f0> - Attempting recovery from error: Error Do
2026-11-13 10:09:48.767787+0100 0x3ec8d3   Error       0x0                  50327  14   LooseEnds: (CoreData) [com.apple.coredata:CloudKit] CoreData+CloudKit: -[NSCloudKitMirroringDelegate _recoverFromError:withZoneIDs:forStore:inMonitor:](2623): <NSCloudKitMirroringDelegate: 0x102fb79f0> - Failed t
Recovery encountered the following error: (null):0
2026-11-13 10:09:48.767891+0100 0x3ec8d3   Info        0x0                  50327  0    LooseEnds: (CoreData) [com.apple.coredata:CloudKit] CoreData+CloudKit: -[NSCloudKitMirroringDelegate _finishedRequest:withResult:](3647): Finished request: <NSCloudKitMirroringDelegateSetupRequest: 0x105608230> 4
2026-11-13 10:09:48.767912+0100 0x3ec8d3   Info        0x0                  50327  0    LooseEnds: (CoreData) [com.apple.coredata:CloudKit] CoreData+CloudKit: -[NSCloudKitMirroringDelegate checkAndExecuteNextRequest](3616): <NSCloudKitMirroringDelegate: 0x102fb79f0>: Checking for pending requests.
2026-11-13 10:09:48.831644+0100 0x3ec81b   Info        0x0                  50327  0    LooseEnds: (LooseEnds.debug.dylib) [com.henning.looseends:Sync] CloudKit event setup succeeded=false ended=true error=Der Vorgang konnte nicht abgeschlossen werden. Unable to initialize without an iCloud account 
2026-11-13 10:09:49.034627+0100 0x3ec81b   Info        0x0                  50327  0    LooseEnds: (LooseEnds.debug.dylib) [com.henning.looseends:claude-sync] send ended: done
2026-11-13 10:09:49.034642+0100 0x3ec81b   Info        0x0                  50327  0    LooseEnds: (LooseEnds.debug.dylib) [com.henning.looseends:claude-sync] pull ended: busy
2026-11-13 10:09:49.062615+0100 0x3ec81b   Info        0x0                  50327  0    LooseEnds: (LooseEnds.debug.dylib) [com.henning.looseends:claude-sync] pull ended: done
2026-11-13 10:09:49.079279+0100 0x3ec8d3   Info        0x0                  50327  0    LooseEnds: (CoreData) [com.apple.coredata:CloudKit] CoreData+CloudKit: -[NSCloudKitMirroringDelegate checkAndExecuteNextRequest]_block_invoke(3632): <NSCloudKitMirroringDelegate: 0x102fb79f0>: No more requests to
2026-11-13 10:09:51.494104+0100 0x3ec81b   Info        0x8d6ed              50327  0    LooseEnds: (LooseEnds.debug.dylib) [com.henning.looseends:claude-sync] send ended: done

$ grep-Zähler
-34018 von LooseEnds: 1
deviceIdentity: 0

$ xcrun simctl terminate "$udid" com.henning.looseends
(Ausgang 0)

$ kill -TERM 50167
Dienst-Skript beendet, Ausgang 143

$ test -e "$work_dir" && echo "Temp-Ordner DA" || echo "Temp-Ordner fehlt"
Temp-Ordner fehlt
(Ausgang 0)

$ lsof -nP -iTCP:"$PORT" -sTCP:LISTEN || echo "Port $PORT frei"
Port 60948 frei
(Ausgang 0)
```
ERGEBNIS: GELUNGEN
