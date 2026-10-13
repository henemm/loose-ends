# AC-7 (#377): Ereignismeldung im Simulator — Ergebnis

Datum: 2026-10-13. Simulator: iPhone 17e (iOS 27.0), Debug-Bau der Sitzung `377-impl`, Start im Produktpfad (ohne `--ui-testing`)
per `xcrun simctl launch`, Live-Mitschnitt mit `log stream --info --debug` (Prozess `LooseEnds` und Subsystem `com.henning.looseends`).

## Ergebnis

**Im Simulator nicht beantwortbar.** Der Debug-Bau für den Simulator ist unsigniert und hat keine App-Gruppe. Die App fällt beim
Start in den ersten der zwei stillen Rückfälle der `ModelContainerFactory` und legt einen lokalen Speicher ohne Abgleich an,
bevor ein CloudKit-Container entsteht. Ohne Container gibt es keine Spiegelungsereignisse, die man mitschneiden könnte.

Einzige App-eigene Logzeile beim Start (pid 50508):

```
2026-10-13 12:54:36.055 E  LooseEnds[50508:2e9855] [com.henning.looseends:Persistence] App-group entitlement unavailable, using local store without sync
```

Keine Zeile der Kategorie „Sync“ (auch nicht „Listening for CloudKit mirroring events“): `start()` wird im Rückfallzweig nicht erreicht.

## Was das belegt

- Der Rückfall auf den lokalen Speicher ist im echten Produktpfad auslösbar und wird geloggt (Grundlage für AC-3 im echten Ablauf).
- Ob `NSPersistentCloudKitContainer.eventChangedNotification` für den SwiftData-Container eintrifft, ist im Simulator **nicht
  prüfbar**, nur mit einem signierten Bau mit App-Gruppe und iCloud-Anmeldung (Gerät oder Mac, Nachgelagert G-1).

## Folge

AC-7 kann in der Fassung der Spec („im Simulator belegen“) nicht erfüllt werden. Er gehört zu Nachgelagert G-1 (signierter Bau).
Risiko bleibt: Bleibt die Meldung aus, zeigt die Zeile dauerhaft „Wartet auf iCloud“. Auf dem Mac ist das bei G-1 gesondert zu
prüfen (Zeile „Wartet auf iCloud“ trotz Netz und Anmeldung wäre dann noch kein Beleg für Hypothese 2).

Der Rohmitschnitt (rund 116.000 Zeilen, enthält auch Zeilen fremder Sitzungen) ist nicht abgelegt.
