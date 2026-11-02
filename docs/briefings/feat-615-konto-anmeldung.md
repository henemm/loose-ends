---
spec_file: docs/specs/feat-615-schnitt-1-konten-sitzungen.md
spec_sha256: cafd3c47e752896fb4125b2e02c36e7535444898621698ac96848b506cf84741
spec_frozen_sha256: 7ed33523025cab04946d3da463c281a7326243926e26d4925a05d3db72f09ada
---

# PO-Briefing: feat-615-konto-anmeldung

- **Spec:** docs/specs/feat-615-schnitt-1-konten-sitzungen.md
- **Issue:** #615
- **Erstellt:** 2026-11-02

## Was gebaut wird

Im Dienst entsteht die Grundlage für Konten: anlegen, Sitzung starten und beenden, Konto samt allen Daten löschen.

## Definition of Done

Alle Konto-Funktionen laufen gegen eine echte Testdatenbank grün; in der App ändert sich nichts Sichtbares, Anmelden ist noch nicht möglich.

## Wie geprüft wird

Automatische Tests gegen echtes Postgres belegen Anlegen, Sitzungen und vollständiges Löschen; Apple-Anmeldung und App-Bedienung sind nicht enthalten und ungeprüft.

## Kritische Anmerkungen

- Ticket-Ziel (Anmelden, Abmelden, Löschen im Simulator) kommt erst nach drei Folgeschnitten; dieser Schnitt zeigt nichts Sichtbares.
- "Watch und Widgets sehen die Sitzung" entfällt wegen Weg B; der Ticket-Text ist insoweit veraltet.
- Abschrift und Aufträge erhalten keine Datenbank-Absicherung; Löschen geschieht per Code, Restrisiko verwaiste Zeilen erst ab dem HTTP-Schnitt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
