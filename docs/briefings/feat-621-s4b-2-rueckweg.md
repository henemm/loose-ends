---
spec_file: docs/specs/feat-621-schnitt-4b2a-rueckweg.md
spec_sha256: 365fafb427ca473b718798b2015d3303e15622de6201b08f54d2ae2eacdcbbfd
spec_frozen_sha256: b192c85217042667057a64d110bd149384cf72ddd9f899621ad989df00c1f174
---

# PO-Briefing: feat-621-s4b-2-rueckweg

- **Spec:** docs/specs/feat-621-schnitt-4b2a-rueckweg.md
- **Issue:** #621
- **Erstellt:** 2026-11-06

## Was gebaut wird

Der Dienst nimmt Apples Antwort nach der Anmeldung streng geprüft an und legt Konto samt kurzem Ticket an.

## Definition of Done

Testlauf zeigt: gültige Apple-Antwort ergibt Konto und einminütiges Ticket, falsche oder wiederholte Antworten werden abgelehnt, niemand ist angemeldet.

## Wie geprüft wird

Automatische Tests spielen Apple nach; ob echtes Apple alle Prüfwerte so liefert, zeigt erst der spätere Echtlauf.

## Kritische Anmerkungen

- Neu: Teilung in zwei Schnitte; erst der zweite meldet wirklich an.
- Umfang: 6 Dateien, ca. 320 Zeilen statt 4–5 und 250, wegen Sicherheitstests.
- Unbelegt: Apple liefert die Prüfnummer im Token; fehlt sie, scheitert die Anmeldung sicher.

## Freigabe-Frage

Nimmst du Teilung in zwei Schnitte und Überschreitung (6 Dateien, ca. 320 Zeilen) für diesen Schnitt an?

## Ampel

Ampel: rot
