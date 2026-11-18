---
spec_file: docs/specs/feat-625-schnitt-2-privacy-manifest.md
spec_sha256: a60d8a3fc70aacde1dfce080eab63eafed105508e164f8225f6561e234be4775
spec_frozen_sha256: 21f25a8c73f2854008ff5b2226227087cb0e3056d7736802eaa975c8d247a776
---

# PO-Briefing: feat-625-s2-privacy-manifest

- **Spec:** docs/specs/feat-625-schnitt-2-privacy-manifest.md
- **Issue:** #625
- **Erstellt:** 2026-11-18

## Was gebaut wird

Testbauten mit Claude-Verbindung melden Apple ihre erhobenen Daten korrekt; Store-Bauten bleiben unverändert ohne erfasste Daten.

## Definition of Done

Ein automatischer Test und eine Prüfung beim Bau bestätigen: Testbauten mit Claude nennen drei Datentypen, Store-Bauten keinen; der Schalter bleibt aus.

## Wie geprüft wird

Tests und ein Simulator-Bau belegen die Einträge; ob die Prüfung in einem echten TestFlight-Lauf grün ist, zeigt erst der nächste Lauf.

## Kritische Anmerkungen

- Echter Nachweis im Archiv fehlt bis zum nächsten regulären Konto-Testlauf; ein Fehler dort würde jeden TestFlight-Lauf stoppen.
- Ob Apple abweichende Manifest-Einträge gegen "Keine Daten erfasst" ablehnt, ist nur aus Fallberichten bekannt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
