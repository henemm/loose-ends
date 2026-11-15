---
spec_file: docs/specs/fast/fix-782-refresh-once.md
spec_sha256: fa825f5183b4087633256c3a4228c03c2ea61a084f36cb173696912c5e19ed17
spec_frozen_sha256: 29283b78e775b5f97b703ba75cf651bbd63a94e2d8f844aed53fcfa86ca4dce6
---

# PO-Briefing: fix-782-refresh-once

- **Spec:** docs/specs/fast/fix-782-refresh-once.md
- **Issue:** #782
- **Erstellt:** 2026-11-15

## Was gebaut wird

Die Hintergrund-Auffrischung der Mitteilungen meldet sich nach Zeitablauf nur noch einmal, nämlich als nicht erfolgreich, statt zusätzlich als erfolgreich.

## Definition of Done

Nach Ablauf des Zeitfensters kommt genau eine Abschlussmeldung mit "nicht erfolgreich"; Zeitplan und Kennung bleiben unverändert, Morgen- und Abendmitteilung kommen weiter.

## Wie geprüft wird

Ein automatischer Test simuliert den Ablauf aus dem Hintergrund und zählt die Meldungen; ob iOS sich real so verhält, zeigt nur das Gerät.

## Kritische Anmerkungen

- Keine — Spec deckt die Anfrage ab, jede Anforderung hat einen Test.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
