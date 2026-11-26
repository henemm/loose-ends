---
spec_file: docs/specs/enrichment/feat-982-schnitt-1-modell-raus.md
spec_sha256: 70985b8de08b54849bd6875dd9fced394313bbdc55725e7b47a05ae770d448d4
spec_frozen_sha256: 3d2aa2a95bf924ed01ad06acfdac699a29ee29dde22533e532f5b83525ac6fa7
---

# PO-Briefing: feat-982-modell-ausbauen

- **Spec:** docs/specs/enrichment/feat-982-schnitt-1-modell-raus.md
- **Issue:** #982
- **Erstellt:** 2026-11-26

## Was gebaut wird

Die App erzeugt keine KI-Titel und KI-Dauern mehr; Titel und Dauer entstehen nur noch aus festen Regeln.

## Definition of Done

Eine erfasste Aufgabe behält ihren gesprochenen Titel, zeigt keine erfundene Dauer, und „Neu analysieren“ erwähnt Apple Intelligence nicht mehr.

## Wie geprüft wird

Automatische Tests und ein Simulator-Durchlauf belegen das; das Verhalten auf deinem Gerät zeigt erst dein TestFlight-Test.

## Kritische Anmerkungen

- Neue Aufgaben bleiben vorerst in „Neu“; das Entfernen dieser Liste folgt separat (#1000).
- Onboarding-Hinweis und Datenschutztext nennen Apple Intelligence noch; Bereinigung erst in späteren Schnitten, das Issue bleibt offen.
- Issue-Text war nicht lesbar; Abgleich nur gegen Analyse, Epic-Entscheidung und Spec.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
