---
spec_file: docs/specs/feat-938-schnitt-1-app.md
spec_sha256: 0d498fb1aae575f7585475508de2ca223bce8d6b50096f0529a9da5c42a651ac
spec_frozen_sha256: d14d956a36a236cbbd780c54fe291ce697f1fd940ca8b1e3a67ab0bb28c06f35
---

# PO-Briefing: feat-938-wiederholung-claude

- **Spec:** docs/specs/feat-938-schnitt-1-app.md
- **Issue:** #938
- **Erstellt:** 2026-11-17

## Was gebaut wird

Die App versteht Aufträge von Claude, die Wiederholung und Link mitbringen, und legt solche Aufgaben korrekt an.

## Definition of Done

Von Claude angelegte Aufgaben tragen ihren Rhythmus samt Link, Erledigen verschiebt die Fälligkeit richtig weiter, und ein neuer TestFlight-Bau liegt vor.

## Wie geprüft wird

Automatische Tests decken jede Anforderung ab; nicht geprüft werden der Dienst, die Übertragung der Liste „Family“ und der Durchlauf in claude.ai.

## Kritische Anmerkungen

- Dies ist nur Schnitt 1 von 3; #938 bleibt offen, die Liste „Family“ wandert erst in Schnitt 3.
- Mit Tests über dem Änderungslimit (etwa 335 statt 250 Zeilen); Sicherheitstests, wie früher angenommen.
- Wiederholung lässt sich per Claude nicht wieder entfernen; „2. Samstag im Februar“ wird jährlich zum Datum.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
