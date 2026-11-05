---
spec_file: docs/specs/tooling/feat-846-waechter-appinfo.md
spec_sha256: 6fd42cefae996b56f1a412b8980aa6bfe46449e33bf3caf2c164de8d980b956f
spec_frozen_sha256: c8e4695e437c29c52334003c351c7b9fc72a2c49bb41d348d543398b19516929
---

# PO-Briefing: feat-846-waechter-appinfo

- **Spec:** docs/specs/tooling/feat-846-waechter-appinfo.md
- **Issue:** #846
- **Erstellt:** 2026-11-05

## Was gebaut wird

Ein täglicher Lesezugriff auf App Store Connect meldet in 837 einmalig, wenn der Untertitel schreibbar wird oder Mac 1.0 fertig ist.

## Definition of Done

Ein manueller Probelauf nach dem Merge zeigt „warten“ ohne Kommentar, solange Mac 1.0 in Prüfung ist; alle Skripttests sind grün.

## Wie geprüft wird

Skripttests mit Apple-Nachbau prüfen alle Lagen und Fehler; der Einmal-Kommentar selbst wird nur als Workflow-Text geprüft, nicht ausgeführt.

## Kritische Anmerkungen

- Umfang etwa 290 Zeilen, über dem 250er-Limit; deine Freigabe bestätigt die Grenze von 300.
- Einmal-Kommentar-Logik läuft erst im echten Fall; vorher nur Textprüfung.
- Entfernen des Wächters nach dem Untertitel ist nur Aufgabe, ohne Test.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
