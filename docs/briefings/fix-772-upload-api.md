---
spec_file: docs/specs/fix-772-upload-api.md
spec_sha256: d64b520e354b5a4819a4f6ac6d777a4b07614a5c6dea53c3fe15c153a9f278e8
spec_frozen_sha256: 94319884e089d999a316decb676f3f45ce670c0789251f557985c96405357ce4
---

# PO-Briefing: fix-772-upload-api

- **Spec:** docs/specs/fix-772-upload-api.md
- **Issue:** #772
- **Erstellt:** 2026-11-02

## Was gebaut wird

Das Hochladen der vier App-Store-Kopfbilder in Apples Bibliothek folgt künftig Apples echter Schnittstelle, ohne zu platzieren oder einzureichen.

## Definition of Done

Ein echter Lauf zeigt Apples Bildvorgaben, ein zweiter legt alle zulässigen Bilder an und meldet nicht passende ausdrücklich; nichts wird platziert.

## Wie geprüft wird

Tests gegen eine Attrappe in Apples dokumentierter Form belegen jede Anforderung; ob Apples echte Antwort so aussieht, zeigt erst der Lauf.

## Kritische Anmerkungen

- Neu gegenüber dem ersten Schnitt: Passen nur einige Bildmaße, wird teilweise hochgeladen statt abgebrochen; der Rest wird nur gemeldet.
- Ob 5244×2950 für das Kopfbild zulässig ist, ist ungeklärt; sonst fehlen Bilder, Maßänderung wäre eigene Entscheidung.

## Freigabe-Frage

Soll bei nur teilweise passenden Bildern trotzdem hochgeladen werden, statt komplett abzubrechen?

## Ampel

Ampel: rot
