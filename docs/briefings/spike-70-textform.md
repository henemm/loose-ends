---
spec_file: docs/specs/spike-70-textform.md
spec_sha256: 9a78d4564e20f1ae42562189eade0e3be2ff9bb9bc1f4b137390fcfd31c56973
spec_frozen_sha256: 235de401e739c314e60f74b9601e026a562b9c2d4d4b997319ad6742e2bd5682
---

# PO-Briefing: spike-70-textform

- **Spec:** docs/specs/spike-70-textform.md
- **Issue:** #70
- **Erstellt:** 2026-10-25

## Was gebaut wird

Die Frage "Ist die Textform egal?" wird per Regelmessung beantwortet und entschieden dokumentiert.

## Definition of Done

Bericht und Annahme B2 tragen das Ergebnis mit Datum, ein neuer Test hält fest, dass bei Mails nur der Betreff übernommen wird.

## Wie geprüft wird

Ein Test beweist, dass Mail-Körper nie übernommen wird; die bestehende Regelmessung bleibt grün; Modellverhalten wird nicht gemessen.

## Kritische Anmerkungen

- Abweichung: Die verlangte Modellspalte entfällt; Modell-Formtreue bei Titel und Dauer bleibt bis #88 ungeprüft.
- B2 wird umformuliert: Regeln statt Modell erzeugen die Struktur; das Abbruchkriterium wird nie am Modell geprüft.
- Diktat im Korpus ist geschrieben, nicht gesprochen; echte Spracherkennung ist nicht gemessen.

## Freigabe-Frage

Darf B2 ohne Modellmessung abgeschlossen und die Modellprüfung von Titel und Dauer auf #88 verschoben werden?
