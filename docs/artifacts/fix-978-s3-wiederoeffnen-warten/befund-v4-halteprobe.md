# #978 S3 v4 – Haltedauer-Probe ausgewertet (2026-11-25)

Lauf: `mac-panel-repeat.yml` **45602877961**, Zweig `fix/978-s3-wiederoeffnen-warten` (f2dbbb4), `iterationen=20`,
`halteprobe=true`, `kontrollarm=false`, Ergebnis success (11:16–11:36 UTC = 12:16–12:36 Uhr MEZ). 20 Iterationen
`testHoldDurationProbe` bestanden, je Iteration ein Klick je Arm → 40 Klick-Anhänge.
Artefakte: `probe-45602877961/` (Log, xcresult, Summary aus der CI).

## Auswertungsfehler im CI-Summary und Korrektur

Die CI-Zusammenfassung (`probe-45602877961/MacPanelRepeatSummary/mac-panel-repeat-summary.md`) zählte **0 Klicks**:
`xcresulttool export attachments` trennt den Anhangsnamen am Punkt in `1.0`/`0.1` wie eine Dateiendung
(`mac-gallery-hold-1_0_<UUID>.0-0-click`). `arm_of` erkennt seither auch diese Form (Skripttest
`test_arm_of_hold_names_split_by_xcresulttool`). Dieselben Rohdaten neu ausgewertet, mit denselben Argumenten wie der
Workflow: `probe-45602877961/summary-lokal.md`. Kein neuer Lauf nötig: die Messdaten waren vollständig.

## Ergebnis je Arm

| Arm | Nenner | zu | offen | Rate zu |
|---|---|---|---|---|
| hold-1.0 | 20 | 20 | 0 | 100,0 % |
| hold-0.1 | 20 | 0 | 20 | 0,0 % |

**Entscheidung nach der vorab festgelegten Regel (Spec Punkt 6): bestanden** (≥ 20 Klicks je Arm, 1,0 s zu ≥ 95 %,
0,1 s zu 0 %). Die Hypothese „langes Halten zwischen Maus-runter und Maus-hoch schließt das Panel“ ist belegt →
Folgeschnitt **v5** (Testumbau: Klickweg zurück auf `statusItem.click()`, Haltedauer messen, über der Schwelle genau
eine Wiederholung mit Anhang, darunter hart rot).

## Haltedauer laut Panel-Protokoll (key → Maus hoch)

- hold-1.0: 0,89 bis 1,44 s, alle 20 zu.
- hold-0.1: 17 Klicks 0,036 bis 0,137 s, alle offen. Drei Klicks zeigen 11,6 / 11,7 / 13,0 s: Zu diesen Klicks steht kein
  Maus-hoch im Protokoll (beim kurzen Klick bleibt das Ereignis beim Statusobjekt), die Auswertung paart deshalb mit
  einem späteren Maus-hoch im 15-s-Fenster. Fehlpaarung, keine echte Haltedauer; alle drei blieben offen, die
  Entscheidung hängt nicht daran.
- Die eingestellte Haltedauer kam also tatsächlich so an: die beiden Arme trennen sich sauber.

## Monitor im Testläufer (AC-8)

**Monitor sah Ereignisse: 0 von 40** (`monitor saw nothing`: 40). Der globale `NSEvent`-Monitor im Testläufer sieht die
von XCTest synthetisierten Klicks nicht; ein Abgleich Monitor gegen Log ist deshalb nicht möglich (Übereinstimmung 0,
Abweichung 0). Für v5 heißt das: die Haltedauer nicht im Testläufer messen, sondern aus dem Panel-Protokoll der App
(oder aus der Klickdauer im Aktivitätsprotokoll) lesen.

## Geöffnete Anhänge (AC-4)

- hold-0.1, Klick `1795605665.415`: `d: 0.1`, `result: open`, `monitor saw nothing`.
- hold-1.0, Klick `1795605637.384` (`mac-gallery-hold-1_0_CE05AC11-….0-0-click`): `d: 1.0`, `result: closed`,
  `monitor saw nothing`.
