---
spec_file: docs/specs/measurement/spike-22-kaltstart.md
spec_sha256: aecad4681490d9891029759a0b6a31bd9c0dfaa0469e72828671a29c222b36ae
---

# PO-Briefing: spike-22-kaltstart

- **Spec:** docs/specs/measurement/spike-22-kaltstart.md
- **Issue:** #22
- **Erstellt:** 2026-10-08

## Was gebaut wird

Es wird gemessen, ob die Erfassung nach einem Kaltstart in unter einer Sekunde eingabebereit ist.

## Definition of Done

Messbericht mit Mittelwert, Ausreißern, Läufen und Gerät liegt vor; bei Verfehlung existiert ein Folge-Ticket.

## Wie geprüft wird

Tests prüfen nur die Messwerkzeuge; die Zeiten selbst liefern je zehn automatische Läufe und zehn Druck-Läufe.

## Kritische Anmerkungen

- Gemessen wird auf dem iPhone 16 Pro, nicht dem Mindestgerät iPhone 15 Pro; ein Treffer beweist das Budget dort nicht.
- Zeit vom Tastendruck bis Appstart bleibt ungemessen; „eingabebereit“ heißt Mikrofon hört, Textfeld ist nicht fokussiert.
- Erfassung ist heute ein Fenster, keine schlanke Szene wie in ADR-9; wird nur berichtet.

## Freigabe-Frage

Genügt dir eine Messung auf dem iPhone 16 Pro statt dem iPhone 15 Pro?
