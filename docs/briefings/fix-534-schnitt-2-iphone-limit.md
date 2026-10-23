---
spec_file: docs/specs/fix-534-schnitt-2-iphone-latenz.md
spec_sha256: 3b929fbbe70c07f1d84b71542074d548e05da773fd140ac87451b2e9715d7737
spec_frozen_sha256: 69157ccd2eaee7cb3f75868b0297675ef486af8dfea48061906fc5e4fbc13102
---

# PO-Briefing: fix-534-schnitt-2-iphone-limit

- **Spec:** docs/specs/fix-534-schnitt-2-iphone-latenz.md
- **Issue:** #534
- **Erstellt:** 2026-10-22

## Was gebaut wird

Die Modell-Antwortzeit deines iPhones wird mit denselben sechs Notizen wie am Mac gemessen und im Bericht ausgewertet.

## Definition of Done

Zehn Messstarts auf dem iPhone sind gelaufen, der Bericht nennt Kennzahlen kalt/warm und einen Vorschlag für das neue Limit; im Produkt ändert sich nichts.

## Wie geprüft wird

Automatische Tests prüfen Startargumente, Korpus und Auswertung; der Gerätelauf liefert die Zahlen, ob das vorgeschlagene Limit trägt, zeigt erst Schnitt 3.

## Kritische Anmerkungen

- Spec sprengt die Dateigrenze: neun statt vier bis fünf Dateien, etwa 170 Zeilen.
- Gerätelauf dauert etwa 20 Minuten bei entsperrtem iPhone, das iPhone erwärmt sich; deine Freigabe vom 22.10. liegt vor.
- Ob am Strom oder am Akku gemessen wird, bleibt offen; die Limit-Zahl entsteht erst nach der Messung.

## Freigabe-Frage

Gibst du die Spec trotz Überschreitung der Dateigrenze und des 20-minütigen iPhone-Laufs frei?
