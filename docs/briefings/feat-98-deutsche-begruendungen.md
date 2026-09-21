---
spec_file: docs/specs/enrichment/feat-98-deutsche-begruendungen.md
spec_sha256: 2963f2ea584b7b40f52af4caa4f812a34291fe3de40585a7504719db0f67b2c4
---

# PO-Briefing: feat-98-deutsche-begruendungen

- **Spec:** docs/specs/enrichment/feat-98-deutsche-begruendungen.md
- **Issue:** #98
- **Erstellt:** 2026-09-21

## Was gebaut wird

Die Begründungssätze zu automatisch erkannten Terminen erscheinen künftig auf Deutsch statt auf Englisch.

## Definition of Done

Ein Test bestätigt, dass alle neun Begründungssätze im deutschen Sprachpaket vom englischen Text abweichen.

## Wie geprüft wird

Ein Test prüft im gebauten App-Paket, dass jeder der neun Sätze vom englischen Original abweicht — nicht, ob er korrekt ist.

## Kritische Anmerkungen

- Die Tests zeigen keinen deutschen Text auf einem echten Gerät, nur den Katalogeintrag — abweichend von der Ursprungsanfrage.
- Für drei von sechs Kriterien (Wortlaut, Kennzeichnung, unveränderter Code) fehlt eine automatisierte Prüfmethode im Plan.
- Der Test prüft nur Abweichung vom englischen Satz — ein falscher deutscher Text bestünde ihn ebenfalls.

## Freigabe-Frage

Reicht der Nachweis, dass die deutschen Sätze existieren und anders klingen als die englischen, oder muss der genaue Wortlaut zusätzlich geprüft werden?
