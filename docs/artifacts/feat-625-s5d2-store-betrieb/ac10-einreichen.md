# AC-10 Einreichen 1.0.2 (iOS und Mac) nach Hennings Wort

Zeit: 2026-11-24T22:28:53+01:00

Zustand: a

Wort: „einreichen“ (von Henning getippt, 2026-11-24, kurz vor 22:28:48 Uhr MEZ, als Antwort auf die Frage nach dem
Einreichen in dieser Sitzung). Liegt nach AC-9 (`pruefen` 22:14 Uhr MEZ, beide `bereit`).

## Lauf (genau einmal)

`gh workflow run asc-store-submit.yml -f aktion=einreichen -f bestaetigung=1.0.2`,
https://github.com/henemm/loose-ends/actions/runs/45491513174, gestartet 22:28:53 Uhr MEZ, Ende 22:31:08 Uhr MEZ,
Ergebnis `success`. Nicht wiederholt.

Plan (nur GET) wie in AC-9: beide Plattformen bereit, Freigabeart `AFTER_APPROVAL`. Ausgabe ab der Einreichung:
```
IOS bereit
IOS freigabeart AFTER_APPROVAL
MAC_OS bereit
MAC_OS freigabeart AFTER_APPROVAL
IOS schritt einreichung angelegt
IOS schritt item hinzugefügt
IOS schritt abgeschickt
IOS gegenprobe einreichung=WAITING_FOR_REVIEW version=WAITING_FOR_REVIEW
MAC_OS schritt einreichung angelegt
MAC_OS schritt item hinzugefügt
MAC_OS schritt abgeschickt
MAC_OS gegenprobe einreichung=WAITING_FOR_REVIEW version=WAITING_FOR_REVIEW
zusammenfassung eingereicht=ios,mac
```

Je Plattform genau eine Einreichung angelegt, ein Item, ein Abschicken; nichts gelöscht oder storniert. Gegenprobe im
selben Lauf: iOS und Mac `WAITING_FOR_REVIEW`. Freigabe nach Apples Prüfung automatisch (`AFTER_APPROVAL`).
