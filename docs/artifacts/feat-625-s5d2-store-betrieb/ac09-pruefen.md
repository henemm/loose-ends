# AC-9 Vorprüfung vor dem Einreichen (nur GET)

Zeit: 2026-11-24T22:14:41+01:00

`gh workflow run asc-store-submit.yml -f aktion=pruefen`, https://github.com/henemm/loose-ends/actions/runs/45488786947,
22:13–22:14 Uhr MEZ, Ergebnis `success` (Ausgang 0). Vorher (RED, `red-store-submit-pruefen.txt`): `nicht bereit: ios,mac`,
Ausgang 1.

Vollständige Ausgabe des Skripts:
```
version IOS 1.0.2 state=PREPARE_FOR_SUBMISSION
bau IOS 1.0.2 (142) processingState=VALID
  IOS de-DE description zeichen=2751 keywords zeichen=100 supportUrl zeichen=50 whatsNew zeichen=501 promotionalText zeichen=145
  IOS en-US description zeichen=2469 keywords zeichen=94 supportUrl zeichen=50 whatsNew zeichen=443 promotionalText zeichen=148
  IOS de-DE bilder=12 platzierungen=14
  IOS en-US bilder=12 platzierungen=12
review-detail IOS vorhanden
einreichungen IOS COMPLETE, COMPLETE
version MAC_OS 1.0.2 state=PREPARE_FOR_SUBMISSION
bau MAC_OS 1.0.2 (142) processingState=VALID
  MAC_OS de-DE description zeichen=2751 keywords zeichen=100 supportUrl zeichen=50 whatsNew zeichen=501 promotionalText zeichen=145
  MAC_OS en-US description zeichen=2469 keywords zeichen=94 supportUrl zeichen=50 whatsNew zeichen=443 promotionalText zeichen=148
  MAC_OS de-DE bilder=4 platzierungen=4
  MAC_OS en-US bilder=4 platzierungen=4
review-detail MAC_OS vorhanden
einreichungen MAC_OS COMPLETE, COMPLETE
IOS bereit
MAC_OS bereit
zusammenfassung bereit=ios,mac nicht-bereit=keine
```

Beide Plattformen `bereit`. Die zwei Einreichungen je Plattform sind `COMPLETE` (1.0 und 1.0.1, abgeschlossen); keine
belegende Einreichung (`READY_FOR_REVIEW`, `WAITING_FOR_REVIEW`, `IN_REVIEW`) existiert.
