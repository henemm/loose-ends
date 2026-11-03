---
spec_file: docs/specs/feat-615-schnitt-2b2-apple-tresor.md
spec_sha256: da07cebc39ee4161f18910af2754c3d2411dd0934b0fbf79d58dc2b1785e28ad
spec_frozen_sha256: 091f49019aadbab70a3301764a187c2ee94e3b4edb2ec77039809b5bfcaff683
---

# PO-Briefing: feat-615-s2b2-apple-vault

- **Spec:** docs/specs/feat-615-schnitt-2b2-apple-tresor.md
- **Issue:** #615
- **Erstellt:** 2026-11-03

## Was gebaut wird

Der Dienst legt Apples Anmelde-Schlüssel eines Kontos nur verschlüsselt in der Datenbank ab und kann ihn später wieder lesen.

## Definition of Done

Gespeicherte Schlüssel sind ohne separaten Tresorschlüssel unlesbar, manipulierte oder fremde Daten werden abgewiesen, und alle Serverprüfungen laufen grün durch.

## Wie geprüft wird

Automatische Tests prüfen Verschlüsselung, Manipulationsversuche, Speichern und den Weg über das Kontolöschen; die App selbst ruft nichts davon auf.

## Kritische Anmerkungen

- Ein Wechsel des Tresorschlüssels macht alte Schlüssel unlesbar; der Widerruf bei Apple entfiele dann. Rotation ist bewusst nicht enthalten.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
