---
spec_file: docs/specs/feat-795-schnitt-5b-weckruf-betrieb.md
spec_sha256: 564e9b4fe3497c40030e87686e666a8501c9f10ec746726617e0f1c124ff0f18
spec_frozen_sha256: d68d97d8850c6e4b5f37165b47551b477646e3bf1db43826e138842497f3c775
---

# PO-Briefing: feat-795-s5b-weckruf-betrieb

- **Spec:** docs/specs/feat-795-schnitt-5b-weckruf-betrieb.md
- **Issue:** #795
- **Erstellt:** 2026-11-15

## Was gebaut wird

Der Dienst kann ein Gerät anstupsen, sobald Claude einen Auftrag hinterlegt; Apple-Schlüssel und Zugang werden eingerichtet.

## Definition of Done

Die Anmeldeadresse für Geräte ist von außen erreichbar, Apple akzeptiert die Zugangsdaten des Dienstes, und der Dienst läuft danach stabil.

## Wie geprüft wird

Außenabfragen und ein Probeaufruf an Apple mit erfundenem Gerät belegen Zugang; ob ein echtes Gerät geweckt wird, belegt es nicht.

## Kritische Anmerkungen

- Ursprungsanfrage nur als Kontextdokument gelesen, der Issue-Wortlaut selbst wurde nicht geprüft.
- Bietet Apple nur Produktion an, entfallen Weckrufe für Test-Geräte; sie holen dann beim Öffnen ab.
- Zustellung an ein echtes Gerät wird erst im Folgeschnitt belegt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
