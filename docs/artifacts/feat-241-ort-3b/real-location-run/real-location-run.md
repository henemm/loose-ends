# Standortlauf #241 Schnitt 3b (AC-8), 2026-10-23

Echter Weg im iOS-Simulator (iPhone 17, iOS 27, Systemsprache Deutsch), App **ohne `--ui-testing`**: `CurrentLocation.current`
ist damit `SystemCurrentLocation` (Core Location, `requestWhenInUseAuthorization`, `requestLocation`, Rückwärtssuche über
`MKReverseGeocodingRequest`), echter Datenspeicher, echte Systemfrage. Bedient hat ein Wegwerf-XCUITest
(`ZZRealLocationRunTests`, nur für den Lauf in `LooseEndsUITests/` kopiert, danach gelöscht und `generate` neu, nicht im Repo).
Startargumente nur `-AppleLanguages (de) -AppleLocale de_DE`. Berechtigung vor Lauf 1 und 3 per
`XCUIApplication().resetAuthorizationStatus(for: .location)` auf „unentschieden“ zurückgesetzt.

Koordinaten: Altona = `FixedCurrentLocation.altona` 53.5561, 9.9285; fern = `FixedCurrentLocation.elsewhere` 53.6304, 9.9882 (ca. 9 km).

## Lauf 1, Zusage am Ort (AC-1, AC-2 Zusage, AC-6)

```
./scripts/sim.sh location 53.5561 9.9285
./scripts/sim.sh test ZZRealLocationRunTests/test1GrantedAtThePlace   # ✔ 65 s
```

- `00-einstellungen-felder-ort-an.png`: Einstellungen > Felder, Schalter „Ort“ an (Standard hat Ort aus, #538; ohne das bietet das Detail „+ Ort“ nicht an).
- `01-blatt-aktueller-ort.png`: Blatt „Ort“ mit „Aktueller Ort“, „Zuhause“/„Arbeit“ je „Noch nicht festgelegt“, Suchfeld.
- `02-systemfrage-standort.png`: Systemfrage „Darf „Loose Ends“ deinen Standort verwenden?“ mit dem Zwecktext der App, Knöpfe „Einmal erlauben“, „Beim Verwenden der App erlauben“, „Nicht erlauben“. Getippt: „Beim Verwenden der App erlauben“.
- `03-detail-ort-und-schon-hier.png`: Blatt geschlossen, Detail: Ortszeile „Bahrenfelder Straße 234A, Hamburg“ (Name aus der Rückwärtssuche der Altona-Koordinate), Ankommen gewählt, darunter grau „Erinnert, wenn du ankommst.“ und „Du bist schon hier. Erinnert beim nächsten Ankommen.“

## Lauf 2, fern (AC-6 Gegenprobe)

```
./scripts/sim.sh location 53.6304 9.9882
./scripts/sim.sh test ZZRealLocationRunTests/test2FarAway   # ✔ 32 s
```

- `04-detail-fern-ohne-hinweis.png`: dieselbe Aufgabe neu geöffnet (App neu gestartet), Ortszeile unverändert, nur „Erinnert, wenn du ankommst.“; der Satz „Du bist schon hier …“ fehlt (8 s gewartet, damit der eine Standortabruf beim Öffnen zurück ist).

## Lauf 3, Ablehnung (AC-2 Ablehnung)

```
./scripts/sim.sh location 53.5561 9.9285
./scripts/sim.sh test ZZRealLocationRunTests/test3Refused   # ✔ 48 s
```

- `05-systemfrage-vor-ablehnung.png`: dieselbe Systemfrage nach dem Zurücksetzen. Getippt: „Nicht erlauben“.
- `06-blatt-offen-standort-aus.png`: Blatt bleibt offen, unter „Aktueller Ort“ grau „Standort ist in den Einstellungen aus“. Zweiter Tipp auf „Aktueller Ort“: keine zweite Systemfrage binnen 4 s (Assertion, kein Bild).
- `07-detail-ohne-ort.png`: nach „Abbrechen“ Detail ohne Ortszeile, „+ Ort“ weiter angeboten: kein Ort gesetzt.

Hinweis: Lauf 3 hat eine Aufgabe ohne Ort geöffnet, die aus einem früheren, abgebrochenen Versuch stammt (Gesagt „Standortlauf erlaubt 241“); für die Ablehnung zählt nur, dass sie keinen Ort trägt.

## Befund `requestLocation` unter iOS 27 (Offener Punkt der Spec)

`requestLocation` liefert im iOS-27-Simulator nach der Zusage einen Standort, ohne `CLServiceSession`: die Ortszeile steht
binnen der 20-s-Frist des Tests. Die Rückwärtssuche benennt den Ort mit der Adresse, nicht mit „Aktueller Ort“.

## Nebenbefunde (kein Teil von AC-8)

- Die doppelte Beschriftung „Ort“ (graue Zeile) und „ORT“ (Kopf) im Detail ist sichtbar (Bild 03, 04) — Offener Punkt der Spec.
- Ohne `--ui-testing` lief das Modell im Simulator: Titel zu „Standortlauf“ gekürzt, Dauer 5 Min. gesetzt.
