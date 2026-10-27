---
spec_file: docs/specs/intents/feat-342-s2-komplikation-de.md
spec_sha256: 922770012c8b0bc9bb622c65973f60b3875763c42c145ed3049411e26635d6d1
spec_frozen_sha256: b6066e154a16c22d90f584801eb6f9b4cdc2761c8dec1a2696170ce2ec5f72be
---

# PO-Briefing: 342-s2-komplikation-de

- **Spec:** docs/specs/intents/feat-342-s2-komplikation-de.md
- **Issue:** #342
- **Erstellt:** 2026-10-27

## Was gebaut wird

Die Uhr-Komplikation heißt auf deutschen Geräten „Erfassen“ und beschreibt sich als „Öffnet die Erfassung.“

## Definition of Done

Die deutschen Texte stecken im gebauten Uhr-Paket; auf der Zifferblatt-Galerie sieht man sie erst nach TestFlight-Prüfung.

## Wie geprüft wird

Ein Test belegt, dass jeder Komplikationstext einen deutschen Eintrag hat; dass die Uhr ihn wirklich anzeigt, beweist er nicht.

## Kritische Anmerkungen

- Echte Anzeige auf der Uhr nur per TestFlight und nach deinem Wort prüfbar; Ticket bleibt bis dahin offen.
- Der Nachweis im gebauten Paket ist ein einmaliger Bauschritt, kein dauerhafter automatischer Test.

## Freigabe-Frage

Soll die Komplikation auf Deutsch erscheinen, mit Prüfung auf der Uhr erst später über TestFlight?
