---
spec_file: docs/specs/feat-342-texte-fuer-fremde.md
spec_sha256: c0b2ef57bd05462312bb22e7e35746fb30934c4d6be85f7a0a854e3b028a4a31
spec_frozen_sha256: d0ef9330de141cfda6c07ddd9eeedd350c4c5c5b2b2288aba64db8b1f73edfd6
---

# PO-Briefing: feat-342-texte-fuer-fremde

- **Spec:** docs/specs/feat-342-texte-fuer-fremde.md
- **Issue:** #342
- **Erstellt:** 2026-10-26

## Was gebaut wird

Fremde Tester sehen deutsche Berechtigungsdialoge und erfahren ohne Apple Intelligence ehrlich, was die App trotzdem kann.

## Definition of Done

Auf deutschem Gerät erscheinen Mikrofon-, Sprach- und Kalenderdialog deutsch; das Onboarding ohne Modell nennt Tags, Dauer, fehlenden Titel; Datenschutz-Entwurf liegt vor.

## Wie geprüft wird

Ein Dateitest prüft deutsche Berechtigungstexte, zwei Oberflächentests den Hinweis; nicht geprüft wird er auf einem echten Gerät ohne Modell.

## Kritische Anmerkungen

- Abweichung: siebte Datei geändert; Tests erzwingen „Modell aus“, echtes Verhalten ohne Modell bleibt ungetestet.
- Datenschutztext ist nur Entwurf; Veröffentlichung und Apple-Adresse fehlen (#705), Ticket bleibt offen.
- Wortlaut der Dialoge ungetestet; Watch-Texte nur sinngleich.

## Freigabe-Frage

Soll das Paket aus Berechtigungstexten, Hinweis ohne Modell und unveröffentlichtem Datenschutz-Entwurf so gebaut werden?
