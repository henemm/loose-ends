---
spec_file: docs/specs/feat-893-schnitt-a-pruefen.md
spec_sha256: d1407810b4261fd31a554f3ee253253dc2310683a1cf3174349ceeb1d30c6b4c
spec_frozen_sha256: 74f218550477ea4e002aa0f549e70d5a0dc4c20d9f874f3e2145fd48f264323d
---

# PO-Briefing: feat-893-einreichen

- **Spec:** docs/specs/feat-893-schnitt-a-pruefen.md
- **Issue:** #893
- **Erstellt:** 2026-11-09

## Was gebaut wird

Ein reines Lese-Werkzeug prüft, ob iPhone-, iPad- und Mac-Version 1.0.1 bei Apple einreichbar sind; es reicht nichts ein.

## Definition of Done

Ein echter Lauf gegen Apple meldet je Plattform „bereit“ oder nennt Gründe, ohne etwas zu verändern, bevor das Einreichen gebaut wird.

## Wie geprüft wird

Automatische Tests mit nachgestellter Apple-Schnittstelle belegen jede Regel und dass nie geschrieben wird; Apples echte Antworten zeigt erst der Lauf nach Merge.

## Kritische Anmerkungen

- Das Ticket ist damit nicht erfüllt: Einreichen, Sperrwort und Gegenprobe fehlen und folgen in einem zweiten, eigenen Schritt.
- Apples Antwortform der Einreichungen ist nur aus Dokumentation bekannt; der Lauf nach dem Merge muss sie bestätigen.
- „Bereit“ heißt nicht „Apple nimmt an“: Altersfreigabe und Datenschutz prüft Apple selbst.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
