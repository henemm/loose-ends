# AC-8 Hinweise für Apples Prüfer (Review-Detail) je Plattform

Zeit: 2026-11-24T22:10:30+01:00

Quelle: `docs/reference/app-review-notizen.md` (Stand `origin/main`, Text aus S5d-1). Liegt nach AC-7 (22:08 Uhr MEZ).

## lesen vorher

`asc-review-notes aktion=lesen`, https://github.com/henemm/loose-ends/actions/runs/45488204717, 22:09 Uhr MEZ, `success`:
```
version IOS 1.0.2 id=78834df9-0492-4265-b821-95bad8a68060 state=PREPARE_FOR_SUBMISSION
version MAC_OS 1.0.2 id=8eb2d4b5-ddbe-47e9-b0a2-965db40e402c state=PREPARE_FOR_SUBMISSION
IOS notizen gesetzt bytes=2514
IOS anhang name=LooseEnds-1.0.2-Review.mp4 groesse=8216773 assetDeliveryState=COMPLETE
MAC_OS notizen gesetzt bytes=417
MAC_OS anhang name=LooseEnds-1.0.2-Review.mp4 groesse=8216773 assetDeliveryState=COMPLETE
zusammenfassung geschrieben=0
```
Abweichung: beide Versionen tragen noch die von 1.0.1 übernommenen Notizen.

## Schreiben mit Gegenprobe

`asc-review-notes aktion=notizen`, https://github.com/henemm/loose-ends/actions/runs/45488345391, 22:10 Uhr MEZ, `success`:
```
version IOS 1.0.2 id=78834df9-0492-4265-b821-95bad8a68060 state=PREPARE_FOR_SUBMISSION
version MAC_OS 1.0.2 id=8eb2d4b5-ddbe-47e9-b0a2-965db40e402c state=PREPARE_FOR_SUBMISSION
IOS notizen gesetzt bytes=3515
IOS gegenprobe gleich=ja
MAC_OS notizen gesetzt bytes=3515
MAC_OS gegenprobe gleich=ja
zusammenfassung geschrieben=2
```
Je Plattform genau ein Schreibaufruf (`geschrieben=2` für zwei Plattformen), keiner wiederholt.

## Gegenprobe danach

`lesen`, https://github.com/henemm/loose-ends/actions/runs/45488480527, 22:11 Uhr MEZ: beide `notizen gesetzt bytes=3515`,
Anhang je Plattform unverändert `LooseEnds-1.0.2-Review.mp4`, `geschrieben=0`.

`notizen` ein zweites Mal (schreibt nur bei Abweichung), https://github.com/henemm/loose-ends/actions/runs/45488631826,
22:12 Uhr MEZ:
```
IOS notizen unverändert bytes=3515
MAC_OS notizen unverändert bytes=3515
zusammenfassung geschrieben=0
```
Kein Unterschied zwischen Datei und Review-Detail, kein Schreibaufruf.
