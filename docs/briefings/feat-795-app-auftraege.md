---
spec_file: docs/specs/feat-795-schnitt-1-dienst-wege.md
spec_sha256: 1769cdd326e9070bb17f7af1045068e23631d70a5a104658d071c8fb6e3deb88
spec_frozen_sha256: 75bf8534c7ee9a885af5ba66de6d15877bdfdb77d9f0e2116d883fd2500d0940
---

# PO-Briefing: feat-795-app-auftraege

- **Spec:** docs/specs/feat-795-schnitt-1-dienst-wege.md
- **Issue:** #795
- **Erstellt:** 2026-11-11

## Was gebaut wird

Der Dienst bekommt drei Zugänge für die App: Abschrift ablegen, Auftrag abholen, Ergebnis melden; die App nutzt sie noch nicht.

## Definition of Done

Dienst-Tests grün; ohne Anmeldung gibt jeder Zugang „nicht erlaubt“; ein zehn Minuten hängender Auftrag wird neu vergeben.

## Wie geprüft wird

Automatische Tests gegen eine Wegwerf-Datenbank belegen jede Anforderung; nicht geprüft wird die Erreichbarkeit von außen, die erst der nächste Schnitt öffnet.

## Kritische Anmerkungen

- Nur erster von sechs Schnitten: Das Ticket bleibt offen, Senden, Holen und Ausführen in der App folgen später.
- Zusatz: Rückholregel nach zehn Minuten; zurückgeholte „Erfassen“-Aufträge können eine Aufgabe doppelt anlegen (im Vertrag bekannt).
- Dateigrenze wird nur einmalig bei der Abschlussprüfung belegt, nicht dauerhaft getestet; Umfang rund 460 Zeilen von dir angenommen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
