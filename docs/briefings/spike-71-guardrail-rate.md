---
spec_file: docs/specs/spike-71-schnitt-1-mac-guardrails.md
spec_sha256: 6380a2348ca58f6ff6db7b9dad4a7bd930001f40d2b55e084619a5a2182f3f7d
spec_frozen_sha256: 838d2fa18429d81dbbb39fc9b4a06b1cf6d37f4df4f263f60293744a9db8e8cc
---

## Was gebaut wird

Eine Messung auf dem Mac, wie oft das Modell Alltagsaufgaben ablehnt, mit Bericht; das iPhone folgt später.

## Definition of Done

Messung gelaufen, Bericht nennt Raten, jeden Treffer und das Urteil zur 1-Prozent-Grenze; das Ticket bleibt offen.

## Wie geprüft wird

Tests im Simulator belegen die Zählweise; die Messung selbst ist ein einmaliger Lauf, kein Test.

## Kritische Anmerkungen

- Ticket verlangt Mac und iPhone; hier nur der Mac, B3 bleibt bis zum iPhone-Schnitt unentschieden.
- Die 1-Prozent-Grenze gilt für alle 387 Texte zusammen; die 100 heiklen allein: ein Treffer wären 1 Prozent.
- Zeitüberschreitung und Last-Sperre zählen nicht als Ablehnung; FocusBlox-Sätze bleiben lokal, nicht im Repo.

## Freigabe-Frage

Soll zuerst nur der Mac gemessen werden, mit der Schwelle über alle 387 Texte?
