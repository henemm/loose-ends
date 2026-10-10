---
spec_file: docs/specs/fix-279-hoert-zu-anzeige.md
spec_sha256: 18422cddf29cec31f6ee152c7e2176da41b1e4e4684f30bd491ec7ab50b78ad3
---

# PO-Briefing: 279-pegel-mikrofon

- **Spec:** docs/specs/fix-279-hoert-zu-anzeige.md
- **Issue:** #279 (bleibt offen), #297 (wird geschlossen)
- **Erstellt:** 2026-10-10

## Was gebaut wird

Die Erfassung zeigt sofort „Ich höre …“, und der Mikrofonknopf pulsiert jetzt deutlich sichtbar im Takt deiner Stimme.

## Definition of Done

Normale Sprache lässt Pegel halb hoch ausschlagen und den Ring um bis zu 35 Prozent wachsen; das erste Wort ersetzt den Hinweis.

## Wie geprüft wird

Tests belegen Rechnung und Aussehen im Simulator; ob der Ring am iPhone wirklich sichtbar pulsiert, zeigt nur dein Test.

## Kritische Anmerkungen

- Neu seit Freigabe: Pegelskala empfindlicher; Ring wächst bis 35 Prozent mit der Stimme, Knopf selbst bleibt ruhig.
- Die neue Skala beruht auf einem Bildschirmfoto, einer Stimme; anderer Abstand verschiebt sie.
- Wartezeit bis zum ersten Wort bleibt unverändert.

## Freigabe-Frage

Ist ein pulsierender Ring bei unveränderter Wartezeit für dich ausreichend?
