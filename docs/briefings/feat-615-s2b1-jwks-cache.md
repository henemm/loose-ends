---
spec_file: docs/specs/feat-615-schnitt-2b1-jwks-cache.md
spec_sha256: 997753ba44ac52dac83744b1d094782b1ee26b15bee8fae41d4a135a3da4ece7
spec_frozen_sha256: c2f6e888f269c3753109d16392fd15b495c914d3104b1aa831fc47097bf43324
---

# PO-Briefing: feat-615-s2b1-jwks-cache

- **Spec:** docs/specs/feat-615-schnitt-2b1-jwks-cache.md
- **Issue:** #615
- **Erstellt:** 2026-11-03

## Was gebaut wird

Der Dienst holt Apples Anmelde-Schlüssel, merkt sie sich eine Stunde und lädt sie höchstens einmal pro Minute nach.

## Definition of Done

Der Testlauf des Dienstes und die automatische Prüfung auf GitHub sind grün; für Nutzer ist noch nichts sichtbar, weil nichts den Baustein aufruft.

## Wie geprüft wird

Tests mit nachgestelltem Apple und gesteuerter Uhr belegen Zwischenspeicher, Sperre und Fehlerfälle; echtes Apple-Verhalten wird nicht geprüft.

## Kritische Anmerkungen

- Ergänzung zur Vorgabe aus Schnitt 2a: Die Minutensperre gilt auch bei leerem oder abgelaufenem Speicher, damit niemand Apple überlastet.
- Bei Apple-Störung nach Ablauf der Stunde werden Anmeldungen bis zu einer Minute abgelehnt, bewusst aus Sicherheitsgründen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
