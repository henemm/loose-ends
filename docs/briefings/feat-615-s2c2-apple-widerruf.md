---
spec_file: docs/specs/feat-615-schnitt-2c2-apple-widerruf.md
spec_sha256: 52bed3a0b53a341202585c427c36bd22144f14e535dfacbe42af6c007fc2d527
spec_frozen_sha256: c29de297963ec889e2d281515d0fae77bbce9570049544656bf6820935ba71be
---

# PO-Briefing: feat-615-s2c2-apple-widerruf

- **Spec:** docs/specs/feat-615-schnitt-2c2-apple-widerruf.md
- **Issue:** #615
- **Erstellt:** 2026-11-03

## Was gebaut wird

Der Dienst kann Apple den bei der Anmeldung erhaltenen Schlüssel zurückgeben, wenn ein Konto gelöscht wird (noch ohne Aufrufer).

## Definition of Done

Die neue Funktion liefert in allen getesteten Fällen ein klares Ergebnis, wirft nie bei Apple-Fehlern, und die gesamte Testsuite samt CI ist grün.

## Wie geprüft wird

Automatische Tests mit simuliertem Apple prüfen Anfrage, Erfolg, Fehler, Zeitlimit und Geheimnisfreiheit; ein echter Apple-Aufruf wird nicht getestet.

## Kritische Anmerkungen

- "Erfolg" bedeutet nur, Apple hat nicht abgelehnt; Apple antwortet teils auch bei ungültigem Schlüssel mit 200.
- Welche Anmelde-Kennung beim Widerruf gilt, ist offen und wird erst im nächsten Schnitt entschieden.
- Apples Fehlerformat ist eine Annahme, nicht bestätigt; Abweichung ergibt nur einen allgemeinen Fehlergrund.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
