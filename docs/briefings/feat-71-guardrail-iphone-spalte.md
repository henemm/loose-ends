---
spec_file: docs/specs/spike-71-schnitt-2a-laeufer-ablehnung.md
spec_sha256: f4f69de1ddde7cb7b9e024682f7adc40f3718b2dad6deccfbe1ef7ea12a89106
spec_frozen_sha256: 4e57ade3d9e8b8962ca407dde9872e415068a365f2bba50610cc41e4b24f5320
---

# PO-Briefing: feat-71-guardrail-iphone-spalte

- **Spec:** docs/specs/spike-71-schnitt-2a-laeufer-ablehnung.md
- **Issue:** #71
- **Erstellt:** 2026-10-28

## Was gebaut wird

Die Mess-App zählt vom iPhone-Modell abgelehnte Texte als Ergebnis, statt sie endlos zu wiederholen.

## Definition of Done

Neun Kriterien erfüllt, Simulator-Tests grün, nichts auf einem Gerät gelaufen; die iPhone-Messung selbst folgt später.

## Wie geprüft wird

Simulator-Tests zeigen, dass Ablehnungen gezählt werden und der Lauf endet; die tatsächliche Ablehnungsrate des iPhones messen sie nicht.

## Kritische Anmerkungen

- Liefert keine Zahl: Die iPhone-Spalte und damit die Entscheidung über die Annahme bleiben bis Teil 2b offen.
- Zusatz: Messdateien werden auch aus dem App-Speicher geladen, damit private Sätze nie ins Paket müssen.
- Verdrahtung des Startarguments in der Mess-App hat keinen Test, nur Bau und Dateiliste.

## Freigabe-Frage

Soll zuerst nur der Messcode ohne Gerätelauf gebaut werden, mit der eigentlichen iPhone-Messung als zweitem Schritt?
