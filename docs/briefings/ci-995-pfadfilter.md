---
spec_file: docs/specs/ci/ci-995-skripttests-parallel.md
spec_sha256: 9b99511d8f99d55568760bff03b90b2b676e7c7402c240742da7e51dce7d9de0
spec_frozen_sha256: 5eae039a17808dc5c497eebb42138461fd61c41c351bc2e71d1bc2fd2233bef5
---

# PO-Briefing: ci-995-pfadfilter

- **Spec:** docs/specs/ci/ci-995-skripttests-parallel.md
- **Issue:** #995
- **Erstellt:** 2026-11-28

## Was gebaut wird

Reine Doku- und Skript-Änderungen sollen die automatischen Prüfungen künftig in unter zehn Minuten bestehen, nicht erst nach elf.

## Definition of Done

Ein anschließender reiner Doku-Änderungsvorschlag erfüllt alle Pflicht-Prüfungen in unter zehn Minuten, und der Vorschlag mit dieser Änderung läuft vollständig grün.

## Wie geprüft wird

Eigene Tests belegen den neuen Prüf-Ablauf; die Zeit unter zehn Minuten lässt sich erst im echten Lauf nach der Auslieferung messen.

## Kritische Anmerkungen

- Die Zehn-Minuten-Zusage ist vorab nur lokal gemessen (2 bis 2,5 Minuten); bestätigt wird sie erst nach dem Zusammenführen.
- Zwei Sammel-Prüfungen laufen künftig auf einem anderen Rechnertyp; Namen der Pflicht-Prüfungen bleiben gleich.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
