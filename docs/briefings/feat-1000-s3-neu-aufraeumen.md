---
spec_file: docs/specs/feat-1000-schnitt-3a-regeln-und-ansicht-neu.md
spec_sha256: e08d93e5009243480f7c0ce746bc4aa8330a70769157330c54a3265ba2e88a10
spec_frozen_sha256: 20073dcbb05b395003330dede6e4ebdc864291657965b1dd321c1c3c47134ed0
---

# PO-Briefing: feat-1000-s3-neu-aufraeumen

- **Spec:** docs/specs/feat-1000-schnitt-3a-regeln-und-ansicht-neu.md
- **Issue:** #1000
- **Erstellt:** 2026-11-27

## Was gebaut wird

Die Ansicht „Neu“ und ihre Sichtungsregeln werden aus der App entfernt; erfasste Aufgaben stehen unverändert sofort in ihrer Liste.

## Definition of Done

Eine per Schreibzeile erfasste Aufgabe steht sofort in der Liste, der Index zeigt kein „Neu“, alle Tests laufen grün.

## Wie geprüft wird

Automatische Tests belegen, dass „Neu“ fehlt und neue Aufgaben normal zählen; ein Simulatordurchlauf bestätigt es, die Zeilen-Tönung bleibt ungeprüft.

## Kritische Anmerkungen

- Die Tönung „noch nicht angesehen“ bleibt vorerst sichtbar; ihre Entfernung, Katalogtexte und Doku folgen in Schnitt 3b.
- Das Issue bleibt bis 3b offen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
