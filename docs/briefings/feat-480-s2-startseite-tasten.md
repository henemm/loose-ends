---
spec_file: docs/specs/feat-480-schnitt-2-startseite.md
spec_sha256: 72a7243baf8c57f3afe6807feb698fbd60e6bc2fdc3d9c03ada982f4a19c8748
spec_frozen_sha256: b8a03fbae7f31ecbe03d25399ff14359abd1027d350d78df12ed0019c8a60740
---

# PO-Briefing: feat-480-s2-startseite-tasten

- **Spec:** docs/specs/feat-480-schnitt-2-startseite.md
- **Issue:** #480
- **Erstellt:** 2026-10-22

## Was gebaut wird

Auf der Mac-Startseite lassen sich Aufgaben per Pfeiltasten wählen, mit Leertaste erledigen, mit Rücktaste löschen; das Fenster hat eine Mindestgröße.

## Definition of Done

Pfeile wählen eine Jetzt-Zeile, Leertaste erledigt mit Rückgängig, Rücktaste fragt vor dem Löschen, Schreibfeld tippt normal, Fenster bleibt mindestens 760×520 Punkte groß.

## Wie geprüft wird

Automatische Mac-Tests spielen jede Taste und die Mindestgröße durch; Hover- und Auswahlfarbe belegen nur Fotos, nicht Tests.

## Kritische Anmerkungen

- Ticket schließt beim Zusammenführen, deine Mac-Abnahme über TestFlight folgt erst danach.
- Tasten im Schreibfeld sind auf dem Mac undokumentiert; nur ein Test sichert, dass Leertaste dort nichts erledigt.

## Freigabe-Frage

Soll Schnitt 2 gebaut werden, obwohl das Ticket vor deiner Mac-Abnahme schließt?
