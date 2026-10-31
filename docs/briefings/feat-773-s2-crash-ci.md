---
spec_file: docs/specs/tooling/feat-773-schnitt-2-crash-ci.md
spec_sha256: 09525535420323d811b125872f877f6f9404adca872f0c5624627c7f799b4bf5
spec_frozen_sha256: 6b33862b47642b5f9abc03c926aadecd64bc2cccd3025ad8b892e83d1eb9d767
---

# PO-Briefing: feat-773-s2-crash-ci

- **Spec:** docs/specs/tooling/feat-773-schnitt-2-crash-ci.md
- **Issue:** #773
- **Erstellt:** 2026-10-31

## Was gebaut wird

Claude holt TestFlight-Absturzmeldungen per Handlauf in GitHub ab, legt sie verschlüsselt ab und wertet sie aus.

## Definition of Done

Der Handlauf läuft grün, liefert verschlüsselte Meldungen oder „keine Absturzmeldungen“, und die Anleitung steht in der Doku.

## Wie geprüft wird

Tests belegen Verschlüsselung, Aufbau des Ablaufs und Schutz des Logs; ob GitHub es wirklich so ausführt, zeigt erst der Lauf nach dem Merge.

## Kritische Anmerkungen

- Zusatz zum Ticket: Artefakt ist verschlüsselt (Repo öffentlich); Schlüssel ohne Passphrase nur auf diesem Mac, Aufbewahrung 7 Tage.
- Ticket bleibt offen, bis eine echte Meldung mit Bericht ausgewertet ist; der Probelauf geht erst nach dem Merge.
- Ob der Abrufpfad für Berichte stimmt und ob sie symbolisiert ankommen, bleibt ohne echte Meldung unbelegt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
