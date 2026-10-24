---
spec_file: docs/specs/feat-68-modell-verfuegbarkeit.md
spec_sha256: b438432654755429ab68fd732b4ad387dab956c18e88fcaaedc9cd28a34483ff
spec_frozen_sha256: 888f46696545b9157a85c973e8d7e2716fdf5b4fdac7cca34cf96f019d955d39
---

# PO-Briefing: 68-modell-verfuegbarkeit

## Was gebaut wird

Eine Übersicht, wo das Modell läuft (nur in der App), die berichtigte Entscheidung dazu und Tests je Ausfallgrund. Das Verhalten der App ändert sich nicht.

## Definition of Done

Übersicht und Entscheidung liegen vor, Tests sind grün, Gerätezellen stehen auf „offen“.

## Wie geprüft wird

Tests im Simulator; kein Gerät wird angefasst.

## Kritische Anmerkungen

- Ticket wollte Gerätemessung, Spec lässt Gerätezellen offen.
- „Intent-Prozess“ wurde nie gebaut; Aufgaben von Watch, Teilen, Kurzbefehl warten auf eine geöffnete App (Folgeticket).
- Doppellauf wird nicht verhindert, nur im Test belegt.
- Tests ohne RED-Phase; Simulator-Beleg nur, falls das Gate ihn verlangt.

## Freigabe-Frage

Geben Sie den Nachweis ohne Gerätemessung frei?
