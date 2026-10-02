---
spec_file: docs/specs/tooling/fix-165-wiederholend-test.md
spec_sha256: 5d72e0b10a8d76c54ca7c29bd9fde1bedcfb1a6300b5a7cf346af350a670a19e
---

# PO-Briefing: bug-165-wiederholend-test

- **Spec:** docs/specs/tooling/fix-165-wiederholend-test.md
- **Issue:** #165
- **Erstellt:** 2026-10-02

## Was gebaut wird

Die Oberflächentests der Erfassung laufen lokal mit Apple Intelligence und in der CI zuverlässig beim ersten Versuch grün.

## Definition of Done

Die ganze Testklasse läuft lokal dreimal hintereinander grün, und der erste CI-Versuch besteht ohne Wiederholung.

## Wie geprüft wird

Wiederholte Läufe der geänderten Tests belegen Stabilität nur statistisch; ein eigener Test für die neue Ausweichlogik fehlt.

## Kritische Anmerkungen

- Umfang gewachsen: Rund zehn weitere Tests werden umgebaut, das Issue verlangte nur einen. Jede Änderung kann zusichern, was vorher geprüft wurde, abschwächen.
- Drei grüne Läufe beweisen wenig, weil Titel-Umschreibung zufällig auftritt; zuvor schlugen nur zwei von drei Läufen fehl.
- Der CI-Wiederholungslauf bleibt bestehen und kann Fehler weiter verdecken; Entfernung ist nur ein Folge-Ticket.

## Freigabe-Frage

Soll das Ticket auf die ganze Testklasse erweitert werden, obwohl das Issue nur einen Test nannte?
