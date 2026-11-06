---
spec_file: docs/specs/feat-621-schnitt-3-aussteller.md
spec_sha256: bc81ad361f7874105b5e0183d215fed1d4fe51c51a509a18df268fa42ccb6dab
spec_frozen_sha256: b8091faf03e42fd284905b23d615577e0d81dbc4fcbdd8f5fbaaf1bcc4ab438c
---

# PO-Briefing: feat-621-s3-aussteller

- **Spec:** docs/specs/feat-621-schnitt-3-aussteller.md
- **Issue:** #621
- **Erstellt:** 2026-11-06

## Was gebaut wird

Der Dienst bekommt eine eigene Ausweisstelle, damit sich Claude später sicher anmelden und nur die eigenen Aufgaben abfragen kann.

## Definition of Done

Ein Testlauf zeigt den ganzen Weg bis zum Schlüssel und zur Abfrage eines einzigen Kontos; von außen bleibt alles geschlossen.

## Wie geprüft wird

Automatische Tests gegen eine Wegwerf-Datenbank beweisen Anmeldeweg, Ablehnungen und Log-Sauberkeit; echtes Verbinden mit claude.ai und Apple-Anmeldung sind nicht geprüft.

## Kritische Anmerkungen

- Neue Bibliothek oidc-provider (rund 34 Pakete) braucht deine ausdrückliche Freigabe; ohne sie muss die Spec neu geschrieben werden.
- Umfang etwa 650–770 Zeilen, weit über dem 250-Limit; Freigabe nimmt das ausdrücklich an.

## Freigabe-Frage

Gibst du die neue Bibliothek oidc-provider samt der Überschreitung des Umfangslimits frei?

## Ampel

Ampel: rot
