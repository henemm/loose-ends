# Mini-Spec: #742 Schnitt 2 — Beispielaufgaben auf der Uhr für die Store-Bilder

## Was ändert sich
- `LooseEndsWatch/LooseEndsWatchApp.swift`: Nur wenn die Uhr-App mit `--ui-testing` **und** `--ui-testing-store-sample` gestartet wird, legt sie drei Beispielaufgaben für heute an („Steuerbescheid prüfen“, „Anna wegen Sonntag anrufen“, „Blumen gießen“). Dann zeigt „Jetzt“ eine gefüllte Liste.
- `LooseEndsUITests/Watch/WatchCaptureUITests.swift`: Foto-Test `testPhotographStoreScreens` für die Uhr (416×496), Namen `store-<nn>-<name>`.
- `scripts/sim.sh`: Befehl `watch-test` (UI-Test im Watch-Simulator ohne Beleg).

## Was darf sich nicht ändern
- Im normalen Betrieb und in allen bestehenden Tests ändert sich nichts: ohne beide Startargumente läuft der neue Code nie.
- Keine Berechtigung, kein Schema, keine Info.plist.

## Manuelle Test-Schritte
Keine. Der Foto-Test beweist es: „Jetzt“ zeigt die Beispielaufgaben, die Bilder werden angesehen.

## Inline-Test (wird während Implementierung geschrieben)
- [ ] `testPhotographStoreScreens`: „Jetzt“ hat mindestens zwei Zeilen (`watch.now.row`).

Gerätepfad: `LooseEndsWatch/` steht auf der Geräteliste, der Code läuft aber nur unter `--ui-testing`. Ein Gerätelauf zeigt dazu nichts; die Abnahme endet im Simulator.
