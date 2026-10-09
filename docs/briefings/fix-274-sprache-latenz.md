---
spec_file: docs/specs/fix-274-sprache-latenz-messung.md
spec_sha256: 3850f72841da7d2083050b625a64094e12e3a70b8a83e6bbda63545dc6f0679a
---

## Was gebaut wird
Die graue Zeile in der Spracherfassung zeigt Zeiten: Startdauer in fünf Schritten (inklusive Öffnen) und Dauer bis zum ersten Text. Bei Verzögerung bleibt sie als Bericht stehen.

## Definition of Done
Tests grün, Simulator-Screenshot. Nach Auslieferung Pflicht: neue TestFlight-Fassung, deine Zeile im Ticket.

## Wie geprüft wird
Regel-Tests; im Simulator nur die alte Zeile, Zahlen erst an deinem Gerät.

## Abweichungen vom Ticket
Behebt die Verzögerung nicht, misst nur. „Stoßweise“ (#279) entfällt.

## Kritische Anmerkungen
- Verschiebung von Gerätelauf und Stresstest ist fair, aber die Absicherung gilt dann erst nach Auslieferung; ein Regressionsfehler träfe zuerst deine Fassung.
- Die Zeile wird zum stehenden Bericht, ohne Entwurf vorab.
- „Rechte“ enthält beim ersten Start deine Antwortzeit.

## Freigabe-Frage
Zuerst nur messen, Gerätelauf und Stresstest nachgelagert?
