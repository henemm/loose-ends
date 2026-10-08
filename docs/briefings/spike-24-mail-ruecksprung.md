---
spec_file: docs/specs/measurement/spike-24-mail-ruecksprung.md
spec_sha256: 99322f08dec4dae96ef96bbcf7b17f8664ad6b83e9bb900427b9d5c1a7529adc
---

# PO-Briefing: spike-24-mail-ruecksprung

- **Spec:** docs/specs/measurement/spike-24-mail-ruecksprung.md
- **Issue:** #24
- **Erstellt:** 2026-10-08

## Was gebaut wird

Aus Mail geteilte Datei-Links werden nicht mehr als tote Quelle gespeichert; das Messergebnis steht im Bericht.

## Definition of Done

Teilen aus Mail ergibt keinen toten Quell-Link mehr, und Bericht, Frage 5 sowie Stand-Dokument nennen Ergebnis und Fallback.

## Wie geprüft wird

Automatische Tests belegen nur die Link-Regel; ob Mail je eine Mail-Adresse liefert, beruht allein auf deiner Handbeobachtung.

## Kritische Anmerkungen

- Ticket verlangte vier Mails, zwei Konten, Rücksprung und Randfälle; geliefert sind drei Handversuche, Rücksprung ungemessen, Randfälle unbelegt.
- Kein Log der Typkennungen vorhanden; "Datei-Link" ist Deutung, nicht Messung.
- Rücksprung bleibt offen: Muss und ADR-9 unverändert, Lösung nur im Folgeticket #289.

## Freigabe-Frage

Genügt dir ein unvollständig gemessenes "Teilen liefert keinen Rücksprung", mit Klärung der Alternativen in #289, zum Schließen von #24?
