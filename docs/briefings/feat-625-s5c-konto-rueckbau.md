---
spec_file: docs/specs/feat-625-schnitt-5c-konto-rueckbau.md
spec_sha256: 2d79fa5e015624e377417a53bfcf6014a52771c1452d2d22903638df56a10635
spec_frozen_sha256: f6b3b1947a68efbc3c88d07ae72e4d0e513e6fe87fb33bae76289f302117627b
---

# PO-Briefing: feat-625-s5c-konto-rueckbau

- **Spec:** docs/specs/feat-625-schnitt-5c-konto-rueckbau.md
- **Issue:** #625
- **Erstellt:** 2026-11-23

## Was gebaut wird

TestFlight-Läufe starten künftig immer gleich, ohne Sonderschalter „Konto-Bau“ und ohne Warnhinweis in „Was testen“.

## Definition of Done

Ein von Hand gestarteter TestFlight-Lauf läuft ohne Schalter durch beide Prüfungen, und der neue Bau trägt keinen Konto-Bau-Hinweis.

## Wie geprüft wird

Automatische Skripttests belegen Ablauf, Texte und Dokumentation; ob der echte Lauf bei GitHub durchgeht, zeigt erst der Lauf nach dem Merge.

## Kritische Anmerkungen

- Alte, markierte Testbauten bleiben für den Store gesperrt; der 1.0.2-Bau muss nach diesem Schnitt entstehen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
