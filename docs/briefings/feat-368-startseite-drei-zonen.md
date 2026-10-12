---
spec_file: docs/specs/feat-368-startseite-drei-zonen.md
spec_sha256: 54355306f4c32333e5a2b7dc61443571f33383f11af6f52dd030204855d02601
---

# PO-Briefing: feat-368-startseite-drei-zonen

- **Spec:** docs/specs/feat-368-startseite-drei-zonen.md
- **Issue:** #368
- **Erstellt:** 2026-10-12

## Was gebaut wird

Der Startbildschirm zeigt Eingang, Jetzt-Aufgaben, Situations-Chips und kompakte Ansichten statt einer gleich gewichteten Liste.

## Definition of Done

Eingangsleiste nur bei Neuem, höchstens fünf Jetzt-Zeilen ohne Doppelungen, Chips mit Anzahl, graues Raster; iPad und Mac unverändert.

## Wie geprüft wird

Unit-Tests belegen die Jetzt-Reihenfolge, Bedien-Tests Leiste, Aufklappen, Wischen, Chips; Optik und große Schrift nur per Screenshot.

## Kritische Anmerkungen

- Vier Teilschritte statt der freigegebenen drei; die Startseite ist zwischendurch halb umgebaut.
- Chip-Umbruch, große Schrift, Farbbudget nur per Screenshot; der Schnell-Chip hat keinen Test.
- „Aus Als nächstes entfernen“ lässt fällige Aufgaben in Jetzt stehen, wirkt scheinbar wirkungslos.

## Freigabe-Frage

Startseite so in vier Schritten umbauen, Jetzt mit höchstens fünf Zeilen und jeder Aufgabe einmal?
