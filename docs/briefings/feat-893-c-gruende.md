---
spec_file: docs/specs/feat-893-schnitt-c-gruende.md
spec_sha256: 4f3b329b2ee26e67149ee6b4d7446f9927f1eb909e929e0443fd403da0ef9d8c
spec_frozen_sha256: 21d4a02345c8f836067c3877f78ddc231951484cd18255c4d8d9fd4427942401
---

# PO-Briefing: feat-893-c-gruende

- **Spec:** docs/specs/feat-893-schnitt-c-gruende.md
- **Issue:** #893
- **Erstellt:** 2026-11-10

## Was gebaut wird

Das Einreichwerkzeug nennt künftig die Gründe, die Apple für die abgelehnte Einreichung von Version 1.0.1 angibt.

## Definition of Done

Bei erneuter Ablehnung zeigt das Werkzeug Apples Gründe an, und nach dem echten Lauf liegt ein Beleg dazu vor.

## Wie geprüft wird

Automatische Tests mit nachgebauter Apple-Antwort prüfen Ausgabe, Bereinigung und einmaligen Schreibaufruf; ob Apples echte Antwortform passt, zeigt erst der echte Lauf.

## Kritische Anmerkungen

- Apples Antwortform ist undokumentiert; das Werkzeug rät zwei Varianten, sonst zeigt es nur Schlüsselnamen. Ein weiterer Lauf kann nötig werden.
- Die Ablehnung selbst wird in diesem Schnitt nicht behoben, nur sichtbar gemacht.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
