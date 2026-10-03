---
spec_file: docs/specs/tooling/fix-191-testflight-zertifikat.md
spec_sha256: 7aa6fdbd5ced67ef4dac01378841d4bf0bcfbc2b713837751ee1187c7f86869a
---

# PO-Briefing: fix-191-testflight-zertifikat

- **Spec:** docs/specs/tooling/fix-191-testflight-zertifikat.md
- **Issue:** #191
- **Erstellt:** 2026-10-03

## Was gebaut wird

Der TestFlight-Lauf widerruft seine eigenen Signier-Zertifikate selbst und scheitert nicht mehr am Konto-Limit.

## Definition of Done

Zwei scharfe TestFlight-Läufe hintereinander laufen grün, die Zertifikatszahl im Konto wächst nicht.

## Wie geprüft wird

Skripttests prüfen die Auswahl gegen einen Fake-Server; der Probelauf bestätigte sie am echten Konto, die zwei scharfen Läufe stehen aus.

## Kritische Anmerkungen

- Probelauf: Hennings eigene Zertifikate bleiben verschont; Spec auf vollen Namen „Apple Development: Created via API“ korrigiert.
- Widerruf ist unumkehrbar; ob das Archiv danach ohne Profilfehler läuft, zeigt erst der erste scharfe Lauf.
- Export verbraucht laut Probelauf kein Zertifikat; „Zahl bleibt gleich“ ist erst nach beiden scharfen Läufen bewiesen.

## Freigabe-Frage

Dürfen zwei scharfe Läufe die vier Zertifikate „Apple Development: Created via API“ widerrufen, Hennings eigene bleiben unberührt?
