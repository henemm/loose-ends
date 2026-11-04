---
spec_file: docs/specs/feat-615-schnitt-3a-datenschicht.md
spec_sha256: 2f16df83a28948b51b51c6fd2b4c520c6419e1518e403aba08e03f17ee3036d1
spec_frozen_sha256: cf9c65653d1ec2f015fe2bf0c615195b666220aeaffedcc4cf251843a94350a6
---

# PO-Briefing: feat-615-s3-http-rand

- **Spec:** docs/specs/feat-615-schnitt-3a-datenschicht.md
- **Issue:** #615
- **Erstellt:** 2026-11-04

## Was gebaut wird

Der Dienst merkt sich die Apple-Anmelde-Kennung, damit beim Konto-Löschen der Apple-Zugang später korrekt widerrufen werden kann.

## Definition of Done

Alle Server-Tests und die automatische Prüfung laufen grün; in der App ändert sich nichts Sichtbares, weil noch nichts diese Bausteine aufruft.

## Wie geprüft wird

Automatische Tests belegen Ablegen, Rückgabe, Migration auf Bestandsdaten und Fehlbedienung; echtes Anmelden oder Widerrufen bei Apple wird nicht geprüft.

## Kritische Anmerkungen

- 10 statt 4–5 Dateien (fünf davon nur mechanisch angepasste Tests); Überhang ist begründet, aber Ihre Entscheidung steht noch aus.
- Aufteilung in drei Schnitte ist noch nicht entschieden; erst der dritte macht Anmelden und Löschen nutzbar, bis dahin kein sichtbarer Nutzen.

## Freigabe-Frage

Akzeptieren Sie den Überhang auf 10 Dateien und die Aufteilung in drei Schnitte (S3a, S3b, S3c)?

## Ampel

Ampel: rot
