---
spec_file: docs/specs/lab-83-foreground-measurement.md
spec_sha256: ccc77503569a234338e6c9ded9f895187fcd81cdcf7cb5be1cd2f1e141ec8220
---

# PO-Briefing: lab-foreground-83

- **Spec:** docs/specs/lab-83-foreground-measurement.md
- **Issue:** #83
- **Erstellt:** 2026-09-20

## Was gebaut wird

Die Labor-App misst nur, während sie geöffnet ist, hält bei Sperre an und schreibt jeden Schritt mit Zeitstempel mit.

## Definition of Done

Simulator und iPhone zeigen: Anhalten nach drei Fehlschlägen, Anhalten bei Sperre, jedes Ereignis mit Zeitstempel in der Ergebnisdatei.

## Wie geprüft wird

Automatisierte Tests prüfen Fehlerarten und Datei-Format; Vordergrund-Verhalten und Fernstart werden nur einmalig per Bildschirmaufnahme vorgeführt, nicht dauerhaft automatisiert.

## Kritische Anmerkungen

- Dass die App keine Hintergrundmodi mehr anmeldet, wird weder getestet noch im Nachweis gezeigt.
- Der Nachweis läuft einmalig manuell auf Simulator und iPhone, nicht als wiederholbarer automatischer Test.
- Die Änderung betrifft 6 statt der üblichen 4–5 Dateien, laut Spec ohne sinnvolle Aufteilung.

## Freigabe-Frage

Reicht dir ein einmaliger manueller Nachweis auf Simulator und iPhone, oder soll das Hintergrund-Verbot zusätzlich automatisch geprüft werden?
