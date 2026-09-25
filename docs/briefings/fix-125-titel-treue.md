---
spec_file: docs/specs/fix-125-titel-treue.md
spec_sha256: 3b1bd88afbf389e2484d1a260dd761101ff5c9751be2fadbd2153bde0bbd270b
---

# PO-Briefing: fix-125-titel-treue

- **Spec:** docs/specs/fix-125-titel-treue.md
- **Issue:** #125
- **Erstellt:** 2026-09-25

## Was gebaut wird

Ein KI-Titel lässt sich per Tipp zurücksetzen; Zweck oder Objekt fallen im Titel nicht mehr weg.

## Definition of Done

Der Reset-Button erscheint nur bei KI-Titeln und stellt sofort den vorherigen Wert her; ein Beispieltitel mit Zweck-Anhang bleibt vollständig erhalten.

## Wie geprüft wird

Automatisierte Tests prüfen die Rückgängig-Funktion und einen Beispieltitel gegen einen Textkorpus; das sichtbare Verhalten nach dem Zurücksetzen wird nicht geprüft.

## Kritische Anmerkungen

- Weggelassener Teil bleibt im Titel statt in eigener Subheadline — Abweichung von Hennings Vorschlag, von ihm abgesegnet.
- Kein Test prüft, ob das Titelfeld nach dem Zurücksetzen korrekt bleibt (nur die Datenebene ist getestet).
- Die Titel-Kürzung bleibt ein KI-Modell — derselbe Fall kann bei erneutem Lauf wieder misslingen.

## Freigabe-Frage

Ist akzeptabel, dass der weggelassene Teil künftig im Titel selbst steht statt in einer eigenen Subheadline?
