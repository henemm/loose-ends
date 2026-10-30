---
spec_file: docs/specs/bug-746-ipad-weisse-flaechen.md
spec_sha256: 2cdf6649a87f477f6c0db53d3d94cb87534a316a9ff4bc024e30242867acc58b
spec_frozen_sha256: 9d0a03d30eea937937185f9044e24ab91b9cd59d9cbf07e19342d79568b018dc
---

# PO-Briefing: fix-746-ipad-weisse-flaechen

- **Spec:** docs/specs/bug-746-ipad-weisse-flaechen.md
- **Issue:** #746
- **Erstellt:** 2026-10-30

## Was gebaut wird

Auf dem iPad im Hochformat erscheinen Startseite und „Erledigt“ durchgehend auf beigem Papier statt mit weißen Flächen.

## Definition of Done

Vorher/nachher-Bilder zeigen auf dem iPad keine weißen Flächen mehr, Seitenleiste, iPhone und Mac sehen unverändert aus, und die App-Store-Bilder sind neu erzeugt.

## Wie geprüft wird

Zwei neue iPad-Tests vergleichen die Farbe in Zeile und Hintergrund; sie laufen nur lokal, nicht in der automatischen Prüfung auf GitHub.

## Kritische Anmerkungen

- Die iPad-Tests laufen nicht automatisch bei jeder Änderung; ein späterer Rückfall fiele erst bei einem lokalen Lauf auf.
- Unveränderte Seitenleiste wird per Bildvergleich und bestehenden Tests geprüft, nicht durch einen eigenen neuen Test.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
