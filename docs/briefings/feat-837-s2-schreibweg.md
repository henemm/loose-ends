---
spec_file: docs/specs/feat-837-schnitt-2-schreibweg.md
spec_sha256: 638fb9a3b1a00dca32cb00d895b40d528c520c3dd4e61b7f06c213b2bf5b4f02
spec_frozen_sha256: 8d88507d5d189beab88e26d6aa6cb3df184046f07af8418a611d95606c2221e1
---

# PO-Briefing: feat-837-s2-schreibweg

- **Spec:** docs/specs/feat-837-schnitt-2-schreibweg.md
- **Issue:** #837
- **Erstellt:** 2026-11-05

## Was gebaut wird

Ein Weg im Repo, der den neuen App-Store-Untertitel auf Deutsch und Englisch in App Store Connect einträgt.

## Definition of Done

Der Handlauf trägt beide Untertitel ein und App Store Connect meldet sie zurück; heute bricht er sicher ab, weil Apple die Angaben sperrt.

## Wie geprüft wird

Tests gegen einen Nachbau beweisen Abbruch, Schreiben und Gegenprobe; ob Apples echte Schnittstelle den Änderungsbefehl akzeptiert, zeigt erst der Lauf nach der Mac-Prüfung.

## Kritische Anmerkungen

- Der Ticket-Beleg (Wert aus App Store Connect) bleibt offen, bis Apples Mac-Prüfung endet; das Ticket bleibt bis dahin offen.
- Der englische Untertitel blockiert die Einreichung von iOS 1.0.1, bis eine englische Store-Seite (#842) steht.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
