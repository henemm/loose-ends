---
spec_file: docs/specs/feat-241-schnitt-3b-aktueller-ort-zuhause-arbeit.md
spec_sha256: 4e9bbbaa108867cea45b5a51c848b0df7fadacca7f9fc94dd90037687f088e14
spec_frozen_sha256: a148863a230cf17c5f1bf22a5bf7f3473dff32943adf15fae75634b1406fd5d1
---

# PO-Briefing: feat-241-ort-3b

- **Spec:** docs/specs/feat-241-schnitt-3b-aktueller-ort-zuhause-arbeit.md
- **Issue:** #241
- **Erstellt:** 2026-10-23

## Was gebaut wird

Ort-Auswahl bietet Aktueller Ort, Zuhause und Arbeit an und warnt bei ausgeschaltetem Standort oder schon erreichtem Ort.

## Definition of Done

Im Simulator setzt Aktueller Ort den Ort, Zuhause geht mit einem Tipp, beide Hinweise erscheinen nur zur rechten Zeit.

## Wie geprüft wird

Regel- und Simulatortests mit festem Standort; echter Gerätestandort und iCloud-Abgleich zwischen Geräten bleiben unbewiesen.

## Kritische Anmerkungen

- Echter Standort und iCloud-Abgleich nur über TestFlight, erst nach Merge und auf dein Wort.
- Zuhause/Arbeit liegen im iCloud-Schlüsselspeicher statt als Datenmodell; bei Gleichzeitigkeit gewinnt der letzte Schreiber.
- Umfang doppelt über Limit (11 Dateien, +400 Zeilen), von dir gewählt.

## Freigabe-Frage

Gibst du Aktueller Ort, Zuhause/Arbeit und beide Hinweise in diesem einen größeren Schnitt frei?
