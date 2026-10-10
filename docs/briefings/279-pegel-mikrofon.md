---
spec_file: docs/specs/fix-279-hoert-zu-anzeige.md
spec_sha256: 41b29943eecc36d7940f34da8667ac225c8acd181eeafc7fc174ced4cf2ead45
---

# PO-Briefing: 279-pegel-mikrofon

- **Spec:** docs/specs/fix-279-hoert-zu-anzeige.md
- **Issue:** #279 (bleibt offen), #297 (wird geschlossen)
- **Erstellt:** 2026-10-10

## Was gebaut wird

Die Erfassung zeigt sofort „Ich höre …“, einen deutlicheren Pegel und einen runden Mikrofonknopf, damit klar ist, dass zugehört wird.

## Definition of Done

Beim Öffnen steht sofort „Ich höre …“, Sprache lässt den Pegel etwa halb hoch ausschlagen, das erste Wort ersetzt den Hinweis.

## Wie geprüft wird

Tests belegen Pegelrechnung, Hinweisregel und Aussehen im Simulator; die echte Pegelhöhe belegt nur dein Test am iPhone.

## Kritische Anmerkungen

- Die Wartezeit bis zum ersten Wort wird nicht kürzer, nur sichtbar; #279 bleibt offen.
- Halbe Pegelhöhe bei Sprache ist gerechnet, nicht gemessen; Beleg erst mit deinem iPhone-Test.
- Wachsender Ring und Grundlinie haben keinen automatischen Test; sie werden nur per Screenshot angesehen.

## Freigabe-Frage

Genügt dir diese reine Sichtbarmachung, obwohl die Wartezeit selbst unverändert bleibt?
