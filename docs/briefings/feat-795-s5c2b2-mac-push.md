---
spec_file: docs/specs/feat-795-schnitt-5c2b2-mac-push.md
spec_sha256: abbd30ea2aeeb4beb0a33b6e1cdf661181f7aeb92cbafb0757c42d9c114a5845
spec_frozen_sha256: f9503293299bc977c7e025b2e74466554c6fc3338c9824541f693b60d0262518
---

# PO-Briefing: feat-795-s5c2b2-mac-push

- **Spec:** docs/specs/feat-795-schnitt-5c2b2-mac-push.md
- **Issue:** #795
- **Erstellt:** 2026-11-19

## Was gebaut wird

Das Mac-Programm bekommt von Apple die Erlaubnis für Push-Nachrichten, damit es später vom Dienst geweckt werden kann.

## Definition of Done

Der nächste TestFlight-Lauf besteht beide Prüfungen: Mac-Bau trägt die Push-Erlaubnis, iPhone-Bau bleibt unverändert hochladbar.

## Wie geprüft wird

Automatische Prüfungen belegen die Erlaubnis in Konfiguration und Mac-Prüfung; ob Apple das iPhone-Archiv akzeptiert, zeigt erst der TestFlight-Lauf.

## Kritische Anmerkungen

- Ob das iPhone-Archiv die Mac-Erlaubnis verträgt, zeigt erst der Lauf nach dem Merge; sonst stoppt er vor dem Upload.
- Sichtbare Wirkung entsteht erst mit dem Folgeschnitt; dieser Schnitt allein ändert für Nutzer nichts.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
