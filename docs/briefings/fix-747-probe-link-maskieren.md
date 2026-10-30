---
spec_file: docs/specs/fast/fix-747-probe-link-maskieren.md
spec_sha256: a826848b0a047a1c5849b65343284885db47905858d5aba19c1c3e0c1bd19d72
spec_frozen_sha256: 7dfebcbc9a6ec5f0be0e0b89f701294dff0fe531accfe7ff8de86e2ee3d129a9
---

# PO-Briefing: fix-747-probe-link-maskieren

- **Spec:** docs/specs/fast/fix-747-probe-link-maskieren.md
- **Issue:** #747
- **Erstellt:** 2026-10-30

## Was gebaut wird

Die Prüfroutine für TestFlight zeigt im öffentlich lesbaren Protokoll den Einladungslink nicht mehr, sondern nur noch „gesetzt“ oder „-“.

## Definition of Done

Ein Probelauf zeigt in seinem Protokoll statt des Einladungslinks nur „gesetzt“ beziehungsweise „-“, und der Link steht nirgends in der Ausgabe.

## Wie geprüft wird

Automatische Tests belegen, dass der Link weder in Ausgabe noch Fehlerausgabe steht; ein echter Probelauf wird nicht gefahren.

## Kritische Anmerkungen

- Bis zum Merge bleibt der Probelauf ausgesetzt; die Spec regelt das nur als Hinweis, nicht technisch gesperrt.
- Hennings Link über App Store Connect ist genannt, aber nicht Teil der Umsetzung.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
