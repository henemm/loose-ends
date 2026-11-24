# AC-4 Englische Store-Bilder an 1.0.2 (iOS und Mac)

Zeit: 2026-11-24T18:53:32+01:00

## lesen vorher

iOS: https://github.com/henemm/loose-ends/actions/runs/45452717347 (nur GET), 18:49 Uhr MEZ.
Mac: https://github.com/henemm/loose-ends/actions/runs/45453198959 (nur GET), 18:52 Uhr MEZ.

Apple hat beim Anlegen von 1.0.2 die Bilder von 1.0.1 übernommen. Schon vor jedem Schreiblauf sind alle Bilder des
Manifests an der bearbeitbaren Version (en-US) in Manifest-Reihenfolge platziert, jedes Bild im Katalog `APPROVED`:
```
platzierung IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE 1 en-iphone-01-start zustand=ACTIVE
platzierung IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE 2 en-iphone-02-erfassen zustand=ACTIVE
platzierung IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE 3 en-iphone-03-neu zustand=ACTIVE
platzierung IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE 4 en-iphone-04-detail zustand=ACTIVE
platzierung IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE 5 en-iphone-05-erledigt zustand=ACTIVE
platzierung IPAD_13_PROFILE 1 en-ipad-01-start zustand=ACTIVE
platzierung IPAD_13_PROFILE 2 en-ipad-02-erfassen zustand=ACTIVE
platzierung IPAD_13_PROFILE 3 en-ipad-03-neu zustand=ACTIVE
platzierung IPAD_13_PROFILE 4 en-ipad-04-detail zustand=ACTIVE
platzierung IPAD_13_PROFILE 5 en-ipad-05-erledigt zustand=ACTIVE
platzierung WATCH_SERIES_10_PROFILE 1 en-watch-01-jetzt zustand=ACTIVE
platzierung WATCH_SERIES_10_PROFILE 2 en-watch-02-gespeichert zustand=ACTIVE
platzierung MAC_PROFILE 1 en-mac-01-start zustand=ACTIVE
platzierung MAC_PROFILE 2 en-mac-03-neu zustand=ACTIVE
platzierung MAC_PROFILE 3 en-mac-04-detail zustand=ACTIVE
platzierung MAC_PROFILE 4 en-mac-05-erledigt zustand=ACTIVE
```
Das ist genau die Reihenfolge der `plan`-Zeilen desselben Laufs (Manifest).

## hochladen (Abweichung: Abbruch ohne Schreibaufruf)

iOS https://github.com/henemm/loose-ends/actions/runs/45453417607 und Mac
https://github.com/henemm/loose-ends/actions/runs/45453422934, 18:53 Uhr MEZ, Ergebnis `failure`:
```
bild en-iphone-01-start schon vorhanden, übersprungen
… (alle 12 iOS- bzw. 4 Mac-Bilder „schon vorhanden, übersprungen“)
##[error]Bild en-iphone-01-start ist APPROVED, nicht PREPARE_FOR_SUBMISSION
##[error]Bild en-mac-01-start ist APPROVED, nicht PREPARE_FOR_SUBMISSION
```
Jedes Bild wurde übersprungen, kein POST, kein Upload. Die Schlussprüfung des Werkzeugs (`ready_images`) kennt nur
frisch hochgeladene Bilder (`PREPARE_FOR_SUBMISSION`) und hält freigegebene für nicht bereit. `platzieren` ruft dieselbe
Prüfung vor jedem Schreibaufruf auf und hätte genauso ohne Schreiben abgebrochen; es lief deshalb nicht. Werkzeug-Folgearbeit:
#996 (nicht Teil dieses Schnitts, AC-13 verbietet Änderungen unter `scripts/`).

## Gegenprobe

Der Zielzustand von AC-4 ist erfüllt, ohne dass ein Schreibaufruf nötig war: `lesen` belegt für en-US je Plattform alle
Bilder des Manifests in Manifest-Reihenfolge an der bearbeitbaren Version 1.0.2 (oben). Nichts Fremdes wurde
überschrieben, kein Schreibaufruf auf de-DE oder en-US, kein DELETE. de-DE wurde nur gelesen (die Läufe schreiben nur
en-US; `hochladen` endete vor jedem Schreiben).
