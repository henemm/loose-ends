---
spec_file: docs/specs/fix-637-zahl-symbol-jetzt.md
spec_sha256: 7b852d00e88c45b78fa6cbd365c689e10151305f7531bda5abbc252c7fb179c2
spec_frozen_sha256: d241c3acdfcd113ba884247fee67b0a3b74bf4aab6581bd45d6c8fd9a1fb2bd5
---

# PO-Briefing: fix-637-start-zeigt-badge

- **Spec:** docs/specs/fix-637-zahl-symbol-jetzt.md
- **Issue:** #637
- **Erstellt:** 2026-10-23

## Was gebaut wird

Die Zahl am App-Symbol steht auf iPhone, iPad und Mac genauso über "Jetzt", und alle gezählten Aufgaben stehen dort.

## Definition of Done

Bei deinem Fall zeigen Symbol und "Jetzt" beide 5, mit fünf Zeilen, davon vier mit "Neues Datum"; nach neuem Datum sinken beide auf 4.

## Wie geprüft wird

Automatische Tests prüfen die Rechenregel und den Ablauf im iPhone-Simulator; Mac nur per Foto, iPad nur per Rechentest, nicht auf echten Geräten.

## Kritische Anmerkungen

- Die Startseite wird voller: Liegengebliebene stehen bei "Jetzt" nun mit, was zuvor bewusst vermieden wurde.
- Mac und iPad werden nicht per Bedienung geprüft; "am richtigen Platz" ist vage formuliert.

## Freigabe-Frage

Soll "Jetzt" künftig alle Aufgaben zeigen, die das Symbol zählt, auch liegengebliebene?
