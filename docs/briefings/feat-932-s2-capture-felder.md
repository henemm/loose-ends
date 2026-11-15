---
spec_file: docs/specs/feat-932-schnitt-2-dienst.md
spec_sha256: 9d1ade59e5e0bbe88c51a79f35a711248971ff49b8864c1462b395aca25d5ee9
spec_frozen_sha256: 564cd54da013b2bbd15511367d570061529b680593a7173303d5dbbbc6f6e022
---

# PO-Briefing: feat-932-s2-capture-felder

- **Spec:** docs/specs/feat-932-schnitt-2-dienst.md
- **Issue:** #932
- **Erstellt:** 2026-11-15

## Was gebaut wird

Claude kann beim Erfassen einer Aufgabe gleich Titel, Fälligkeit, Wichtigkeit, Dauer, Tags und Projekt mitgeben, der Dienst prüft die Form.

## Definition of Done

Alle neuen und bisherigen Dienst-Tests sind grün; eine Erfassung ohne Angaben verhält sich unverändert, eine mit falschen Angaben wird abgewiesen und nichts gespeichert.

## Wie geprüft wird

Automatische Tests prüfen Form und Speicherung der Angaben; nicht geprüft werden Tag- und Projektnamen sowie das Verhalten auf dem Gerät.

## Kritische Anmerkungen

- Dieser Schnitt wird nicht ausgerollt; sichtbar für Claude werden die Angaben erst mit Schnitt 3 samt Test auf deinem Gerät.
- Ticket bleibt offen: Nachträgliches Ändern per Werkzeug, Anleitung und claude.ai-Durchlauf fehlen noch (Schnitt 3).

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
