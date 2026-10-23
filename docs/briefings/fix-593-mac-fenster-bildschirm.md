---
spec_file: docs/specs/fix-593-mac-fenster-bildschirm.md
spec_sha256: 92b013ee2c944c9fc741c0fdaa2771497a7722cb036e70bf6c6e1b4ddc711680
spec_frozen_sha256: 8fea2138430166dc43221a6c11884bb873c7e934468ce39d05b8aa9bec31a19c
---

# PO-Briefing: fix-593-mac-fenster-bildschirm

- **Spec:** docs/specs/fix-593-mac-fenster-bildschirm.md
- **Issue:** #593
- **Erstellt:** 2026-10-23

## Was gebaut wird

Das Mac-Fenster öffnet nie breiter als der sichtbare Bildschirm, und die Mac-Tests melden es, falls doch.

## Definition of Done

Im grünen Mac-CI-Lauf nennt die Galerie-Notiz Fenster- und Bildschirmgröße, das Fenster ist nie breiter, und die Bilder sind vollständig.

## Wie geprüft wird

Rechentests belegen die Größenregel; ob das echte Fenster passt, zeigt nur der CI-Lauf, nicht lokal und nicht gezielt erzwingbar.

## Kritische Anmerkungen

- Abweichung: Statt nur Tests ändert die Spec die App selbst; auf Hennings Mac bleibt alles unverändert.
- Die Meldung bei zu breitem Fenster hat keinen eigenen Test; ihre Wirkung wird nur per Codeansicht belegt.
- Der Fehler trat seit neun Läufen nicht auf; die Behebung ist daher kaum beweisbar.

## Freigabe-Frage

Soll die Fenstergröße der App zusätzlich zur Testprüfung geändert werden, obwohl das Ticket nur Test-Anpassungen nannte?
