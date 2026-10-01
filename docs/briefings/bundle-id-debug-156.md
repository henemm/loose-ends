---
spec_file: docs/specs/tooling/fix-156-pruefkennung.md
spec_sha256: 4471a6ed34a28296cd098c1c5eda7a26acf96d70cd52dce9d024a6be697bbdc5
---

# PO-Briefing: bundle-id-debug-156

- **Spec:** docs/specs/tooling/fix-156-pruefkennung.md
- **Issue:** #156
- **Erstellt:** 2026-10-01

## Was gebaut wird

Prüfbauten auf dem iPhone bekommen eine eigene Kennung, damit sie Hennings echte App-Daten nie überschreiben.

## Definition of Done

Ein Testlauf zeigt beide Apps gleichzeitig installiert, Hennings Version unverändert, Prüf-Version mit eigenem Namen und Speicherbereich.

## Wie geprüft wird

Automatisierte Prüfungen sichern den normalen Programmstart ab; der Gerätetest beweist nur die Installation, keinen Bedienablauf.

## Kritische Anmerkungen

- Weicht vom Ticket ab: nur der Prüfweg, nicht die normale App, bekommt die neue Kennung — von Henning entschieden.
- Für künftige Prüfbauten muss Henning sich gelegentlich neu bei Xcode anmelden, sonst scheitert die Registrierung.
- Ob der eigene Cloud-Speicher entsteht, ist offen — misslingt es, läuft der Prüfbau nur lokal.

## Freigabe-Frage

Sollen Prüfbauten künftig getrennt von Hennings eigener App laufen, auch wenn das gelegentlich erneute Anmeldung braucht?
