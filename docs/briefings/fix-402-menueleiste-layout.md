---
spec_file: docs/specs/fix-402-menueleiste-layout.md
spec_sha256: 23596aafb0b15dc71e820d7801ccad5d4afe302139f4a59a01f93c027d92d4a2
---

# PO-Briefing: fix-402-menueleiste-layout

- **Spec:** docs/specs/fix-402-menueleiste-layout.md
- **Issue:** #402 (zusätzlich #405)
- **Erstellt:** 2026-10-13

## Was gebaut wird

Das Mac-Menüleistenfeld zeigt im Alltag keine Diagnose, bei echtem Problem eine ruhige Zeile; Knöpfe bleiben unverdeckt.

## Definition of Done

Im Mac-Prüfbau sind Knöpfe und Fußzeile mit und ohne Problemzeile sichtbar, Schweigen zeigt keine Diagnose; Screenshots hell und dunkel belegen das.

## Wie geprüft wird

Regeltests belegen, dass Schweigen nichts auslöst und Ton ohne Text warnt; das Panel-Layout belegen nur Screenshots, kein automatischer Test.

## Kritische Anmerkungen

- #405 (fehlendes Menü-Icon) wird nur dokumentiert, nicht repariert: Wahl „macOS“ in TestFlight; ob das hilft, zeigt erst dein Test.
- Kein automatischer Mac-Layout-Test: Verdeckte Knöpfe könnten später unbemerkt wiederkehren.
- Regel gilt auch auf iPhone/iPad; Pegel-Schwelle ungemessen; sechste Datei ist nur Doku.

## Freigabe-Frage

Gibst du das ruhige Panel frei, mit #405 nur als Doku-Hinweis und offenem Mac-Test?
