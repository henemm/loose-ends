---
spec_file: docs/specs/fix-786-telefonregel.md
spec_sha256: 8e7e3c3cc48a10c90b338b28d4a42452f9e492fb7051ce812606336864b40a16
spec_frozen_sha256: b0405b2b98992144b06deb6042c4bb97d9bf4f20e439bd0d033838bd87e9d6cf
---

# PO-Briefing: fix-786-telefonregel

- **Spec:** docs/specs/fix-786-telefonregel.md
- **Issue:** #786
- **Erstellt:** 2026-11-01

## Was gebaut wird

Policen- und Kundennummern bleiben im Titel, echte Telefonnummern gehen in die Notiz, auf iPhone, iPad und Mac gleich.

## Definition of Done

Der Satz „Die Police 30021988 umschreiben lassen" behält die Zahl im Titel, „Ruf 040 1234567 an" legt die Nummer in die Notiz.

## Wie geprüft wird

Tabellentests mit echten und falschen Nummern, der bisher rote Vergleichstest und zwei Simulator-Durchläufe; andere Länderformate und Geräte bleiben ungeprüft.

## Kritische Anmerkungen

- Telefonnummern anderer Länder als Deutschland und Nordamerika bleiben im Titel statt in der Notiz.
- Antippbare Nummern in der Notiz verhalten sich auf dem iPhone weiter anders; Angleichen wäre ein eigenes Ticket.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
