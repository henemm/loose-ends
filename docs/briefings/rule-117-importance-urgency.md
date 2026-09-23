---
spec_file: docs/specs/enrichment/rule-117-importance-urgency.md
spec_sha256: a2dfd14c7c752cd4c1c5e037b0e708cdc7f2bdf4c30e5145b308110ca408e093
---

# PO-Briefing: rule-117-importance-urgency

- **Spec:** docs/specs/enrichment/rule-117-importance-urgency.md
- **Issue:** #117
- **Erstellt:** 2026-09-23

## Was gebaut wird

Wichtigkeit und Dringlichkeit einer Aufgabe werden künftig an Schlüsselwörtern im Text erkannt, nicht mehr vom Gerätemodell geraten.

## Definition of Done

Jede Schlüsselwort-Kategorie hat einen bestandenen automatisierten Test, die App baut fehlerfrei, und Henning hat sie auf seinem iPhone geprüft.

## Wie geprüft wird

Automatisierte Tests zeigen, dass jede Schlüsselwort-Kategorie den richtigen Wert liefert — nicht, ob die Schlüsselwortlisten im echten Alltag alle Fälle treffen.

## Kritische Anmerkungen

- Trefferquote der Schlüsselwörter lässt sich nicht messen — es gibt keine verlässliche Vergleichswahrheit für diese beiden Felder.
- Ohne Treffer bleibt das Feld leer — viele Aufgaben zeigen künftig weder Wichtigkeit noch Dringlichkeit an.
- Zwei bestehende Messungen laufen danach ins Leere; deren Aufräumen ist als eigenes Folge-Ticket vorgemerkt, nicht Teil hiervon.

## Freigabe-Frage

Ist akzeptabel, dass Aufgaben ohne erkanntes Schlüsselwort keine Wichtigkeits- oder Dringlichkeits-Einstufung erhalten, statt einer geschätzten?
