---
spec_file: docs/specs/feat-477-schnitt-2-detail.md
spec_sha256: 8a40b8e691f9ec771c1b99f3fac9dc41debda401202b8356a1f184f23e4d1ab1
spec_frozen_sha256: 515a5538362fec1db96c991c1ed573342d732d3294c7e54c71fc6c74afa03a86
---

# PO-Briefing: feat-477-schnitt-2-detail

- **Spec:** docs/specs/feat-477-schnitt-2-detail.md
- **Issue:** #477
- **Erstellt:** 2026-10-18

## Was gebaut wird

Auf Mac und breitem iPad sieht das Detail wie auf dem iPhone aus: Papier, Haarlinien, großer Titel, mittige Spalte.

## Definition of Done

Auf den Mac-Bildern aus der CI und im iPad-Querformat stehen Zeilen auf Papier statt Karten, das iPhone sieht unverändert aus.

## Wie geprüft wird

Unit-Tests belegen nur Titelgröße und Spaltenbreite; das Aussehen auf Mac und iPad wird per Bildern beschrieben, nicht automatisch getestet.

## Kritische Anmerkungen

- Ob es auf dem Mac klappt, zeigt sich erst im CI-Bild; ein Umbau des Behälters (+60 Zeilen) ist vorgesehen.
- Aussehen und Bedienung im breiten Fenster prüft kein automatischer Test, nur beschriebene Bilder.
- Linien-Feinschliff aus der Analyse (Linienbeginn, dunklere Kopflinie) ist ausgeklammert.

## Freigabe-Frage

Soll das Detail auf Mac und breitem iPad im iPhone-Papierstil gebaut werden?
