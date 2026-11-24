---
spec_file: docs/specs/fix-978-s3-wiederoeffnen-warten.md
spec_sha256: fe8484a95b3c61fc4949fe183f2bc5ebb67d90212619b70c819f61855b15ba82
spec_frozen_sha256: 1759122b7f8c0630566eb69c4bf2e51b5217f586ae9032841d82fb29db0a4582
---

# PO-Briefing: fix-978-s3-wiederoeffnen-warten

- **Spec:** docs/specs/fix-978-s3-wiederoeffnen-warten.md
- **Issue:** #978
- **Erstellt:** 2026-11-24

## Was gebaut wird

Der automatische Test des Mac-Menüleisten-Fensters wartet den App-Wechsel ab und schlägt bei Fehlern wieder hart an.

## Definition of Done

Drei Pflichtläufe sind grün, und ein Wiederholungslauf mit mindestens 40 Öffnungen je Weg endet ohne einen einzigen Fehlschlag.

## Wie geprüft wird

Wiederholte Läufe in der Testumgebung belegen Öffnen und Offenbleiben; ob echte Nutzer das Zuklappen erleben, belegen sie nicht.

## Kritische Anmerkungen

- Das Issue selbst war nicht lesbar; geprüft wurde nur gegen das Kontext-Dokument.
- Der Test umgeht den Fehlerfall nur; ein Nutzerklick genau im Fensterwechsel könnte weiter zuklappen, App bleibt unverändert.
- 40 fehlerfreie Wiederholungen sind eine Stichprobe; früher trat der Fehler nur 1 von 420 Mal auf.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
