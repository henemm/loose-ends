---
spec_file: docs/specs/tooling/feat-183-testflight-beleg.md
spec_sha256: 0321dc2fa9ae2d4951a1d557bd6f1a7d13778edda0b47174ff197a46c364712f
---

# PO-Briefing: feature-183-testflight-beleg

- **Spec:** docs/specs/tooling/feat-183-testflight-beleg.md
- **Issue:** #183
- **Erstellt:** 2026-10-03

## Was gebaut wird

Jeder TestFlight-Lauf zeigt die Archiv-Tabelle im Protokoll und wartet, bis Apple den Build als verarbeitet meldet.

## Definition of Done

Ein echter Lauf zeigt vier Tabellenzeilen OK und die Build-Nummer mit Status VALID; die Anleitung beschreibt den Schritt.

## Wie geprüft wird

Pythontests gegen einen Apple-Nachbau belegen Warten, Fehlerfälle und Geheimhaltung; Apples echte Antworten zeigt nur der echte Lauf.

## Kritische Anmerkungen

- Nachweis braucht einen echten Lauf: verbraucht eine Build-Nummer, lädt einen Build in die Gruppe „Familie“.
- Apples Filter nach Build-Nummer ist unbelegt; schlimmstenfalls wartet der Lauf 45 Minuten und wird rot.
- Neue Tests laufen nicht in der CI; spätere Fehler im Wartescript blieben unbemerkt.

## Freigabe-Frage

Darf für den Nachweis ein echter TestFlight-Lauf mit Build-Upload stattfinden?
