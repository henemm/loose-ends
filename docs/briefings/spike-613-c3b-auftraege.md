---
spec_file: docs/specs/spike-613-schnitt-c3b-auftraege.md
spec_sha256: f440033177280a3833ddd0e2755104af9f7c86fdbd928323cc7487275b0aa3fd
spec_frozen_sha256: 27e3aa39154fa039a0b82ca4d668518888120e44d7ad19c237d309f7cb089d37
---

# PO-Briefing: spike-613-c3b-auftraege

- **Spec:** docs/specs/spike-613-schnitt-c3b-auftraege.md
- **Issue:** #613
- **Erstellt:** 2026-11-01

## Was gebaut wird

Der Dienst nimmt Aufträge von Claude an, gibt jeden genau einem Gerät und nimmt Ergebnisse nur von diesem Gerät.

## Definition of Done

Alle Servertests laufen grün, auch auf GitHub; die App ändert sich nicht.

## Wie geprüft wird

Tests belegen Formprüfung, einmalige Vergabe bei gleichzeitigem Zugriff und Abweisung fremder Ergebnisse, nicht aber Claude oder App.

## Kritische Anmerkungen

- Umfang etwa 256 statt 250 Zeilen; deine Grenze ist knapp überschritten.
- Abweichungen: Der Dienst verlangt je Auftragsart Pflichtfelder, die in der App optional sind; erledigte oder gelöschte Aufgaben nimmt er an.
- Keine Reihenfolge der Vergabe zugesagt; ein abgestürztes Gerät behält seinen Auftrag bis zum Betriebsschnitt C7.

## Freigabe-Frage

Gibst du die Überschreitung der 250-Zeilen-Grenze um etwa sechs Zeilen frei?

## Ampel

Ampel: rot
