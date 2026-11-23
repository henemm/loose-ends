---
spec_file: docs/specs/feat-625-schnitt-5a-offene-tuer.md
spec_sha256: 3ddda55c840d950993e68a76324c89e3f2775a99e0baa96af65e2daa96dbff16
spec_frozen_sha256: eed4803e9646e817e1f59398366f5ffb0b163167a5a058dd3f9f5666b9facb43
---

# PO-Briefing: feat-625-konto-schalter

- **Spec:** docs/specs/feat-625-schnitt-5a-offene-tuer.md
- **Issue:** #625
- **Erstellt:** 2026-11-22

## Was gebaut wird

Der Dienst für Claude kann künftig jedem Apple-Konto offenstehen, mit höchstens 20 neuen Konten pro 24 Stunden.

## Definition of Done

Der Dienst läuft mit unveränderter Einstellung weiter, dein Konto kommt herein, und die offene Variante ist im Test nachgewiesen.

## Wie geprüft wird

Automatische Tests mit echter Datenbank belegen Grenze, Bestandskonten und beide Anmeldewege; ob Apples Prüfer durchkommt, zeigt erst die spätere Einreichung.

## Kritische Anmerkungen

- Die Tür bleibt vorerst zu; geöffnet wird erst im Store-Schnitt. Dieser Schnitt allein hilft Apples Prüfer noch nicht.
- Ist die Grenze erreicht, wird auch ein Prüfer bis zu 24 Stunden abgewiesen (Spec benennt das Risiko).
- Gelöschte Konten zählen nicht mehr mit; Löschen und Neuanlegen umgeht die Grenze (bewusst akzeptiert, dokumentiert).

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
