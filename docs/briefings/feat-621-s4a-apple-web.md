---
spec_file: docs/specs/feat-621-schnitt-4a-apple-web.md
spec_sha256: 637065ce0cf64e8199901b7958ca81098e8c346452b348e06373e732270eef96
spec_frozen_sha256: 125bf0502f95b634395765c08df4ffc52fc0526f09a316d4288c67b5ff70ddb2
---

# PO-Briefing: feat-621-s4a-apple-web

- **Spec:** docs/specs/feat-621-schnitt-4a-apple-web.md
- **Issue:** #621
- **Erstellt:** 2026-11-06

## Was gebaut wird

Der Dienst bekommt die Bausteine, damit du dich später beim Verbinden von Claude im Browser mit Apple anmelden kannst.

## Definition of Done

Sichtbar ändert sich nichts; alle Dienst-Tests laufen grün, und die bisherige App-Anmeldung funktioniert unverändert.

## Wie geprüft wird

Automatische Tests ohne echte Apple-Verbindung belegen Adressbau, Einlösen und Ablehnen falscher Tokens; die echte Anmeldung wird erst später erprobt.

## Kritische Anmerkungen

- Abweichung vom Schnittplan: Die Browser-Kennung steht in eigener Einstellung, damit die App-Anmeldung keine Browser-Tokens annimmt.
- Vor dem Einschalten musst du dich einmal im Apple-Portal anmelden; die Browser-Kennung lässt sich nicht automatisch anlegen.
- Sechs statt höchstens fünf Dateien, etwa 220 Zeilen; die Spec nimmt das ausdrücklich in Kauf.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
