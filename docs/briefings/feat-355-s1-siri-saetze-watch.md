---
spec_file: docs/specs/intents/feat-355-s1-siri-saetze-watch.md
spec_sha256: f005a7aeb117b2163524798c2eaef8fc6f140a7cb440198b36f625cc224432c2
---

# PO-Briefing: feat-355-s1-siri-saetze-watch

- **Spec:** docs/specs/intents/feat-355-s1-siri-saetze-watch.md
- **Issue:** #355
- **Erstellt:** 2026-10-13

## Was gebaut wird

Die Watch versteht deutsche Siri-Sätze wie „Erfasse in Loose Ends“ und fragt auf Deutsch nach dem Text.

## Definition of Done

Auf deiner Watch erkennt Siri die fünf deutschen Sätze, fragt nach dem Text und speichert ohne App-Start.

## Wie geprüft wird

Skripte und Paketinspektion belegen deutsche Texte im Watch-Paket; ob Siri versteht und speichert, zeigt nur dein TestFlight-Test.

## Kritische Anmerkungen

- Siri fragt „Was soll ich aufnehmen?“ statt des verlangten „Was soll ich mir merken?“.
- Kernziel ohne Gerätetest unbewiesen; ein bekannter Siri-Fehler könnte die Rückfrage auf der Watch verhindern.
- Watch erkennt Sätze nur wörtlich; Ersatznamen wie „Lose Enden“ wirken eventuell nicht.

## Freigabe-Frage

Gibst du den Schnitt frei, obwohl die Siri-Frage abweicht und die Wirkung erst per TestFlight bewiesen wird?
