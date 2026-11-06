---
spec_file: docs/specs/feat-842-schnitt-2-platzierungspfad.md
spec_sha256: b22df33748508fbed0b20e306aadd1cbbaedcb86810ec14922c42d38ce7f48aa
spec_frozen_sha256: b7f610a69b1391882f7b88daff16ed2ce33e6fa816095d14dece6ea0d527dc85
---

# PO-Briefing: feat-842-s2-platzierungspfad

- **Spec:** docs/specs/feat-842-schnitt-2-platzierungspfad.md
- **Issue:** #842
- **Erstellt:** 2026-11-06

## Was gebaut wird

Die Store-Prüfung fragt Apple nach Bildplatzierungen und Referenzdaten richtig und nennt künftig den Grund, wenn Apple ablehnt.

## Definition of Done

Der nächste Prüflauf zeigt für alle drei Versionen die Platzierungen samt Feldnamen und die Gruppennamen, oder nennt Apples Ablehnungsgrund.

## Wie geprüft wird

Automatische Tests gegen einen Apple-Nachbau mit echten Pfaden belegen Pfad, Fehlergrund und Gruppenlesen; ob Apple wirklich so antwortet, zeigt erst der Prüflauf.

## Kritische Anmerkungen

- Apples Antwortform für Platzierungen und Gruppen ist nur aus der Dokumentation bekannt; der Prüflauf nach dem Merge bestätigt sie erstmals.
- Kein Simulator-Durchlauf, da nur ein Skript geändert wird; der echte Prüflauf ersetzt ihn.
- Texte und Bilder schreibt erst Schnitt 3 und 4; das Ticket bleibt offen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
