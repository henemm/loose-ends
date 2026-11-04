---
spec_file: docs/specs/feat-837-schnitt-1-app-info-befund.md
spec_sha256: 1c2a863bdf640b20c35f59e25bcb65954aef36084828e5c742daa1e74ccfd04c
spec_frozen_sha256: bc65c3a5dd653a0d1085b640a14853a14f329dd53fc5e6bf6d6f60983fcb1da1
---

# PO-Briefing: feat-837-store-untertitel

- **Spec:** docs/specs/feat-837-schnitt-1-app-info-befund.md
- **Issue:** #837
- **Erstellt:** 2026-11-04

## Was gebaut wird

Die Store-Prüfung zeigt nur lesend, welcher Apple-Eintrag zur iPhone-Fassung gehört und änderbar ist.

## Definition of Done

Der Prüflauf nennt für beide Apple-Einträge Zustand und Zuordnung, und im Ticket steht, ob die iPhone-Fassung änderbar ist.

## Wie geprüft wird

Automatische Tests gegen einen Nachbau belegen Ausgabe und reines Lesen; der echte Apple-Eintrag zeigt sich erst im Lauf nach dem Zusammenführen.

## Kritische Anmerkungen

- Abweichung vom Ticket: Untertitel setzen, englischen Eintrag anlegen und Texte anpassen fehlen; im Store ändert sich noch nichts.
- Ein neuer englischer Eintrag braucht vermutlich weitere Pflichtangaben (Beschreibung, Bilder); Schritt 2 kann deutlich größer werden.
- Gibt es keinen änderbaren Eintrag für die iPhone-Fassung, muss der Untertitel auf Apple warten.

## Freigabe-Frage

Soll das Ticket wie vorgeschlagen in drei Schritte geteilt werden, beginnend mit diesem reinen Nachsehen?

## Ampel

Ampel: rot
