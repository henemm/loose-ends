---
spec_file: docs/specs/intents/feat-355-s1-siri-saetze-watch.md
spec_sha256: 4b1979c40a8d259f8591ef93cd6992458377c3866794070bb37a04c1732682b3
---

# PO-Briefing: feat-355-s1-siri-saetze-watch

- **Spec:** docs/specs/intents/feat-355-s1-siri-saetze-watch.md
- **Issue:** #355
- **Erstellt:** 2026-10-13

## Was gebaut wird

Auf der Watch soll deutsche Siri „Erfasse in Loose Ends“ verstehen, nach dem Text fragen und speichern.

## Definition of Done

Deine Watch versteht per Siri auf Deutsch alle fünf Sätze, fragt nach dem Text und speichert ihn ohne App-Start aufs iPhone.

## Wie geprüft wird

Tests prüfen nur Satzlisten, Übersetzungen und Paketinhalt; ob Siri auf der echten Watch zuhört und speichert, zeigt nur dein Gerätetest.

## Kritische Anmerkungen

- Siri-Erkennung und Speichern sind nur am Gerät prüfbar; Build 52 scheiterte bereits am App-Namen.
- Siri-Rückfrage nach dem Text versagte auf älteren Uhren; Ersatz öffnet die App, verfehlt „ohne App-Start“.
- Dialog weicht vom Ticket ab: „Was soll ich aufnehmen?“ statt „…mir merken?“.

## Freigabe-Frage

Soll dieser Schnitt mit Siri-Berechtigung für die Watch gebaut und per TestFlight getestet werden?
