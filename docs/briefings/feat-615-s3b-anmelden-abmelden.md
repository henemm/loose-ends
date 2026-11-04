---
spec_file: docs/specs/feat-615-schnitt-3b-anmelden-abmelden.md
spec_sha256: 878c9c8662c1f83ab006996181e6b2cd2e79b0fd7e13cb3c002c71abf1536a2f
spec_frozen_sha256: f7776f93a192ebd1983fec6e12f0c3535605fa65a5707b1992fafc3561447dd4
---

# PO-Briefing: feat-615-s3b-anmelden-abmelden

- **Spec:** docs/specs/feat-615-schnitt-3b-anmelden-abmelden.md
- **Issue:** #615
- **Erstellt:** 2026-11-04

## Was gebaut wird

Der Dienst bekommt zwei Türen, Anmelden mit Apple und Abmelden; die App ruft sie noch nicht auf.

## Definition of Done

Alle Tests laufen grün; Anmelden liefert eine Sitzung, Abmelden beendet genau diese eine, und jede Ablehnung klingt nach außen gleich.

## Wie geprüft wird

Tests mit nachgebautem Apple und echter Datenbank prüfen Abläufe und Ablehnungen; Apples echtes Verhalten bleibt bis zur App ungeprüft.

## Kritische Anmerkungen

- Umfang etwa 320 statt 250 Zeilen, allein durch Sicherheitstests; Teilen in zwei Schnitte wäre möglich, doppelt aber den Testaufbau.
- Abmelden meldet auch bei unbekannter Sitzung Erfolg, bewusst, damit nichts verraten wird.

## Freigabe-Frage

Gibst du den Umfang von etwa 320 statt 250 Zeilen frei, oder soll in zwei Schnitte geteilt werden?

## Ampel

Ampel: rot
