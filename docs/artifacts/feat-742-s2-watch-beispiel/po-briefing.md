---
spec_file: docs/specs/fast/feat-742-s2-watch-beispiel.md
spec_sha256: 70e5e7b8963097f9520fd9cd438e3c23e69d737068fb7f3d06b29539b2f1b3e0
spec_frozen_sha256: 6d47d8e9a482e4763750e2795d41d50d667e0bd461d04cb822381806757568bf
---

# PO-Briefing: feat-742-s2-watch-beispiel

- **Spec:** docs/specs/fast/feat-742-s2-watch-beispiel.md
- **Issue:** #742 (Schnitt 2)
- **Erstellt:** 2026-10-31

## Was gebaut wird

Im Testmodus zeigt die Uhr-App unter „Jetzt“ drei Beispielaufgaben, damit die App-Store-Bilder der Uhr nicht leer sind.

## Definition of Done

Die Uhr-Bilder für den App Store zeigen eine gefüllte „Jetzt“-Liste, und die normale Uhr-App verhält sich unverändert.

## Wie geprüft wird

Ein Foto-Test prüft, dass „Jetzt“ mindestens zwei Zeilen zeigt; dass der Normalbetrieb unverändert bleibt, weist kein Test nach.

## Kritische Anmerkungen

- Unverändert im Normalbetrieb ist nur behauptet, nicht getestet; Test prüft „mindestens zwei“ statt drei Aufgaben.
- Zusätzlich eingebaut: neuer Simulator-Befehl für Uhr-Tests, den niemand verlangt hat.
- Der Uhr-Ordner steht auf der Geräteliste; Abnahme endet bewusst im Simulator, ohne Gerätelauf.

## Freigabe-Frage

Ist es für dich in Ordnung, dass der Uhr-Code angefasst wird und nur im Simulator geprüft wird?

## Ampel

Ampel: rot
