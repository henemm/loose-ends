---
spec_file: docs/specs/measurement/feat-88-textform-spalte.md
spec_sha256: 0e22f491dde19adb6081d88aad201edbbee4c9ab23d4440df9ca19c88e14ecf8
spec_frozen_sha256: 1d40baf90d2036204e2663aeaea3e2bbae1b52b54e76f6676cf038b4dc1faea6
---

# PO-Briefing: feat-88-textform-spalte

- **Spec:** docs/specs/measurement/feat-88-textform-spalte.md
- **Issue:** #88
- **Erstellt:** 2026-10-26

## Was gebaut wird

Der Laborlauf kann später Titel und Dauer des Modells je Textform messen und auswerten.

## Definition of Done

Der Laborlauf lädt den Textform-Korpus mit 120 statt 0 Notizen, die Auswertung zeigt je Form Titel- und Dauerwerte.

## Wie geprüft wird

Unit-Tests mit erfundenen Ergebnissen belegen Laden und Auswertung; sie sagen nichts über die Modellqualität, da kein Modell läuft.

## Kritische Anmerkungen

- Issue-Text im Original nicht lesbar; Abgleich nur gegen Kontextdokument. Deckung der Anfrage unbestätigt.
- Mail-Form fehlt bewusst im Modelllauf; Titelqualität bei Mails bleibt unbelegt.
- Dauer-Zahl zeigt nur Übereinstimmung zwischen Formen, keine Trefferquote; echte Modellwerte erst nach Gerätelauf.

## Freigabe-Frage

Soll das Messwerkzeug ohne Gerätelauf gebaut werden, mit Mail ausgeklammert und Dauer nur als Formvergleich?
