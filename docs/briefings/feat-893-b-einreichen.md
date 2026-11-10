---
spec_file: docs/specs/feat-893-schnitt-b-einreichen.md
spec_sha256: b3c5b7bc1efc7aec3f59d74da02d47b817d6f9396b6cd9c4d09cdd9549d25a4f
spec_frozen_sha256: fb9c3bc4e5d35828fd6b34ee0cca1acac05a833100d0ffd74ad3564d5e338f9e
---

# PO-Briefing: feat-893-b-einreichen

- **Spec:** docs/specs/feat-893-schnitt-b-einreichen.md
- **Issue:** #893
- **Erstellt:** 2026-11-10

## Was gebaut wird

Ein Werkzeug reicht Version 1.0.1 für iPhone, iPad und Mac nach vollständiger Vorprüfung bei Apple zur Prüfung ein.

## Definition of Done

Nach dem Echtlauf zeigt Apple 1.0.1 für iOS und Mac als „wartet auf Prüfung“, und das Ticket ist geschlossen.

## Wie geprüft wird

Tests mit nachgestelltem Apple-Server belegen Abläufe und Sicherheitsregeln; Apples echte Antworten beim Einreichen zeigt erst der einmalige Echtlauf nach dem Merge.

## Kritische Anmerkungen

- Einreichen ist nur in App Store Connect rücknehmbar; der Echtlauf lässt sich nicht wiederholen, Apples Antwortformen sind bisher ungesehen.
- Zusatz: Einreichen verlangt die Versionsnummer als Bestätigung; im Ticket nur als „Eingabe-Sperre“ verlangt, harmlos.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
