---
spec_file: docs/specs/tooling/feat-773-schnitt-1-crash-skript.md
spec_sha256: 68d88062fadc1e691eb85b8c088e3be924d31b727cf303d2410194ec13c0e154
spec_frozen_sha256: d08166693ad69d96a043f477841a61e052985ce40bafdbb861ae63d4252e5653
---

# PO-Briefing: feat-773-testflight-crashes

- **Spec:** docs/specs/tooling/feat-773-schnitt-1-crash-skript.md
- **Issue:** #773
- **Erstellt:** 2026-10-31

## Was gebaut wird

Ein Werkzeug, das TestFlight-Absturzmeldungen bei Apple abholt und als Dateien ablegt, ohne persönliche Tester-Daten auszugeben.

## Definition of Done

Das Werkzeug legt je Absturzmeldung zwei Dateien ab, druckt nur Zahlen und Kennzeilen, und alle Skripttests laufen grün.

## Wie geprüft wird

Dreizehn Tests gegen einen Apple-Nachbau belegen Ablauf, Fehlerfälle und Datenschutz; ob Apple wirklich so antwortet, zeigt erst Schnitt 2.

## Kritische Anmerkungen

- Nur Schnitt 1: Ohne Schnitt 2 (CI-Lauf, Verschlüsselung) holt noch niemand echte Berichte ab; #773 bleibt offen.
- Ob Berichte vorliegen und symbolisiert sind, ist unbelegt; ein Lauf ohne Meldung beweist wenig.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
