---
spec_file: docs/specs/enrichment/fix-535-dauerfehler.md
spec_sha256: 8dabbab2d98ce9fb9e4fdd191b9497c59397490ee1d88931a9bd662efced3e89
spec_frozen_sha256: 87f7f5bcc97504d18d3ffbfee67ad6cab72bb395b563c39f9154e4f0cf907a28
---

# PO-Briefing: fix-535-dauerfehler

- **Spec:** docs/specs/enrichment/fix-535-dauerfehler.md
- **Issue:** #535
- **Erstellt:** 2026-10-21

## Was gebaut wird

Notizen, die das Modell dauerhaft ablehnt, gehen nicht mehr bei jedem Start erneut ans Modell.

## Definition of Done

Dauerhaft abgelehnte Notizen gehen kein zweites Mal ans Modell, vorübergehende Fehler werden weiter wiederholt.

## Wie geprüft wird

Unit-Tests mit simuliertem Modellfehler belegen Einteilung und Einmaligkeit; echtes Modell wird erst über TestFlight gesehen.

## Kritische Anmerkungen

- Ablehnungen („refusal") bleiben vorübergehend und werden weiter bei jedem Start wiederholt.
- Dauerfehler bleibt auch nach System-Updates stehen; Abhilfe nur manuell über „Neu analysieren".
- Watch-Verträglichkeit und Doku-Ergänzung haben keinen automatischen Test.

## Freigabe-Frage

Genügt es, nur Sicherheitsfilter und zu lange Notizen dauerhaft auszuschließen, während alle anderen Fehler weiter wiederholt werden?
