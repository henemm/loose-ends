---
spec_file: docs/specs/tooling/fix-172-ui-tests-first-try.md
spec_sha256: f0be54564d11b0d473e34913de19a47bde3594d35a027089eee107abb5265a68
---

# PO-Briefing: fix-172-ui-tests-first-try

- **Spec:** docs/specs/tooling/fix-172-ui-tests-first-try.md
- **Issue:** #172
- **Erstellt:** 2026-10-02

## Was gebaut wird

Zwei wackelnde automatische Tests werden stabilisiert und die stille Testwiederholung in der CI entfernt; die App bleibt unverändert.

## Definition of Done

Beide Testklassen laufen lokal grün, die Wiederholung ist entfernt, und drei CI-Läufe hintereinander zeigen im Protokoll keine Fehlerzeile.

## Wie geprüft wird

Der Fehler wird vor dem Fix unter Last ausgelöst und danach grün gezeigt; dass die CI dauerhaft stabil bleibt, beweisen nur drei Läufe.

## Kritische Anmerkungen

- Nur eine von drei Fehlerquellen ist belegt; zwei Läufe sind nicht mehr auswertbar, CI kann trotzdem rot werden.
- Rückfall bei roter CI: Wiederholung sichtbar machen statt entfernen, das widerspräche dem Ticket.
- Der Sonderfall des Ersatz-Tippens wird nur in einer Wegwerf-Kopie geprüft, nicht dauerhaft getestet.

## Freigabe-Frage

Soll die Testwiederholung entfernt werden, obwohl zwei der drei früheren Fehlschläge ungeklärt sind und die CI rot werden könnte?
