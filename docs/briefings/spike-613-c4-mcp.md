---
spec_file: docs/specs/spike-613-schnitt-c4a-mcp-lesen.md
spec_sha256: 06210a9ea46973e1eac423752772c8d4b31c13bbac633b2d9040c3269efbc1a6
spec_frozen_sha256: 320385c8d068138d835f24cce6fca6e6039efb662282fb2b27473e9c61075b38
---

# PO-Briefing: spike-613-c4-mcp

- **Spec:** docs/specs/spike-613-schnitt-c4a-mcp-lesen.md
- **Issue:** #613
- **Erstellt:** 2026-11-01

## Was gebaut wird

Claude kann künftig die gespeicherte Aufgabenliste und die Zahl über „Jetzt“ lesen, vorerst nur intern im Test.

## Definition of Done

Im Test liefern beide Lesewerkzeuge Zahl und Aufgaben des richtigen Kontos ohne Rohtext, und die gesamte Server-Prüfkette ist grün.

## Wie geprüft wird

Automatische Tests gegen echte Datenbank belegen Kontotrennung, Reihenfolge und Zahl; sie beweisen nicht, dass sich Claude wirklich verbinden kann.

## Kritische Anmerkungen

- Claude ist danach noch nicht verbunden: Es gibt weder Port noch Anmeldung; beides folgt in späteren Schnitten.
- Drei neue Pakete (MCP-Baukasten, Zod, Testclient); Freigabe ergibt sich nur aus Hennings Wort „MCP-SDK“.
- Claude sieht den Stand des letzten Hochladens, nicht des Geräts; das Alter steht in der Ausgabe.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
