---
spec_file: docs/specs/measurement/spike-108-selbstkonsistenz-signal.md
spec_sha256: c1283db668de3cdf48242fb2facf0339d3a2deaf9b099f6ea521671a68809149
---

# PO-Briefing: spike-108-selbstkonsistenz-signal

- **Spec:** docs/specs/measurement/spike-108-selbstkonsistenz-signal.md
- **Issue:** #108 (Kontext-Dokument als Ursprungsanfrage-Ersatz genutzt)
- **Erstellt:** 2026-09-22

## Was gebaut wird

Baut das Werkzeug, um zu prüfen, ob wiederholte Modellantworten Unsicherheit zuverlässig anzeigen.

## Definition of Done

Alle Testfälle sind grün, die Prüfungen laufen automatisch durch, und eine leere Berichtsvorlage für das spätere Messergebnis existiert.

## Wie geprüft wird

Automatisierte Tests prüfen Rechenlogik und Datenformate mit Beispielwerten; der eigentliche mehrtägige Messlauf mit echten Daten läuft erst später.

## Kritische Anmerkungen

- Der eigentliche Messlauf, der zeigt ob das Signal taugt, ist nicht Teil dieses Schnitts — nur das Werkzeug.
- Ursprünglich sollten auch Personen und Projekt gemessen werden; fehlen hier mangels Wahrheitsdaten im Export.
- Der Test für das Export-Skript ist kein automatisierter Test, nur eine manuelle Probe.

## Freigabe-Frage

Reicht dir, dass dieser Schnitt nur das Messwerkzeug liefert — die Antwort auf die eigentliche Frage folgt in einem späteren Schritt?
