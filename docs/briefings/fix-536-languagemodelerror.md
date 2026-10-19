---
spec_file: docs/specs/fix-536-languagemodelerror.md
spec_sha256: 8f7b63af701f2e25c1d1215a548ea6180663c77d3b9712bd4d87dd7f951900e7
spec_frozen_sha256: b3bea3e119bf40f69b12be614c0c35c8c65d1786359fdbeff0cffe906da0ef14
---

# PO-Briefing: fix-536-languagemodelerror

- **Spec:** docs/specs/fix-536-languagemodelerror.md
- **Issue:** #536
- **Erstellt:** 2026-10-19

## Was gebaut wird

Die Auswertung von Modellfehlern in den Messläufen nutzt Apples neue Fehlerarten, und die Veraltet-Warnung im Bau verschwindet.

## Definition of Done

Der Bau meldet aus diesen Dateien keine Veraltet-Warnung mehr, und alle Tests sind grün, auch die drei neu erkannten Fehlerarten.

## Wie geprüft wird

Automatische Tests prüfen jede Fehlerart einzeln; die App selbst verhält sich unverändert und wird deshalb nicht von Hand durchgespielt.

## Kritische Anmerkungen

- Die App-Logik für Fehler (Erfassung, Nachverarbeitung) bleibt bewusst unverändert; die Prüfung dazu steht nur als Begründung, nicht als Test.
- Der Nutzen liegt allein in Messberichten und Warnungsfreiheit; für den Alltag ändert sich nichts Sichtbares.

## Freigabe-Frage

Darf die Fehlerauswertung wie beschrieben umgestellt werden, ohne dass sich im Produkt etwas ändert?
