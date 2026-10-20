---
spec_file: docs/specs/fix-536-languagemodelerror.md
spec_sha256: 0e8454f67957730823db42f01412d74cb50a34b80506c62c2aaa9c512fb6725f
spec_frozen_sha256: aa5bfe2a8cafd26593aea5493f017d32ffc1b4ccb8e3bf53beac258c0889ac43
---

# PO-Briefing: fix-536-languagemodelerror

- **Spec:** docs/specs/fix-536-languagemodelerror.md
- **Issue:** #536
- **Erstellt:** 2026-10-19

## Was gebaut wird

Messberichte erkennen Modellfehler mit Apples neuen Fehlerarten, und die Veraltet-Warnung im Bau verschwindet.

## Definition of Done

Der Bau meldet aus diesen Dateien keine Veraltet-Warnung mehr, alle Tests sind grün, und drei bisher unerkannte Fehlerarten werden benannt.

## Wie geprüft wird

Automatische Tests prüfen jede Fehlerart einzeln; die App verhält sich unverändert und wird deshalb nicht von Hand durchgespielt.

## Kritische Anmerkungen

- Die Prüfung, ob die Aufgabenverarbeitung neue Fehlerarten anders behandeln muss, endet mit „nein" und hat keinen Test, nur eine Begründung.
- Unterscheidung dauerhafter und vorübergehender Fehler ist bewusst ausgeklammert und liegt in Ticket #535.
- Im Alltag ändert sich nichts Sichtbares; der Nutzen liegt nur in Messberichten und einem warnungsfreien Bau.

## Freigabe-Frage

Darf die Fehlerauswertung wie beschrieben umgestellt werden, ohne dass sich im Produkt etwas ändert?
