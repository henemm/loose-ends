---
spec_file: docs/specs/feat-621-schnitt-4c1-ablage-je-client.md
spec_sha256: ba4e8478fa7cc652dbf4dc20e48c47987aea547a8997f7ccb7f54e0418a2aa93
spec_frozen_sha256: ab43d34dc336ccfab62295982303581ea0101712be6d5b42e53c777a3c193524
---

# PO-Briefing: feat-621-s4c-web-token

- **Spec:** docs/specs/feat-621-schnitt-4c1-ablage-je-client.md
- **Issue:** #621
- **Erstellt:** 2026-11-06

## Was gebaut wird

Der Dienst merkt sich je Konto eine Apple-Berechtigung pro Zugang und gibt beim Löschen jede zurück.

## Definition of Done

Alle Tests laufen grün; beim Löschen eines Kontos werden App- und Browser-Berechtigung bei Apple zurückgegeben, ein Fehlschlag verhindert das Löschen nie.

## Wie geprüft wird

Tests mit Testdatenbank und nachgebautem Apple belegen Ablage und Löschen; echtes Apple und die Wirkung über Zugangsgrenzen hinweg bleiben ungeprüft.

## Kritische Anmerkungen

- Scoping-Limits überschritten: neun statt vier bis fünf Dateien, rund 300 statt 250 Zeilen; nur du kannst das annehmen.
- Ticketziel wird erst mit Folgeschnitt 4c-2 erreicht; dieser Schnitt legt noch nichts ab.
- Ob Apple beim Widerruf eines Tokens das andere ungültig macht, ist undokumentiert.

## Freigabe-Frage

Nimmst du die Überschreitung auf neun Dateien und rund 300 Zeilen für diesen Teilschnitt an?

## Ampel

Ampel: rot
