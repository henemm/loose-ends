---
spec_file: docs/specs/tooling/fix-165-wiederholend-test.md
spec_sha256: e11ee8c7b4cc7932a9f5d9c95bc00ee3edb19d026ecf155eabbc155ee93b8564
---

# PO-Briefing: bug-165-wiederholend-test

- **Spec:** docs/specs/tooling/fix-165-wiederholend-test.md
- **Issue:** #165
- **Erstellt:** 2026-10-01

## Was gebaut wird

Der Test für das Löschen wiederholender Aufgaben läuft lokal und in der CI beim ersten Versuch grün.

## Definition of Done

Die Testklasse läuft lokal dreimal hintereinander grün, und der erste CI-Versuch besteht ohne Wiederholung.

## Wie geprüft wird

Der geänderte Test selbst läuft mehrfach lokal und einmal in der CI; er beweist keine Stabilität auf langsamen Runnern.

## Kritische Anmerkungen

- Der CI-Fehler ist nur aus einer Aufnahme abgeleitet, nicht nachgestellt; das Issue verlangt eine reproduzierte Ursache.
- Der neue Ausweichpfad für verpasste Druckgesten hat keinen eigenen Test; ein grüner CI-Lauf beweist ihn nicht.
- Zusatz: Aufräumen der Prioritätsliste (geschlossene Tickets) wurde nicht verlangt.

## Freigabe-Frage

Genügt es, nur den Test anzupassen und keinen App-Fehler zu beheben, obwohl die CI-Ursache unbelegt bleibt?
