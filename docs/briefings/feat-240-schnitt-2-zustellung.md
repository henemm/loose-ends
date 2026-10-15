---
spec_file: docs/specs/feat-240-schnitt-2-zustellung.md
spec_sha256: 68ab838ac1f1aeb7a37e325161a6df42f7525095f52ba883d93f10fc3501d3ca
---

# PO-Briefing: feat-240-schnitt-2-zustellung

- **Spec:** docs/specs/feat-240-schnitt-2-zustellung.md
- **Issue:** #240
- **Erstellt:** 2026-10-14

## Was gebaut wird

Aufgaben mit Ort melden sich beim Ankommen oder Verlassen auf iPhone und iPad, auch bei geschlossener App.

## Definition of Done

Mit geschlossener App am Ort angekommen erscheint genau eine Mitteilung; Erledigt wirkt, eine zweite bleibt aus.

## Wie geprüft wird

Simulatortests belegen Antippen, Knöpfe und fehlerfreie Anbindung; der echte Ortsauslöser ist nur auf Hennings iPhone prüfbar.

## Kritische Anmerkungen

- Ortsauslöser nicht im Simulator belegbar; Gerätetest erst nach Merge, Ticket bleibt bis zu deiner Rückmeldung offen.
- Systemverzögerung von Minuten; „zweite bleibt aus" hat keine messbare Zeitgrenze.
- Kein Hinweis in der App, falls Standort verweigert wird.

## Freigabe-Frage

Freigabe, die Ortserinnerung so zu bauen und erst nach dem Merge per TestFlight am Gerät zu prüfen?
