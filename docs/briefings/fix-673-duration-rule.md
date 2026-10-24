---
spec_file: docs/specs/fix-673-dauer-regel-anschliessen.md
spec_sha256: be613b2baa71fb81ebdb829742227b52315bcdf1c17880e70e7ab94f6f64aff8
spec_frozen_sha256: 5a63763f29b7e0e046331f4ab984edfa894439925bd74aa7c09e2cb4e25359bb
---

# PO-Briefing: fix-673-duration-rule

- **Spec:** docs/specs/fix-673-dauer-regel-anschliessen.md
- **Issue:** #673
- **Erstellt:** 2026-10-24

## Was gebaut wird

Nennt dein Erfassungstext eine Länge wie „20 Minuten“, setzt die App die Dauer automatisch und zeigt sie im Detail.

## Definition of Done

Erfassen von „Steuerbescheid prüfen 20 Minuten“ zeigt im Detail eine Dauer mit Uhr-Zeichen, ohne dass du sie eintippst.

## Wie geprüft wird

Automatische Tests und ein Simulator-Durchlauf belegen Setzen, Schutz eigener Werte und Neu-Analysieren; echte Geräte werden erst nach Auslieferung über TestFlight geprüft.

## Kritische Anmerkungen

- Aus „20 Minuten“ wird „30 min“ (Aufrundung); das Ticket erwartet 20, die Spec übernimmt die frühere Rundungsentscheidung.
- Bestehende Aufgaben bekommen keine Dauer nachträglich, nur über „Neu analysieren“.
- Die Kalender-Rückfrage ist künftig mit der erkannten Dauer vorbefüllt.

## Freigabe-Frage

Ist es für dich in Ordnung, dass „20 Minuten“ als „30 min“ erscheint und alte Aufgaben unverändert bleiben?
