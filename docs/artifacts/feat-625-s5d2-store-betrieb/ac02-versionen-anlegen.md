# AC-2 Versionen 1.0.2 anlegen (iOS, dann Mac)

Zeit: 2026-11-24T18:48:40+01:00

## lesen vorher

https://github.com/henemm/loose-ends/actions/runs/45452076336 (nur GET), 18:45 Uhr MEZ: je Plattform nur 1.0 und 1.0.1
`READY_FOR_SALE`, keine Version 1.0.2, keine bearbeitbare Version (Ausgabe in `ac01-testflight-bau.md`).

## anlegen mit Gegenprobe im selben Lauf

https://github.com/henemm/loose-ends/actions/runs/45452418663, 18:47–18:48 Uhr MEZ, Ergebnis `success`:
```
keine bearbeitbare Version IOS (Zustände READY_FOR_SALE, READY_FOR_SALE), nichts geschrieben
keine bearbeitbare Version MAC_OS (Zustände READY_FOR_SALE, READY_FOR_SALE), nichts geschrieben
bau IOS gewählt: 142 von 6 gültigen
bau MAC_OS gewählt: 142 von 6 gültigen
version IOS 1.0.2 angelegt
version MAC_OS 1.0.2 angelegt
bau IOS zugeordnet: 142
bau MAC_OS zugeordnet: 142
gegenprobe gleich=ja
version MAC_OS 1.0.2 state=PREPARE_FOR_SUBMISSION
version IOS 1.0.2 state=PREPARE_FOR_SUBMISSION
version MAC_OS 1.0.1 state=READY_FOR_SALE
version MAC_OS 1.0 state=READY_FOR_SALE
version IOS 1.0.1 state=READY_FOR_SALE
version IOS 1.0 state=READY_FOR_SALE
version IOS 1.0.2 id=78834df9-0492-4265-b821-95bad8a68060 state=PREPARE_FOR_SUBMISSION
bau IOS 1.0.2 (142) processingState=VALID
review-detail vorhanden
version MAC_OS 1.0.2 id=8eb2d4b5-ddbe-47e9-b0a2-965db40e402c state=PREPARE_FOR_SUBMISSION
bau MAC_OS 1.0.2 (142) processingState=VALID
review-detail vorhanden
zusammenfassung geschrieben=4
```

## lesen nachher

https://github.com/henemm/loose-ends/actions/runs/45452702735 (nur GET), 18:49 Uhr MEZ:
```
version MAC_OS 1.0.2 state=PREPARE_FOR_SUBMISSION
version IOS 1.0.2 state=PREPARE_FOR_SUBMISSION
version MAC_OS 1.0.1 state=READY_FOR_SALE
version MAC_OS 1.0 state=READY_FOR_SALE
version IOS 1.0.1 state=READY_FOR_SALE
version IOS 1.0 state=READY_FOR_SALE
version IOS 1.0.2 id=78834df9-0492-4265-b821-95bad8a68060 state=PREPARE_FOR_SUBMISSION
bau IOS 1.0.2 (142) processingState=VALID
review-detail vorhanden
version MAC_OS 1.0.2 id=8eb2d4b5-ddbe-47e9-b0a2-965db40e402c state=PREPARE_FOR_SUBMISSION
bau MAC_OS 1.0.2 (142) processingState=VALID
review-detail vorhanden
zusammenfassung geschrieben=0
```

Ergebnis: je Plattform genau eine bearbeitbare Version 1.0.2 (`PREPARE_FOR_SUBMISSION`), Bau 142 (`VALID`) zugeordnet,
`gegenprobe gleich=ja`, jeder Schreibaufruf einmal, kein DELETE; der Nachlauf schreibt nichts (`geschrieben=0`).
Apple hat das Review-Detail beider Versionen beim Anlegen angelegt (Risiko „Review-Detail fehlt“ der Spec tritt nicht ein).
