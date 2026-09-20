---
spec_file: docs/specs/measurement/issue-82-satzformen.md
spec_sha256: 9da4dc0ce6c3ef37179601290f3606fc6aec03a4702f702b52fbe26412ea13bb
---

# PO-Briefing: issue-82-satzformen

- **Spec:** docs/specs/measurement/issue-82-satzformen.md
- **Issue:** #82 (Schnitt 1, #87)
- **Erstellt:** 2026-09-20

## Was gebaut wird

Der Testkorpus bekommt 114 neue, unterschiedlich aufgebaute Sätze und der Bericht wertet sie getrennt nach Satzform aus.

## Definition of Done

Der Korpus enthält mindestens 100 Sätze in neun geforderten Formen, und der Bericht zeigt die Trefferquote je Form.

## Wie geprüft wird

Automatisierte Tests prüfen Form und Menge der Sätze; ob das Modell an echten Sätzen besser abschneidet, zeigt erst Schnitt 2.

## Kritische Anmerkungen

- Nur der Testkorpus wächst; echte iPhone-Sätze und eine neue Messung folgen erst in Schnitt 2 (#88).
- Noch nicht bei Henning angekommen: nicht übernommen, nicht auf seinem iPhone installiert, Prüfung noch offen.
- Der Plan ergänzt zwei Satzformen (Präfix, Diktat-Namensfehler), die im Issue nicht ausdrücklich verlangt waren.

## Freigabe-Frage

Reicht dir ein vielfältigerer, aber weiterhin künstlicher Testkorpus mit Formen-Auswertung als Zwischenschritt, bevor echte iPhone-Sätze folgen?
