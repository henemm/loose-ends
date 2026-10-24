---
spec_file: docs/specs/measurement/feat-88-messbericht-gewichtung.md
spec_sha256: 158213b37f20b3ea5e05eab69d9fd8245727e15dd41c87dd5ee1045cb322944d
spec_frozen_sha256: 8ff663735e8a4a0240acfd4d863be8d0ada053fba7929a0ebe788e1b4fc1d1e6
---

# PO-Briefing: feat-88-messbericht-gewichtung

- **Spec:** docs/specs/measurement/feat-88-messbericht-gewichtung.md
- **Issue:** #88
- **Erstellt:** 2026-10-24

## Was gebaut wird

Der Messbericht nennt die Gesamtzahl zusätzlich nach Hennings Satzverteilung gewichtet, mit Regel-Spalte neben dem Modell.

## Definition of Done

Der neu erzeugte Bericht enthält einen Abschnitt mit gewichteter Titel- und Datum-Gesamtzahl für Modell und Regel, Gewichte als Hennings Angabe gekennzeichnet.

## Wie geprüft wird

Tests belegen Rechnung, leere Gruppen und Berichtsaufbau; sie belegen nicht, dass Hennings Gewichte stimmen.

## Kritische Anmerkungen

- Gewichte ungeprüft: Zählung an 287 Titeln ergibt 73,5 % Stichwörter statt einem Drittel; die Gesamtzahl hängt stark daran.
- Gewichtet wird nur über zwei Merkmale, nicht alle zwölf Satzformen; die Gesamtzahl bleibt grobe Näherung.
- Datum-Spalte fürs Modell vorgesehen, obwohl es seit #95 kein Datum mehr liefert; Nutzen unklar.

## Freigabe-Frage

Soll der Bericht mit Hennings ungeprüften Gewichten und der abweichenden Gegenzählung daneben gebaut werden?
