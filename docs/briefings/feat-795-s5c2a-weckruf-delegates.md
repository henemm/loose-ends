---
spec_file: docs/specs/feat-795-schnitt-5c2a-weckruf-delegates.md
spec_sha256: 72f506a8def77f0f024eee2bdcc08b12f559918007b747543f4946c3f17f38e3
spec_frozen_sha256: 2aa455b5c74ae954b7060799f5490162e4cdb76df9bd89b255ba1c4c50e06f6a
---

# PO-Briefing: feat-795-s5c2a-weckruf-delegates

- **Spec:** docs/specs/feat-795-schnitt-5c2a-weckruf-delegates.md
- **Issue:** #795
- **Erstellt:** 2026-11-19

## Was gebaut wird

Schickt Claude einen Auftrag, holt die App ihn sofort per stillem Weckruf, auch wenn sie im Hintergrund liegt.

## Definition of Done

Im Simulator löst ein Weckruf das Holen eines Auftrags aus; im TestFlight-Bau mit Konto klappt das bei App im Hintergrund.

## Wie geprüft wird

Automatische Tests belegen Erkennung, Frist und Anmeldung; ob echte Weckrufe auf Geräten ankommen und iCloud unberührt bleibt, zeigt nur TestFlight.

## Kritische Anmerkungen

- Umfang etwa 300 Zeilen, über dem Limit von 250; Überhang liegt bei Tests.
- Mac-Empfang funktioniert erst nach dem parallelen Schnitt mit dem Mac-Schlüssel.
- Simulator-Beleg gilt laut Apple-Forum als unzuverlässig; der Gerätebeweis steht daher erst in der Definition of Done.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
