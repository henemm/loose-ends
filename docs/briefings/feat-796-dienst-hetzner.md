---
spec_file: docs/specs/feat-796-schnitt-1-prozess-einstieg.md
spec_sha256: 01d439cbc3699dc89166a53d2add701570deae51045e216eebf5eace2e0d61ab
spec_frozen_sha256: 6a9a0ba2afaff8dd6e93a35999d3b8c3d34643c15a424f81cf67ac66b34bd12e
---

# PO-Briefing: feat-796-dienst-hetzner

- **Spec:** docs/specs/feat-796-schnitt-1-prozess-einstieg.md
- **Issue:** #796
- **Erstellt:** 2026-11-02

## Was gebaut wird

Der Dienst bekommt einen Startpunkt mit Gesundheitsabfrage, die Datenbankausfälle und hohe Fehlerraten meldet und Verbindungsabbrüche übersteht.

## Definition of Done

Ein lokal gestarteter Dienst meldet „gesund“, bei gestoppter Datenbank „nicht verfügbar“, erholt sich nach deren Neustart ohne Prozessneustart und beendet sich sauber.

## Wie geprüft wird

Automatische Tests gegen echte Datenbank belegen jede Anforderung; nicht belegt sind Betrieb auf Hetzner, Adresse, Sicherung und Wiederherstellung (spätere Schnitte).

## Kritische Anmerkungen

- Nur Schnitt 1 von 4: Erreichbarkeit unter der Adresse, Sicherung, Wiederherstellung und Überwachung aus dem Ticket folgen erst später.
- Der Dienst läuft danach noch nirgends produktiv; der Verbindungsabbruch wird nur lokal geprüft, nicht auf Hetzner.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
