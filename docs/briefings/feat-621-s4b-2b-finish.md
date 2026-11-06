---
spec_file: docs/specs/feat-621-schnitt-4b2b-finish.md
spec_sha256: 538ffb0fd02b9dc1030f1f649b541661d62821c48293bf3dcd421725191a2313
spec_frozen_sha256: 4644d41743e8eff8677b9ce2484e7df7e0acecf8924fa7e6825ec21bd048bd09
---

# PO-Briefing: feat-621-s4b-2b-finish

- **Spec:** docs/specs/feat-621-schnitt-4b2b-finish.md
- **Issue:** #621
- **Erstellt:** 2026-11-06

## Was gebaut wird

Nach der Apple-Anmeldung im Browser schließt der Dienst die Anmeldung ab, nur für genau diesen Browser und einmalig.

## Definition of Done

Die Tests laufen grün, und ein Durchlauf endet im Dienst bei der festen Absage der Zustimmung, mit angelegter Anmeldung.

## Wie geprüft wird

Tests spielen den ganzen Weg gegen eine echte Datenbank durch, inklusive Angriffsfälle; echte Browser und echtes Apple prüft erst ein späterer Schritt.

## Kritische Anmerkungen

- Ob Safari das nötige Cookie wirklich mitschickt, ist unbelegt; Nachweis folgt erst im Betriebsschritt.
- Umfang ca. 325 statt 250 Zeilen; von dir bereits freigegeben.
- Seltene Löschung im Millisekundenfenster führt zu einem Fehler; bewusst nicht abgefangen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
