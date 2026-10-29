---
spec_file: docs/specs/spike-71-schnitt-2b2-lab-guardrail.md
spec_sha256: e0c6afae30ab92da68da1f88fa2fc3e8bb96574700c324092fb4b480f570d51e
spec_frozen_sha256: a915d808636814845dc7ec1d8434d28111df767fff4c3f2698ed62c9cbac0792
---

# PO-Briefing: feat-71-s2b2-lab-guardrail

- **Spec:** docs/specs/spike-71-schnitt-2b2-lab-guardrail.md
- **Issue:** #71
- **Erstellt:** 2026-10-29

## Was gebaut wird

Ein Werkzeug, das die Ablehnungsrate des Modells auf dem iPhone messbar macht, ohne selbst zu messen.

## Definition of Done

Der Trockenlauf nennt Aufrufzahl und Dauer, ohne das iPhone anzufassen, und die Prüfkette läuft im Simulator mit erfundenen Daten durch.

## Wie geprüft wird

Selbsttests belegen Korpusbau, Zählung und Trockenlauf; ob die Datei wirklich aufs iPhone kommt und der Lauf klappt, zeigt kein Test.

## Kritische Anmerkungen

- Die eigentliche iPhone-Zahl fehlt noch; #71 bleibt offen bis zum Gerätelauf auf Ihr Wort.
- Dateiübertragung aufs iPhone ist nur recherchiert, ungetestet; sie kann beim Gerätelauf scheitern.
- Umfang etwa 270 Zeilen, über dem Limit 250; Teilung ist vorgesehen.

## Freigabe-Frage

Soll das Werkzeug gebaut werden, obwohl die iPhone-Zahl erst in einem späteren, separat freizugebenden Gerätelauf entsteht?
