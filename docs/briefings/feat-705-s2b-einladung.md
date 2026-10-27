---
spec_file: docs/specs/feat-705-schnitt-2b1-gruppe-zuordnung.md
spec_sha256: b897790e4a74b13c88d08cfe4aaf4dfc653f18a7bcc78cac7c70ff3356af2712
spec_frozen_sha256: 74c3e8915750175cf426761c41957185b7bc8d794299a2f25df43de8b5766418
---

# PO-Briefing: feat-705-s2b-einladung

- **Spec:** docs/specs/feat-705-schnitt-2b1-gruppe-zuordnung.md
- **Issue:** #705
- **Erstellt:** 2026-10-27

## Was gebaut wird

Für die erste externe Einladung entsteht bei Apple eine Testgruppe „Tester“, der der neueste Build je Plattform zugeordnet wird.

## Definition of Done

Gruppe „Tester“ existiert ohne Link, beide Plattformen haben einen zugeordneten Build, ein zweiter Lauf ändert nichts.

## Wie geprüft wird

Skripttests gegen einen Apple-Nachbau belegen Ablauf und Sicherheit; ob Apple die Zuordnung wirklich annimmt, zeigt erst der echte Lauf.

## Kritische Anmerkungen

- Ziel „Person installiert über Link“ bleibt fern: Einreichung zum Review und Link folgen erst im Folgeschnitt.
- Ob Apple zur Einreichung eine Datenschutz-URL verlangt, ist ungeklärt; dann hängt die Einladung an Ticket #342.
- Jeder spätere Build braucht wieder einen Handlauf; Automatisierung ist nur als Folgeticket vorgesehen.

## Freigabe-Frage

Soll zuerst nur die Gruppe samt Zuordnung eingerichtet werden, ohne Review und ohne öffentlichen Link?
