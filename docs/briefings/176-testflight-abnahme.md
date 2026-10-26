---
spec_file: docs/specs/feat-176-testflight-abnahme.md
spec_sha256: 44563a53f950cc39a581a90d6aaeeda0840a652eed7d8a8a91bd5aad1f5746f5
spec_frozen_sha256: 09a7c50f88cbf857cca614738a5ec773a8aa33d70d9ae45af989c354bd092f8d
---

# PO-Briefing: 176-testflight-abnahme

- **Spec:** docs/specs/feat-176-testflight-abnahme.md
- **Issue:** #176
- **Erstellt:** 2026-10-25

## Was gebaut wird

Eine feste Prüfliste für die TestFlight-Fassung, die belegte Schritte von Lücken trennt, plus ein Prüfblock für die Lücken.

## Definition of Done

Die Liste steht mit Ticket und Buildnummer je belegtem Schritt, und die Lücken sind in einem Prüfblock gebündelt.

## Wie geprüft wird

Ein Skripttest prüft Aufbau und Belegangaben der Liste; ob die Schritte auf deinen Geräten wirklich funktionieren, beweist er nicht.

## Kritische Anmerkungen

- Nur Lücken, kein vollständiges Durchspielen; Belege stammen aus früheren Builds, nicht frisch.
- Testgruppe wandert nach #342; Meilenstein war schon geschlossen, zwei Ticketpunkte entfallen.
- Ergänzt um iPad, Mac und Ortserinnerung; Prüfblock läuft erst nach deinem "jetzt ist ein Test möglich".

## Freigabe-Frage

Freigeben, dass nur Lücken geprüft und frühere Builds als Beleg gewertet werden?
