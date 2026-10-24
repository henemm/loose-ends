# PO-Briefing: fix-637-start-zeigt-badge

- **Spec:** docs/specs/fix-637-zahl-symbol-jetzt.md
- **Issue:** #637
- **Erstellt:** 2026-10-24

## Was gebaut wird

Die Zahl am App-Symbol steht überall gleich über „Jetzt“, samt liegengebliebener Aufgaben.

## Definition of Done

Hennings Fall zeigt über „Jetzt“ und am Symbol 5; nach einem neuen Datum beide 4.

## Wie geprüft wird

Rechentests und iPhone-Simulator belegen Gleichheit; Mac nur als Foto, iPad nur rechnerisch.

## Kritische Anmerkungen

- Knäuel zählt mit, steht aber nicht unter „Jetzt“: sichtbare Zeilen sind dann einmal weniger als die Zahl.
- Kein UI-Test und kein Mac-Bild prüft das Knäuel; nur der Fall ohne Knäuel.
- „Jetzt“ wird wieder voller; kippt eine frühere Entscheidung, Liegengebliebenes herauszuhalten.

## Freigabe-Frage

Darf „Jetzt“ die Zahl inklusive Knäuel zeigen, obwohl das Knäuel dort nicht als Zeile steht?
