---
spec_file: docs/specs/fix-274-sprache-latenz-messung.md
spec_sha256: 3a688010c37fabc15d395218a9cf1990e73b4168b06bc9f87b0bb5281448526d
---

## Was gebaut wird
Die graue Zeile in der Spracherfassung zeigt künftig Zeiten: Startdauer, aufgeteilt in fünf Schritte, und Dauer bis zum ersten Text. Bei Verzögerung bleibt sie als Bericht stehen.

## Definition of Done
Tests grün, neue TestFlight-Fassung, deine Zeile von iPhone (nach deinem Wort) im Ticket; Fix folgt separat.

## Wie geprüft wird
Regel-Tests; im Simulator nur die alte Zeile, Zahlen erst an deinem Gerät.

## Abweichungen vom Ticket
Dein Wunsch ist weniger Verzögerung; dieser Schritt behebt nichts, er misst nur. „Größter Abstand zwischen Ergebnissen“ (stoßweise, #279) ist gestrichen.

## Kritische Anmerkungen
- Nur messen deckt dein Ziel nicht; ein risikoarmer Hebel könnte mitkommen, dann bliebe unklar, was geholfen hat.
- Die Zeile wird vom Fehlerhinweis zum stehenden Bericht, ohne Entwurf vorab (gegen deine Regel). Es gibt keinen Bildschirmbeleg dafür.
- „Rechte“ enthält beim ersten Start deine Antwortzeit.

## Freigabe-Frage
Zuerst nur messen, ohne Entwurf der Zeile?
