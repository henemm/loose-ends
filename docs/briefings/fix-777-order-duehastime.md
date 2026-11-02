---
spec_file: docs/specs/fix-777-order-duehastime.md
spec_sha256: bc218cb537d6f82d573a09e7239553df945040776b4d50d211a7d12cd948a49b
spec_frozen_sha256: de0a063e82034c7f7f61f5cbeff85a02a9c266217776cc29f175ecb1e518f795
---

# PO-Briefing: fix-777-order-duehastime

- **Spec:** docs/specs/fix-777-order-duehastime.md
- **Issue:** #777
- **Erstellt:** 2026-11-02

## Was gebaut wird

Aufträge aus Claude ändern bei Fälligkeiten um Mitternacht nichts mehr ohne Spur, sondern werden abgelehnt.

## Definition of Done

Ein Auftrag, der um Mitternacht nur das Uhrzeit-Kennzeichen umschalten will, wird abgelehnt und lässt die Aufgabe unverändert; alle Tests sind grün.

## Wie geprüft wird

Automatische Tests belegen Ablehnung, unveränderten Speicher und normale Fälle; im Produkt ist nichts sichtbar, weil die App den Weg noch nicht aufruft.

## Kritische Anmerkungen

- Zweiter Ticketteil (Statusprüfung) war schon mit PR #791 erledigt; hier nur Kommentar, keine Arbeit.
- Der App-eigene Weg hat dieselbe Lücke und bleibt bewusst unverändert.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
