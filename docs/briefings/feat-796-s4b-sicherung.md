---
spec_file: docs/specs/feat-796-schnitt-4b1-sicherung.md
spec_sha256: b753431d17e93319fd89057a7513b846b8496db4440f7057a0bf74d6e0b1e84f
spec_frozen_sha256: 9dc0e9fc90d49abd5ceb5f083ab61810d43485908e2bb129e088702725383f16
---

# PO-Briefing: feat-796-s4b-sicherung

- **Spec:** docs/specs/feat-796-schnitt-4b1-sicherung.md
- **Issue:** #796
- **Erstellt:** 2026-11-04

## Was gebaut wird

Die Datenbank des Dienstes wird jede Nacht gesichert, lokal und extern, und eine Sicherung einmal in eine leere Datenbank zurückgespielt.

## Definition of Done

Eine Sicherung aus dem externen Speicher wird zurückgespielt; Tabellen und Migrationsstand stimmen mit live überein, der nächtliche Lauf meldet weiterhin.

## Wie geprüft wird

Automatische Tests prüfen Dump-Skript und Fehlerfälle; der Rückspielbeweis läuft einmal von Hand auf dem Server. Eine dauerhafte automatische Rückspielprobe fehlt noch.

## Kritische Anmerkungen

- Ein Fehler der neuen Sicherung stoppt den gemeinsamen Alarm aller Sicherungen; gewollt, kann aber Fehlalarm auslösen.
- Alle Tabellen sind leer: bewiesen wird Struktur, nicht Nutzerdaten.
- Ticket bleibt offen, bis die automatische Wochenprobe (zweiter Schnitt) folgt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
