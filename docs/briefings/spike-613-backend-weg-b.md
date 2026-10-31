---
spec_file: docs/specs/spike-613-schnitt-1-abschrift-auftraege.md
spec_sha256: 340722fc7666fe93283dabe963b6845255123795285833c099c31c2810b96198
spec_frozen_sha256: 38d2ffc3191e615dfdb9eb0bce07cc5127705310a0804c2af730090c1e2475b5
---

# PO-Briefing: spike-613-backend-weg-b

- **Spec:** docs/specs/spike-613-schnitt-1-abschrift-auftraege.md
- **Issue:** #613
- **Erstellt:** 2026-10-31

## Was gebaut wird

Die App kann ihre „Jetzt“-Aufgaben als Abschrift ausgeben und Aufträge von Claude (erfassen, abhaken, Fälligkeit setzen) sicher ausführen.

## Definition of Done

Alle zehn Kriterien sind erfüllt, Unit-Tests und App-Bau laufen grün, und eine Vertragsbeschreibung mit Beispielen liegt vor; sichtbar ändert sich in der App nichts.

## Wie geprüft wird

Automatische Tests belegen gleiche Zahl wie in der App, Ablehnung veralteter Aufträge ohne Änderung und Rundlauf; echten Dienst, Netz oder Claude prüfen sie nicht.

## Kritische Anmerkungen

- Aufgabentitel stammen fast wörtlich aus dem Rohtext und verlassen später iCloud; Datenschutzfreigabe folgt erst mit #625.
- Claude sieht nur „Jetzt“; Fällig- und Lose-Enden-Listen fehlen, und ohne Dienst ist noch nichts für Henning nutzbar.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
