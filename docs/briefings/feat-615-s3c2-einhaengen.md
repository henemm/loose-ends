---
spec_file: docs/specs/feat-615-schnitt-3c2-einhaengen.md
spec_sha256: feb90bf88511a9cf303c344c01783fc1f22ee8ce2610504d3e0c440ecfedb313
spec_frozen_sha256: 2beea0b0cad8f6078ff12fe855035d1928e0fd7e8af6eb6ede090db41eb6b503
---

# PO-Briefing: feat-615-s3c2-einhaengen

- **Spec:** docs/specs/feat-615-schnitt-3c2-einhaengen.md
- **Issue:** #615
- **Erstellt:** 2026-11-05

## Was gebaut wird

Die Türen Anmelden, Abmelden und Konto löschen werden im laufenden Dienst eingehängt, von außen noch unerreichbar.

## Definition of Done

Alle Server-Tests sind grün; der Dienst startet ohne Apple-Einrichtung wie bisher, bricht bei halber Einrichtung mit Variablennamen ab und lehnt Anfragen über 1 MiB ab.

## Wie geprüft wird

Automatische Tests mit selbst erzeugten Apple-Schlüsseln belegen Anmelden, Abmelden, Löschen und die Grenzen; echtes Apple und der Betrieb bleiben ungeprüft.

## Kritische Anmerkungen

- Zeilenschätzung 200–220 wirkt knapp: 12 Testfälle in 120–140 Zeilen; nach der 2,5-fach-Erfahrung droht Überschreitung der 250.
- Zwei Abweichungen vom Folgeplan (Test-Naht bleibt, Schlüsselabruf erst bei erster Anmeldung); technisch begründet, ohne Folge fürs Ticket.
- Die neue 1-MiB-Grenze gilt auch für Claude-Anfragen; im Ticket nicht verlangt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
