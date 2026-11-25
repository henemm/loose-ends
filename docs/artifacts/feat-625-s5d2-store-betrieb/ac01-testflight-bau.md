# AC-1 TestFlight-Bau 1.0.2 (iOS und Mac)

Zeit: 2026-11-24T18:44:28+01:00

Lauf: https://github.com/henemm/loose-ends/actions/runs/45447956574 (manueller Lauf auf `main`, Commit c885f7a,
`MARKETING_VERSION: "1.0.2"`), gestartet 18:23 Uhr MEZ, Ende 18:44 Uhr MEZ, Ergebnis `success`.

## Zustand vorher

Letzter TestFlight-Lauf 2026-11-19 (Commit 820199a); bei Apple keine Vorabversion 1.0.2 (`red-store-version-lesen.txt`).

## „Was testen“ (Eingabe `what_to_test`, de und en)

```
de:
Version 1.0.2 mit der Verbindung zu Claude, die Fassung für den App Store.
Bitte nimm mit der Bildschirmaufnahme deines iPhones einen Durchgang auf: eine Aufgabe sprechen oder tippen, die Aufgabe öffnen, dann Einstellungen › Claude, „Mit Apple anmelden“, in claude.ai den Connector Loose Ends benutzen (etwa „Was steht jetzt an?“), zurück in der App unter Einstellungen › Claude das Konto löschen.
Du siehst: die Aufgabe steht in der Liste, die Anmeldung gelingt, Claude nennt deine Aufgaben, nach dem Löschen ist die Gruppe Claude wieder abgemeldet.
en:
Version 1.0.2 with the connection to Claude, the App Store build.
(englische Fassung desselben Ablaufs)
```

## Jobs

- Production knows the CloudKit schema: success
- Archive and upload (iOS): success
- Archive and upload (macOS): success
- Confirm Apple processed the build: success
- Confirm Apple processed the macOS build: success

## Archivprüfungen (Auszug aus dem Log)

iOS:
```
| com.henning.looseends | LooseEnds.app | iphoneos27.0 | 27.0 | 1.0.2 (142) | da | OK |
| LEAccountEnabled | bool true | OK |
| LEApsEnvironment | string production | OK |
```
macOS:
```
| LEAccountEnabled | bool true | OK |
| LEApsEnvironment | string production | OK |
```

## Zustand nachher (Apple)

iOS:
```
build=142 processingState=VALID uploadedDate=2026-11-24T09:34:53-08:00 treffer=1
build=142 whatToTest gesetzt für de-DE, en-US
```
macOS:
```
build=142 processingState=VALID uploadedDate=2026-11-24T09:43:42-08:00 treffer=1
build=142 whatToTest gesetzt für de-DE, en-US
```

`asc-store-version aktion=lesen` danach (https://github.com/henemm/loose-ends/actions/runs/45452076336, nur GET): noch keine
Version 1.0.2, daher kein Bau zugeordnet; die Zuordnung der beiden Bauten 142 belegt AC-2.
```
version MAC_OS 1.0.1 state=READY_FOR_SALE
version MAC_OS 1.0 state=READY_FOR_SALE
version IOS 1.0.1 state=READY_FOR_SALE
version IOS 1.0 state=READY_FOR_SALE
zusammenfassung geschrieben=0
```
