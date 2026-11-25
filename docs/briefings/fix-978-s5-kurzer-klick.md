---
spec_file: docs/specs/fix-978-s5-kurzer-klick.md
spec_sha256: 5e7ef23b25197d9ca5754e6d5c604803b6f36df87af8bba584623ea10ddabc3a
spec_frozen_sha256: a1c1805d5453876e60b168d3ed78c8829bf4fd070d01498ba22da3149b09d74e
---

# PO-Briefing: fix-978-s5-kurzer-klick

- **Spec:** docs/specs/fix-978-s5-kurzer-klick.md
- **Issue:** #978
- **Erstellt:** 2026-11-25

## Was gebaut wird

Der Mac-Prüfablauf klickt kürzer auf das Menüleistensymbol und wiederholt höchstens einmal, wenn der Prüfklick nachweislich zu lange hielt.

## Definition of Done

Der Pflicht-Check „Mac Gallery“ läuft dreimal hintereinander grün, und ein Wiederholungslauf mit je 40 Durchgängen zeigt keinen roten Fall.

## Wie geprüft wird

Skripttests, ein Probelauf und ein 40er-Nachweislauf belegen das; die App selbst bleibt unverändert und wird nur im CI-Lauf benutzt.

## Kritische Anmerkungen

- Ob der Testläufer das Protokoll überhaupt lesen darf, ist unbelegt; sonst Stopp und neue Spec-Fassung mit App-Änderung.
- Der Mac-Test bleibt eine Prüfwerkzeug-Korrektur; ein Produktfehler beim Panel-Schließen wird damit nicht ausgeschlossen, nur unter 0,4 Sekunden weiter rot gemeldet.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
