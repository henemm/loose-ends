---
spec_file: docs/specs/feat-842-schnitt-5b-mac-bilder.md
spec_sha256: dd8c70988de014a82e51d0963e277fce0994956914b49339cf733ce26f94e95b
spec_frozen_sha256: 5939eb341ed8347b0409b0ea4c74083a2c7c78c1e5af6f09ed30f5fc2e2515ba
---

# PO-Briefing: feat-842-s5b-mac-bilder

- **Spec:** docs/specs/feat-842-schnitt-5b-mac-bilder.md
- **Issue:** #842
- **Erstellt:** 2026-11-09

## Was gebaut wird

Die vier englischen Mac-Bilder erscheinen im App Store auf der englischen Seite der Mac-Version 1.0.1, in der freigegebenen Reihenfolge.

## Definition of Done

Der Store-Lesebericht zeigt für Mac Englisch vier Bilder in der richtigen Reihenfolge, Mac Deutsch bleibt unverändert, und nichts ist eingereicht.

## Wie geprüft wird

Automatische Tests ohne Apple-Verbindung sowie echte Läufe gegen Apple; nicht geprüft wird die Optik der Bilder im Store, die du bereits freigegeben hast.

## Kritische Anmerkungen

- Platzierte Bilder lassen sich bei Apple nicht mehr ändern; eine Korrektur wäre nur durch Löschen möglich, das dieser Schnitt nie tut.
- Ob Apple für den Mac die erwarteten Bildgruppen kennt, zeigt erst der erste echte Lauf; sonst Abbruch ohne Schreiben.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
