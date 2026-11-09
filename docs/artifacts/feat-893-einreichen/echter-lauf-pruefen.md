# #893 Schnitt A — echter Lauf `pruefen` gegen App Store Connect

- Run: 42717307403 (`asc-store-submit.yml`, `workflow_dispatch`, `aktion=pruefen`, `main` nach PR #894), 2026-11-09T23:03:52Z, Ergebnis success (Ausgang 0)
- Nur GET; nichts angelegt, geändert oder eingereicht.

## Protokoll (Schritt „Store submit“, wörtlich)

```
version IOS 1.0.1 state=PREPARE_FOR_SUBMISSION
bau IOS 1.0.1 (133) processingState=VALID
  IOS de-DE description zeichen=1638 keywords zeichen=100 supportUrl zeichen=50 whatsNew zeichen=116 promotionalText zeichen=139
  IOS en-US description zeichen=1493 keywords zeichen=94 supportUrl zeichen=50 whatsNew zeichen=99 promotionalText zeichen=125
  IOS de-DE bilder=12 platzierungen=14
  IOS en-US bilder=12 platzierungen=12
review-detail IOS vorhanden
einreichungen IOS COMPLETE
version MAC_OS 1.0.1 state=PREPARE_FOR_SUBMISSION
bau MAC_OS 1.0.1 (133) processingState=VALID
  MAC_OS de-DE description zeichen=1638 keywords zeichen=100 supportUrl zeichen=50 whatsNew zeichen=116 promotionalText zeichen=139
  MAC_OS en-US description zeichen=1493 keywords zeichen=94 supportUrl zeichen=50 whatsNew zeichen=99 promotionalText zeichen=125
  MAC_OS de-DE bilder=4 platzierungen=4
  MAC_OS en-US bilder=4 platzierungen=4
review-detail MAC_OS vorhanden
einreichungen MAC_OS COMPLETE
IOS bereit
MAC_OS bereit
zusammenfassung bereit=ios,mac nicht-bereit=keine
```

## Befund zu Apples Listenform der `reviewSubmissions`

- `GET /v1/reviewSubmissions?filter[app]=…&filter[platform]=…&limit=50` wird angenommen (kein Lesefehler auf beiden Plattformen).
- Zustandswort im Feld `state` belegt: `COMPLETE` (je Plattform die abgeschlossene Einreichung von 1.0). Plattformfeld je Zeile passte zur gefilterten Plattform (keine Zeile ignoriert, sonst wäre keine Zustandszeile erschienen).
- Nicht belegt (keine Zeile in diesem Zustand vorhanden): `READY_FOR_REVIEW`, `WAITING_FOR_REVIEW` u. a.; das Skript wertet sie nach Apples Doku, unbekannte Zustände gelten als belegt.
- Ist-Stand: iOS und Mac 1.0.1 einreichbar nach allen per API lesbaren Voraussetzungen. Schnitt B (`einreichen`) kann beginnen.
