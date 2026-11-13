# Nachweis A/B (#795 S3b-2, AC-12 bis AC-15, AC-18)

Vierter Lauf 2026-11-13, 11:42–11:43 UTC, Simulatoren „iPhone 17“ (A, D553352F-…) und „iPhone Air“ (B, 2E697CBC-…),
iOS 27.2. Ablauf der Spec Teil 3 wörtlich, inklusive Schritt 4b (Nachtrag 2026-11-13: Auftrag `due`, Neustart von B), mit
`LOOSEENDS_SIM_SIGN=1` (Teil 4) und `-onboardingDone YES`, frischer Dienst, neue Aufträge. Bash mit `set -m`, Skript im
Scratch-Ordner, Ausgabe unverändert (Farbcodes entfernt). Kein echtes Gerät berührt.

Vorbereitung vor Schritt 2: die App auf beiden Simulatoren deinstalliert (`xcrun simctl uninstall`, danach kein
App-Group-Container mehr). Grund: Ein dritter Lauf um 11:40 UTC (gleicher Ablauf, alle Fristen erreicht, Revision „Claude“
vorhanden) fand in B's Store noch die „Aufgabe von B“ des zweiten Laufs (`launch` installiert neu, der App-Group-Container
bleibt; Bild „2 zum Durchsehen“). Damit hätte die Abschrift-Abfrage in Schritt 4 auch die alte Aufgabe treffen können. Mit
leerem Store kann `tasks=1 / Aufgabe von B` nur die neue Aufgabe sein. Der vierte Lauf ersetzt den zweiten und dritten.

## Ergebnis

| AC | Stand | Beleg |
|---|---|---|
| AC-12 | erfüllt | Auftrag A nach 8 s `outcome=done`, Abschrift nach weiteren 3 s `tasks=1 / Aufgabe von A` |
| AC-13 | erfüllt | Auftrag B nach 4 s `result`, `outcome=done`, `taskID=97B40E9F-0EA9-417D-A4F5-19B360906374`; Abschrift nach 3 s `tasks=1 / Aufgabe von B` |
| AC-14 | erfüllt | Auftrag `due` (ID B2 `3e9b37dd-…`) nach Neustart von B in 7 s `outcome=done`, `taskID` gleich der aus AC-13. B's Store (App-Group-Container, genau ein Treffer), nur lesend: Aufgabe `ZID = 97B40E9F…6374`, „Aufgabe von B“, `ZCAPTUREDVIARAW = claude`, und genau eine Revision mit Grund „Claude“: Feld `dueDate`, Autor `user`, alt leer, neu `2026-11-19T23:00:00Z` |
| AC-15 | erfüllt | `b-aufgabe.png`, geöffnet und angesehen (unten) |
| AC-18 | erfüllt | Abschnitt „AC-18“ unten: `grep`, `bash -n`, Bau ohne Schalter gelingt und ist wieder unsigniert |

### AC-14: Auszug aus B's Store (nur lesend)

```
$ sqlite3 -readonly "$store" "SELECT hex(ZID), ZTITLE, ZCAPTUREDVIARAW, ZSTATUSRAW FROM ZTASKITEM WHERE hex(ZID) = '97B40E9F0EA9417DA4F519B360906374';"
97B40E9F0EA9417DA4F519B360906374|Aufgabe von B|claude|unprocessed
$ sqlite3 -readonly "$store" "SELECT hex(t.ZID), t.ZTITLE, t.ZCAPTUREDVIARAW, r.ZFIELDRAW, r.ZAUTHORRAW, r.ZREASON, r.ZOLDVALUE, r.ZNEWVALUE, … FROM ZREVISION r JOIN ZTASKITEM t ON t.Z_PK = r.ZTASK WHERE r.ZREASON = 'Claude' …"
97B40E9F0EA9417DA4F519B360906374|Aufgabe von B|claude|dueDate|user|Claude||2026-11-19T23:00:00Z|2026-11-13 11:43:27
$ sqlite3 -readonly "$store" "SELECT COUNT(*) FROM ZREVISION;"
1
$ sqlite3 -readonly "$store" "SELECT COUNT(*) FROM ZTASKITEM;"
1
```

Der neue Wert `2026-11-19T23:00:00Z` ist der 20. November, 00:00 Uhr Ortszeit (Europe/Berlin): der Auftrag trug
`2026-11-20T00:00:00Z` mit `hasTime: false`, die App legt ein reines Datum auf den Tagesbeginn. Der Auftrag kam ohne
`expectedDueDate` (erwartet: kein Datum); die Prüfung gegen den echten Bestand von B hielt (`done`, nicht `stale`).

### AC-15: Bild von B

`b-aufgabe.png` (11:43 UTC, Simulator iPhone Air, nach dem Neustart in Schritt 4b), geöffnet und angesehen: die Startseite,
nicht die Einführung. „Heute drängt nichts.“, Freitag 13. Nov., unter „Neu“ „1 zum Durchsehen ›“ und die Schreibzeile
„Was soll ich aufnehmen?“, „Jetzt 0“, darunter die Listen, lesbar „Lose Enden 1“ und „Erledigt“. Darüber liegt der
System-Dialog „„Loose Ends“ möchte dir Mitteilungen senden“ mit „Nicht erlauben“ / „Erlauben“ (laut Spec Teil 4 zulässig).

## AC-18: Signierter Bau nur auf Wunsch

```
$ grep -n 'CODE_SIGNING_ALLOWED=NO\|LOOSEENDS_SIM_SIGN\|CODE_SIGN_IDENTITY' scripts/sim.sh
347:    # der Schlüsselbund antwortet -34018. LOOSEENDS_SIM_SIGN=1 legt sie ad hoc in die App (Debug-Weg A/B, kein Konto);
350:    [ "${LOOSEENDS_SIM_SIGN:-}" = 1 ] && sign=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER=)
353:        xcodebuild "$@" -derivedDataPath "$SESSION_DERIVED_DATA" "${sign[@]:-CODE_SIGNING_ALLOWED=NO}" 2>&1 | tee "$BUILD_LOG" | xcbeautify || status=$?
355:        xcodebuild "$@" -derivedDataPath "$SESSION_DERIVED_DATA" "${sign[@]:-CODE_SIGNING_ALLOWED=NO}" 2>&1 | tee "$BUILD_LOG" || status=$?
439:# läuft unsigniert (CODE_SIGNING_ALLOWED=NO), also ohne App-Sandbox, und schreibt direkt ins Repo.
```

`CODE_SIGNING_ALLOWED=NO` ist der Standard an beiden `xcodebuild`-Stellen (353, 355; ohne Schalter ist das Feld leer und die
Ersetzung liefert genau dieses eine Argument wie bisher); `CODE_SIGN_IDENTITY=-` steht nur im Zweig von `LOOSEENDS_SIM_SIGN=1`
(350). Zeile 439 ist ein vorhandener Kommentar. Probe der Ersetzung in `/bin/bash` 3.2.57:

```
ohne Schalter:   <CODE_SIGNING_ALLOWED=NO>
mit Schalter:    <CODE_SIGN_IDENTITY=-><CODE_SIGN_STYLE=Manual><PROVISIONING_PROFILE_SPECIFIER=>
$ /bin/bash -n scripts/sim.sh
bash -n scripts/sim.sh: sauber
```

Bau mit Schalter (A/B-Lauf, Schritt 2): `Build Succeeded`, `otool -s __TEXT __entitlements …/LooseEnds` zeigt den Abschnitt.
`launch` baut nicht neu (es installiert nur `…/Debug-iphonesimulator/LooseEnds.app`); der Schalter steht dort laut Spec trotzdem.
Beide Bauarten nutzen dasselbe DerivedData der Sitzung. Bau ohne Schalter danach:

```
$ ./scripts/sim.sh build
note: Removed stale file '…/Debug-iphonesimulator/LooseEndsShare.appex/_CodeSignature'
Build Succeeded
[sim] Build erfolgreich.
$ otool -s __TEXT __entitlements …/LooseEnds.app/LooseEnds
…/LooseEnds.app/LooseEnds:          (kein Abschnitt: wieder ohne Berechtigungen)
$ codesign -dv …/LooseEnds.app
CodeDirectory v=20400 size=418 flags=0x20002(adhoc,linker-signed) hashes=10+0 location=embedded
$ grep -c "CODE_SIGNING_ALLOWED=NO" <DerivedData>/xcodebuild.log
1
```

Danach lief die ganze Unit-Suite ohne Schalter (`test-green-output.txt`).

## Protokoll vierter Lauf

## 1. Lokaler Dienst

```

$ server/scripts/local-service.sh > svc.log 2>&1 &   (11:42:34Z)
Postgres on 127.0.0.1:62580, data in /var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.zzf5DeAdH1
Dienst auf http://localhost:62581 (pid 77217)
STATE=/var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.zzf5DeAdH1/state.env

$ cut -d= -f1 "$state"
DATABASE_URL
PORT
SERVICE_URL
SESSION_TOKEN
(Ausgang 0)

$ echo "$SERVICE_URL"
http://localhost:62581
(Ausgang 0)

```
## Vorbereitung: A und B ohne Bestand aus früheren Läufen

```
iPhone 17 = D553352F-E7E6-4A9A-B1F5-190001E01113

$ xcrun simctl uninstall D553352F-E7E6-4A9A-B1F5-190001E01113 com.henning.looseends
(Ausgang 0)

$ xcrun simctl get_app_container D553352F-E7E6-4A9A-B1F5-190001E01113 com.henning.looseends group.com.henning.looseends
An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=2):
The operation couldn’t be completed. No such file or directory
No such file or directory
(kein App-Group-Container mehr)
iPhone Air = 2E697CBC-91E9-4B18-AC78-7D5DD70F91B4

$ xcrun simctl uninstall 2E697CBC-91E9-4B18-AC78-7D5DD70F91B4 com.henning.looseends
(Ausgang 0)

$ xcrun simctl get_app_container 2E697CBC-91E9-4B18-AC78-7D5DD70F91B4 com.henning.looseends group.com.henning.looseends
An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=2):
The operation couldn’t be completed. No such file or directory
No such file or directory
(kein App-Group-Container mehr)

```
## 2. Auftrag an A, Bau, Start von Simulator A

```

$ ID_A=$(fx order "Aufgabe von A")
4ffbd48d-51bb-464f-89c6-886fb99b6a82

$ LOOSEENDS_SIM_SIGN=1 ./scripts/sim.sh build 2>&1 | tail -3
[LooseEnds] Validate Embedded Binary LooseEndsWidgets.appex
Build Succeeded
[sim] Build erfolgreich.
(Ausgang 0)

$ otool -s __TEXT __entitlements "$HOME/Library/Developer/Xcode/DerivedData/LooseEnds-session-cached-churning-yao/Build/Products/Debug-iphonesimulator/LooseEnds.app/LooseEnds" | head -2
/Users/hem/Library/Developer/Xcode/DerivedData/LooseEnds-session-cached-churning-yao/Build/Products/Debug-iphonesimulator/LooseEnds.app/LooseEnds:
Contents of (__TEXT,__entitlements) section
(Ausgang 0)

$ LOOSEENDS_SIM_SIGN=1 LOOSEENDS_SIM="iPhone 17" ./scripts/sim.sh launch -LEDebugService "$SERVICE_URL" -LEDebugSession "$SESSION_TOKEN" -onboardingDone YES   (11:42:51Z)
[sim] Simulator bereit (iPhone 17).
com.henning.looseends: 77639
[sim] App gestartet (com.henning.looseends).

$ xcrun simctl list devices booted
== Devices ==
-- iOS 27.2 --
    iPhone Air (2E697CBC-91E9-4B18-AC78-7D5DD70F91B4) (Booted) 
    iPhone 17 (D553352F-E7E6-4A9A-B1F5-190001E01113) (Booted) 
-- iOS 27.2 --
-- watchOS 27.0 --
-- watchOS 27.2 --
(Ausgang 0)
UDID A = D553352F-E7E6-4A9A-B1F5-190001E01113

$ fx result "$ID_A"   # alle 2 s, höchstens 60 s, bis: outcome=done
result
outcome=done
taskID=F3646E44-E0BF-47D1-AD0F-44ADB42910F1
(erreicht nach 8 s, 11:43:04Z)

$ fx transcript   # alle 2 s, höchstens 60 s, bis: Aufgabe von A
tasks=1
Aufgabe von A
(erreicht nach 3 s, 11:43:07Z)

$ xcrun simctl terminate "$UDID_A" com.henning.looseends
(Ausgang 0)

```
## 3. Auftrag an B

```

$ ID_B=$(fx order "Aufgabe von B")
ef87c374-5b59-423b-ad9f-40a6aa4db91d

$ fx result "$ID_B"
waiting
(Ausgang 0)

```
## 4. Start von Simulator B

```

$ LOOSEENDS_SIM_SIGN=1 LOOSEENDS_SIM="iPhone Air" ./scripts/sim.sh launch -LEDebugService "$SERVICE_URL" -LEDebugSession "$SESSION_TOKEN" -onboardingDone YES   (11:43:08Z)
[sim] Simulator bereit (iPhone Air).
com.henning.looseends: 77945
[sim] App gestartet (com.henning.looseends).

$ xcrun simctl list devices booted
== Devices ==
-- iOS 27.2 --
    iPhone Air (2E697CBC-91E9-4B18-AC78-7D5DD70F91B4) (Booted) 
    iPhone 17 (D553352F-E7E6-4A9A-B1F5-190001E01113) (Booted) 
-- iOS 27.2 --
-- watchOS 27.0 --
-- watchOS 27.2 --
(Ausgang 0)
UDID B = 2E697CBC-91E9-4B18-AC78-7D5DD70F91B4

$ fx result "$ID_B"   # alle 2 s, höchstens 60 s, bis: outcome=done
result
outcome=done
taskID=97B40E9F-0EA9-417D-A4F5-19B360906374
(erreicht nach 4 s, 11:43:16Z)

$ fx transcript   # alle 2 s, höchstens 60 s, bis: Aufgabe von B
tasks=1
Aufgabe von B
(erreicht nach 3 s, 11:43:19Z)

```
## 4b. Fälligkeit an B, Neustart von B

```
taskID aus Schritt 4 = 97B40E9F-0EA9-417D-A4F5-19B360906374

$ ID_B2=$(fx due "$TASK_B" 2026-11-20T00:00:00Z)
3e9b37dd-7335-42c8-a02b-e3e0f9f2e215 (Ausgang 0)

$ fx result "$ID_B2"
waiting
(Ausgang 0)

$ xcrun simctl terminate "$UDID_B" com.henning.looseends
(Ausgang 0)

$ LOOSEENDS_SIM_SIGN=1 LOOSEENDS_SIM="iPhone Air" ./scripts/sim.sh launch -LEDebugService "$SERVICE_URL" -LEDebugSession "$SESSION_TOKEN" -onboardingDone YES   (11:43:20Z)
[sim] Simulator bereit (iPhone Air).
com.henning.looseends: 78324
[sim] App gestartet (com.henning.looseends).

$ fx result "$ID_B2"   # alle 2 s, höchstens 60 s, bis: outcome=done
result
outcome=done
taskID=97B40E9F-0EA9-417D-A4F5-19B360906374
(erreicht nach 7 s, 11:43:30Z)
taskID gleich: 97B40E9F-0EA9-417D-A4F5-19B360906374

```
## 5. Store von B, nur lesend

```

$ find "$(xcrun simctl get_app_container <udid B> com.henning.looseends group.com.henning.looseends)" -name LooseEnds.store
/Users/hem/Library/Developer/CoreSimulator/Devices/2E697CBC-91E9-4B18-AC78-7D5DD70F91B4/data/Containers/Shared/AppGroup/B8DC6D4A-6D6A-4D22-933A-93025068822F/Library/Application Support/LooseEnds.store
Treffer: 1 im App-Group-Container
ZID gesucht (hex) = 97B40E9F0EA9417DA4F519B360906374

$ sqlite3 -readonly "$store" "SELECT hex(ZID), ZTITLE, ZCAPTUREDVIARAW, ZSTATUSRAW FROM ZTASKITEM WHERE hex(ZID) = \"$hexid\";"
97B40E9F0EA9417DA4F519B360906374|Aufgabe von B|claude|unprocessed
(Ausgang 0)

$ sqlite3 -readonly "$store" "SELECT hex(t.ZID), t.ZTITLE, t.ZCAPTUREDVIARAW, r.ZFIELDRAW, r.ZAUTHORRAW, r.ZREASON, r.ZOLDVALUE, r.ZNEWVALUE, datetime(r.ZCREATEDAT + 978307200, \"unixepoch\") FROM ZREVISION r JOIN ZTASKITEM t ON t.Z_PK = r.ZTASK WHERE r.ZREASON = \"Claude\" ORDER BY r.ZCREATEDAT;"
97B40E9F0EA9417DA4F519B360906374|Aufgabe von B|claude|dueDate|user|Claude||2026-11-19T23:00:00Z|2026-11-13 11:43:27
(Ausgang 0)

$ sqlite3 -readonly "$store" "SELECT COUNT(*) FROM ZREVISION;"
1
(Ausgang 0)

$ sqlite3 -readonly "$store" "SELECT COUNT(*) FROM ZTASKITEM;"
1
(Ausgang 0)

```

$ LOOSEENDS_SIM="iPhone Air" ./scripts/sim.sh screenshot "$art/b-aufgabe.png" 2>&1 | tail -1
[sim] Screenshot: docs/artifacts/feat-795-s3b2-debug-weg/b-aufgabe.png
(Ausgang 0)
## 6. Aufräumen

```

$ xcrun simctl terminate "$UDID_B" com.henning.looseends
(Ausgang 0)

$ kill -TERM 77169
Dienst-Skript beendet, Ausgang 143

$ test -e "$work_dir" && echo "Temp-Ordner DA" || echo "Temp-Ordner fehlt"
Temp-Ordner fehlt
(Ausgang 0)

$ pgrep -f "$work_dir" || echo "kein Postgres dieses Laufs"
kein Postgres dieses Laufs
(Ausgang 0)

$ lsof -nP -iTCP:"$PORT" -sTCP:LISTEN || echo "Port $PORT frei"
Port 62581 frei
(Ausgang 0)

```
Fristen: A result=0 transcript=0, B result=0 transcript=0, B2 result=0 (0 = erreicht)

## Erster Lauf (gescheitert, Ursache -34018)

08:57–09:03 UTC, ohne Schalter (unsignierter Bau, `CODE_SIGNING_ALLOWED=NO`), ohne `-onboardingDone YES`. Beide Simulatoren
sendeten ihre Abschrift (`send ended: done`, im Dienst `tasks=0`), aber kein Gerät holte einen Auftrag: alle vier Fristen
liefen ab, beide Aufträge blieben `waiting`. Log (`xcrun simctl spawn <udid> log show`), auf A und B gleich:

```
securityd: LooseEnds[38765]/1#-1 LF=0 copy_matching Error Domain=NSOSStatusErrorDomain Code=-34018 "Client has neither application-identifier nor keychain-access-groups entitlements"
LooseEnds: [com.henning.looseends:claude-sync] device id unreadable: DeviceIdentityError
LooseEnds: [com.henning.looseends:claude-sync] pass stopped: deviceIdentity (DeviceUnreadable)
LooseEnds: [com.henning.looseends:claude-sync] pull ended: stopped.deviceIdentity
```

Ursache: der unsignierte Simulatorbau hat keine (simulierten) Berechtigungen, `DeviceIdentity.current()` scheitert am
Schlüsselbund. Zusätzlich zeigte B als frische Installation die Einführung statt der Startseite (`b-fehllauf-onboarding.png`).
Abhilfe: Teil 4 der Spec (`LOOSEENDS_SIM_SIGN=1`, Spike `spike-signatur.md`) und `-onboardingDone YES`.
