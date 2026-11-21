---
spec_file: docs/specs/fix-862-menubar-panel.md
spec_sha256: 4219c5d0a974dd79af05e0e196e613edbc5bd6fba8e7a87a365726c6fe053c38
spec_frozen_sha256: 3f1fdb1a8bd9170cf94bc5ea1e64db68119983c725227781ea41fcb44b8f5d8f
---

# PO-Briefing: fix-862-menubar-panel

- **Spec:** docs/specs/fix-862-menubar-panel.md
- **Issue:** #862
- **Erstellt:** 2026-11-20

## Was gebaut wird

Das Mac-Menüleisten-Fenster öffnet nach dem Speichern einer Aufgabe wieder mit einem einzigen Klick statt zwei.

## Definition of Done

Der Mac-Test-Lauf in der CI ist in drei aufeinanderfolgenden Läufen beim ersten Versuch grün, ohne Wiederholung und ohne zweiten Klick im Test.

## Wie geprüft wird

Zwei neue Mac-Tests stellen den Fehler nach und müssen erst rot, dann grün sein; sie laufen nur in der CI, nie auf deinem Mac.

## Kritische Anmerkungen

- Die Ursache ist nur eine Annahme; erklärt nicht alles, Tests entscheiden. Bleibt es rot, kommt eine Rückfrage zu Alternativen.
- Der Fehler ist vermutlich echt: Nutzer brauchen nach Return zwei Klicks; das Ticket sprach nur vom wackelnden Test.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
