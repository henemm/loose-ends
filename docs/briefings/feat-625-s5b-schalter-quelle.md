---
spec_file: docs/specs/feat-625-schnitt-5b-schalter-quelle.md
spec_sha256: a8b4425a963dc9444f48d36108484bac1a7fe5f9d3098668727c4803411f8361
spec_frozen_sha256: d017088e81d911c24538a001972303d9e331a157e2c35c46ed4d2adf66ec9076
---

# PO-Briefing: feat-625-s5b-schalter-quelle

- **Spec:** docs/specs/feat-625-schnitt-5b-schalter-quelle.md
- **Issue:** #625
- **Erstellt:** 2026-11-23

## Was gebaut wird

Die Verbindung zu Claude ist in jeder App-Ausgabe dauerhaft eingeschaltet, samt den drei Datenarten im Datenschutz-Verzeichnis.

## Definition of Done

Im Simulator zeigen die Einstellungen ohne Testmodus die Gruppe „Claude“ mit Apple-Anmeldung, die App startet ohne Absturz, alle Prüfläufe sind grün.

## Wie geprüft wird

Automatische Tests halten Schalter und Datenschutz-Angaben fest; die sichtbare Gruppe belegt nur ein Simulator-Durchlauf, der fertige TestFlight-Bau erst später.

## Kritische Anmerkungen

- Bis zum Folgeschnitt darf kein TestFlight-Lauf starten, sonst scheitert er; das sichert nur die Disziplin der Sitzung.
- Fremde Konten sähen die Gruppe, aber „noch nicht freigeschaltet“, bis die Betriebs-Tür im Schlussschnitt öffnet.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
