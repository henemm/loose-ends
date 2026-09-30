---
spec_file: docs/specs/tooling/fix-156-pruefkennung.md
spec_sha256: 5b1c524d547170ea3e13c2139a5831fd3e693c6cddfdbbaa97f61a41a1b7a253
---

# PO-Briefing: bundle-id-debug-156

- **Spec:** docs/specs/tooling/fix-156-pruefkennung.md
- **Issue:** #156
- **Erstellt:** 2026-09-30

## Was gebaut wird

Prüfbauten fürs Testen auf dem Gerät bekommen eine eigene Kennung, damit sie Hennings echte App nie überschreiben.

## Definition of Done

Auf dem Gerät sind Prüfbau und Hennings echte App gleichzeitig sichtbar, und Hennings Installation bleibt beim Testen unverändert erhalten.

## Wie geprüft wird

Automatisierte Tests prüfen die Kennungslogik und den unveränderten Alltagsbau; die Gerätetrennung wird per Lesebefehl belegt, nicht per Test.

## Kritische Anmerkungen

- Ursprungsanfrage verlangte Kennung an der Debug-Einstellung; Umsetzung setzt sie stattdessen am Prüfweg an, mit Hennings Zustimmung.
- Ob der Cloud-Abgleich im Prüfbau tatsächlich getestet wird, steht noch nicht fest, hängt vom ersten Testlauf ab.
- Ein Teil der Nachweise erfolgt per manuell ausgeführtem Prüfbefehl, nicht per automatisiertem Test.

## Freigabe-Frage

Ist es in Ordnung, dass die Kennung am Testweg statt an der Debug-Einstellung hängt, wie ursprünglich verlangt?
