---
spec_file: docs/specs/feat-795-schnitt-5a2a-apns-absender.md
spec_sha256: 02534c388576b7fc3d64ddbe34813ca7dbef5a2b99128e9d6477c3763f13d392
spec_frozen_sha256: 1510c00e2d3f89807ab19a00fb5c3ee9cbe8dd06206445b5e8dad1bb436b3ae1
---

# PO-Briefing: feat-795-s5a2-apns-absender

- **Spec:** docs/specs/feat-795-schnitt-5a2a-apns-absender.md
- **Issue:** #795
- **Erstellt:** 2026-11-14

## Was gebaut wird

Der Dienst bekommt den Baustein, der Geräte per stiller Apple-Mitteilung wecken kann, noch ohne Anschluss.

## Definition of Done

Alle Dienst-Tests laufen grün, und der Baustein wird von nichts aufgerufen; für Nutzer ändert sich noch nichts.

## Wie geprüft wird

Tests mit Attrappen und lokalem Testserver prüfen Aufbau, Token-Regeln und Löschen ungültiger Adressen; ein echter Apple-Aufruf wird nicht getestet.

## Kritische Anmerkungen

- Dieser Schnitt allein weckt kein Gerät; der Weckruf wirkt erst nach den Folgeschnitten.
- Die echte Verbindung zu Apple bleibt bis zum Schlüssel-Schnitt unbewiesen.
- Umfang liegt mit Tests über der Grenze; diese Zählweise wurde früher schon akzeptiert.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
