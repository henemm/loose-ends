---
spec_file: docs/specs/feat-938-schnitt-2-dienst.md
spec_sha256: 62ce45eaec1140cc828f9f20273e16d661c9349778b84770d95af20a61147dcd
spec_frozen_sha256: 58f37a3b0f54a616e54dbba26653308f34cd1581e21fd370973890b927e93261
---

# PO-Briefing: feat-938-s2-dienst

- **Spec:** docs/specs/feat-938-schnitt-2-dienst.md
- **Issue:** #938
- **Erstellt:** 2026-11-19

## Was gebaut wird

Claude kann beim Anlegen oder Ändern einer Aufgabe eine Wiederholung und beim Anlegen einen Link mitgeben.

## Definition of Done

Claude legt in claude.ai „alle 26 Wochen Zahnarzt“ mit Link an, das Ergebnis zeigt „erledigt“, und die Aufgabe wiederholt sich in der App.

## Wie geprüft wird

Automatische Dienst-Tests prüfen gültige und ungültige Formen sowie das Durchreichen; die Wirkung in der App und in claude.ai zeigt erst der Durchlauf.

## Kritische Anmerkungen

- Das Ausrollen erfolgt erst, wenn Hennings App den Schnitt-1-Bau hat; sonst entsteht still eine Aufgabe ohne Wiederholung.
- Das Ticket selbst konnte ich nicht lesen; Abgleich lief über die Analyse-Dokumente mit PO-Entscheidungen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
