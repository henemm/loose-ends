---
spec_file: docs/specs/feat-621-schnitt-4b2b-finish.md
spec_sha256: cd0c4705ccc0d2018480f73569cd2a8cba7d91c5e532314b3340670ed7ca7377
spec_frozen_sha256: 0049e050161b7987ebac59d59fe74223b43cf5f700679f9f25465b497aa0c765
---

# PO-Briefing: feat-621-s4b-2b-finish

- **Spec:** docs/specs/feat-621-schnitt-4b2b-finish.md
- **Issue:** #621
- **Erstellt:** 2026-11-06

## Was gebaut wird

Nach der Apple-Anmeldung im Browser schließt der Dienst die Anmeldung ab, nur für genau diesen Browser und einmalig.

## Definition of Done

Die Tests laufen grün, und ein Durchlauf endet bei der festen Absage der Zustimmung, mit angelegter Browser-Anmeldung des Kontos.

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
