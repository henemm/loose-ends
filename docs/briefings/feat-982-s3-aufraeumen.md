---
spec_file: docs/specs/enrichment/feat-982-schnitt-3a-modell-rest.md
spec_sha256: a7f1779555718659571d9c4ec88100146e96b933d9d5eb262f70a920ab5a4815
spec_frozen_sha256: 92f1e9de5b648c718d6c09d0d6b01459eeb5243b4a83c6787e1ccb38640da8e3
---

# PO-Briefing: feat-982-s3-aufraeumen

- **Spec:** docs/specs/enrichment/feat-982-schnitt-3a-modell-rest.md
- **Issue:** #982
- **Erstellt:** 2026-11-27

## Was gebaut wird

Toter Modellcode und zwei unbenutzte Texte werden entfernt; für Nutzer bleibt die App unverändert.

## Definition of Done

Die App baut, alle Tests sind grün, und eine im Simulator erfasste Aufgabe „Vor Konzert“ erscheint sofort mit gleichem Titel und ohne Dauer.

## Wie geprüft wird

Ein Abwesenheitstest, alle Unit-Tests und ein Simulatorlauf belegen Aufräumen ohne Verhaltensänderung; der Anleitungstext wird nur per Diff-Durchsicht geprüft.

## Kritische Anmerkungen

- Issue-Text war nicht lesbar; geprüft nur gegen das Kontextdokument.
- Gerätepunkte von Schnitt 1 und #1000 bleiben bis zu Hennings Rückmeldung offen; das Ticket schliesst noch nicht.
- Der Datenschutztext nennt das Modell weiterhin; bewusst ausgeklammert, braucht später Hennings Freigabe.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
