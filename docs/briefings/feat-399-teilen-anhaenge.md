---
spec_file: docs/specs/feat-399-schnitt-1-anhang-speichern.md
spec_sha256: d882049700aa3f5af71d00fa067602d5ab08a69d3b57a6756e2b618272b031f0
spec_frozen_sha256: 622086298220b58ddf5a7a7d4478cb4c75c3f6e782bebb60b8d7a71a7d9f9e74
---

# PO-Briefing: feat-399-teilen-anhaenge

- **Spec:** docs/specs/feat-399-schnitt-1-anhang-speichern.md
- **Issue:** #399
- **Erstellt:** 2026-10-17

## Was gebaut wird

Geteilte Fotos und Dateien können später als Anhang an einer neuen Aufgabe landen; dieser Teil legt nur die unsichtbare Grundlage.

## Definition of Done

Alle Prüfungen der Grundregeln und des Speicherns sind grün; sichtbar ist noch nichts, das Ticket bleibt offen.

## Wie geprüft wird

Automatische Tests belegen Titelregel, Größen- und Zehnergrenze und Speichern; sie belegen nicht, dass Teilen aus anderen Apps funktioniert.

## Kritische Anmerkungen

- Nach diesem Schritt ändert sich in der App nichts Sichtbares; Foto-Teilen funktioniert erst nach Schnitt 2 und Gerätetest.
- Kein Test belegt das Zusammenspiel mit der Teilen-Erweiterung; die Tests stellen ihren Ausgangszustand selbst her.
- Mit etwa 245 von 250 Zeilen liegt der Umfang knapp an der Grenze.

## Freigabe-Frage

Soll dieser unsichtbare Grundbau freigegeben werden, obwohl Foto- und Dateiteilen erst mit dem zweiten Schritt nutzbar wird?
