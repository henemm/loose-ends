---
spec_file: docs/specs/spike-613-schnitt-c3a-abschrift-annehmen.md
spec_sha256: 027a0dede9c497b726a12788f067b9fc927e9bcc2838f32bad74c256299c6d08
spec_frozen_sha256: 6863320b74addde12ed0703fde31b5bd71a7a9a7514ea936b146c435839a77c4
---

# PO-Briefing: spike-613-c3-dienstkern

- **Spec:** docs/specs/spike-613-schnitt-c3a-abschrift-annehmen.md
- **Issue:** #613
- **Erstellt:** 2026-11-01

## Was gebaut wird

Der Dienst für Claude nimmt die Aufgaben-Abschrift der App geprüft entgegen und behält immer die neueste.

## Definition of Done

Falsche oder Rohtext enthaltende Abschriften werden abgewiesen, ältere überschreiben nie neuere, erledigten Aufgaben setzt Claude keine Fälligkeit mehr.

## Wie geprüft wird

Automatische Tests gegen eine echte Datenbank und die App-Tests belegen das; Anbindung an die App und Anmeldung sind nicht Teil.

## Kritische Anmerkungen

- Zwei Punkte (Datenbank unverändert, Vertragstext angepasst) prüft nur eine Durchsicht, kein automatischer Test.
- Der Dienst ist von außen noch nicht erreichbar; Aufträge und Ergebnisse folgen erst im nächsten Schnitt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
