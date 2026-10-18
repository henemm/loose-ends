---
spec_file: docs/specs/feat-442-schnitt-2-teilen-erweiterung.md
spec_sha256: 2c831beee4874224b6d3157c712c4403095acceee3b84aa2ac286021c9cd6b01
spec_frozen_sha256: 2f7d194ba974efc89a8b4b870450a7d469bf3a36ebacfc8be396d6e78be45419
---

# PO-Briefing: feat-442-teilen-erweiterung

- **Spec:** docs/specs/feat-442-schnitt-2-teilen-erweiterung.md
- **Issue:** #442
- **Erstellt:** 2026-10-18

## Was gebaut wird

Fotos und Dateien aus anderen Apps werden über „Teilen“ zum Anhang einer neuen Aufgabe.

## Definition of Done

Foto, PDF und Grenzfälle laufen im Simulator durch; der Gerätetest über TestFlight ist von dir bestätigt.

## Wie geprüft wird

Tests prüfen Typwahl, Kopieren, Größengrenze, Aufräumen; die Maske nur per Bildschirmfotos, nicht automatisiert.

## Kritische Anmerkungen

- Weite Aktivierungsregel: Loose Ends erscheint im Teilen-Menü auch für unbrauchbare Dateitypen; Apple-Prüfung unsicher.
- Mail „Drucken → Teilen“ wird neu Anhang statt verworfen; Speicher und Mail-Weg nur auf dem iPhone prüfbar.
- 240 von 250 erlaubten Zeilen; Ticket bleibt bis zu deiner TestFlight-Rückmeldung offen.

## Freigabe-Frage

Darf die Erweiterung Fotos und Dateien annehmen, obwohl sie dadurch für viele Dateitypen im Menü erscheint?
